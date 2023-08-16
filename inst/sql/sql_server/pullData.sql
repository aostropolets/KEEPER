-- presentation: everything on day 0
with presentation as (select distinct p.person_id, c.new_id, 
                                      case
                                          when birth_datetime is not null
                                              then datediff(year, birth_datetime, cohort_start_date)
                                          else year(cohort_start_date) - year_of_birth end             as age,
                                      case when gender_concept_id = 8507 then 'Male' else 'Female' end as gender,
                                      cohort_start_date                                                as day_0,
                                      case
                                          when cc2.concept_name is not null
                                              then concat(cc.concept_name, ' (', cc2.concept_name, ');')
                                          else concat(cc.concept_name, ';') end                                     as concept_name,
                                      cohort_definition_id
                      from #pts_cohort c
                          join @cdm_database_schema.person p
                      on p.person_id= c.subject_id
                          join @cdm_database_schema.condition_occurrence co on co.person_id = p.person_id and cohort_start_date = condition_start_date
                          JOIN @cdm_database_schema.concept cc on cc.concept_id = co.condition_concept_id and cc.concept_id!=0
                          LEFT JOIN @cdm_database_schema.concept cc2 on cc2.concept_id = co.condition_type_concept_id and cc2.concept_id!=0)
select person_id, new_id, age, gender, day_0, concept_name, cohort_definition_id
into #presentation
from presentation
order by presentation asc
;

-- visits overlapping with the day 0
with visits as (select distinct vo.person_id,
                                datediff(day, visit_start_date, visit_end_date) as duration,
                                visit_start_date,
                                cc.concept_name                                 as visit_type,
                                cohort_definition_id
                from #pts_cohort c
                    join @cdm_database_schema.visit_occurrence vo
                on vo.person_id = c.subject_id and visit_start_date <= cohort_start_date and cohort_start_date <= visit_end_date
                    join @cdm_database_schema.concept cc on cc.concept_id = vo.visit_concept_id and cc.concept_id!=0),
     visits2 as (select v.*,
                        case
                            when duration > 0 then concat(visit_type, ' (', duration, ' days)')
                            else visit_type end as                                                            visit_detail,
                        row_number() OVER (PARTITION BY person_id ORDER BY visit_start_date, visit_type desc) rn
                 from visits v)
select distinct a.person_id,
                case
                    when b.person_id is not null then concat(a.visit_detail, '->', b.visit_detail)
                    else a.visit_detail end as concept_name,
                a.cohort_definition_id
into #visit_context
from visits2 a
    left join visits2 b
on a.person_id = b.person_id
    and b.rn = 2
where a.rn = 1;

-- comorbidties and symptoms within the prior year [-365;0)
-- this is a common query that is used everywhere later. we only modify the time frames and the tables
with conditions as (select distinct person_id,
                                    cohort_definition_id,
                                    concat(concept_name, ' (day ',
                                           datediff(day, cohort_start_date, condition_era_start_date),
                                           ');')                                               as concept_name,
                                    datediff(day, cohort_start_date, condition_era_start_date) as date_order

                    from #pts_cohort c
                        join @cdm_database_schema.condition_era co
                    on co.person_id = c.subject_id
                        and datediff(day, cohort_start_date, condition_era_start_date)<0
                        and datediff(day, condition_era_start_date, cohort_start_date)<=365
                        join @cdm_database_schema.concept cc on cc.concept_id = condition_concept_id and cc.concept_id!=0
                    where cc.concept_id in (@prior_conditions))
select person_id, cohort_definition_id, concept_name
into #prior_conditions
from conditions
order by date_order asc
;

-- drugs within the prior year [-365;0), relies on drug_era
with drugs as (select distinct person_id,
                               cohort_definition_id,
                               concat(concept_name, ' (day ', datediff(day, cohort_start_date, drug_era_start_date),
                                      ', ',
                                      datediff(day, drug_era_start_date, drug_era_end_date), ' days);') as concept_name,
                               datediff(day, cohort_start_date, drug_era_start_date)                    as date_order

               from #pts_cohort c
                   join @cdm_database_schema.drug_era co
               on co.person_id = c.subject_id
                   and datediff(day, cohort_start_date, drug_era_start_date)<0
                   and datediff(day, drug_era_start_date, cohort_start_date)<=365
                   join @cdm_database_schema.concept cc on cc.concept_id = drug_concept_id and cc.concept_id!=0
               where cc.concept_id in (@prior_drugs))
select person_id, cohort_definition_id, concept_name
into #prior_drugs
from drugs
order by date_order asc
;


-- alternative diagnosis within the next 30 days [0;+30].
with dx as (select distinct person_id,
                            cohort_definition_id,
                            concat(concept_name, ' (day ', datediff(day, cohort_start_date, condition_era_start_date),
                                   ')')                                                as concept_name,
                            datediff(day, cohort_start_date, condition_era_start_date) as date_order
            from #pts_cohort c
                join @cdm_database_schema.condition_era co
            on co.person_id = c.subject_id
                and datediff(day, cohort_start_date, condition_era_start_date)<=28
                and datediff(day, condition_era_start_date, cohort_start_date)<=0
                join @cdm_database_schema.concept cc on cc.concept_id = condition_concept_id and cc.concept_id!=0
            where cc.concept_id in (@alternative_diagnosis))
select person_id, cohort_definition_id, concept_name
into #alternative_diagnosis
from dx
order by date_order asc
;

-- diagnostic procedures around the day 0 [-30;+30]
with diagnostics as (select distinct person_id,
                                     cohort_definition_id,
                                     concat(concept_name, ' (day ', datediff(day, cohort_start_date, procedure_date),
                                            ');')                                     as concept_name,
                                     datediff(day, cohort_start_date, procedure_date) as date_order
                     from #pts_cohort c
                         left join @cdm_database_schema.procedure_occurrence po
                     on po.person_id = subject_id
                         and datediff(day, cohort_start_date, procedure_date)<=30
                         and datediff(day, procedure_date, cohort_start_date)<=30
                         join @cdm_database_schema.concept cc on cc.concept_id = procedure_concept_id and cc.concept_id!=0
                     where cc.concept_id in (@diagnostic_procedures))
select person_id, cohort_definition_id, concept_name
into #diagnostic_procedures
from diagnostics
order by date_order asc
;


-- measurements around day 0 [-30;+30].
with meas as (
-- value_as_number
    select person_id,
           cohort_definition_id, {!@meas_values} ? {concat(cc.concept_name, ' (', case
        when value_as_number > range_high then 'abnormal, high'
        when value_as_number < range_low then 'abnormal, low'
        else 'normal' end, ', day ', datediff(day, cohort_start_date, measurement_date), ');') as concept_name}
        : {concat(cc.concept_name, ' (', value_as_number, cc2.concept_name, ', day ', datediff(day, cohort_start_date, measurement_date), ');') as concept_name }, datediff(day, cohort_start_date, measurement_date) as date_order
    from #pts_cohort c
        join @cdm_database_schema.measurement m
    on m.person_id = subject_id
        and datediff(day, cohort_start_date, measurement_date)<=30
        and datediff(day, measurement_date, cohort_start_date)<=30
        join @cdm_database_schema.concept cc on cc.concept_id = measurement_concept_id and cc.concept_id!=0
        left join @cdm_database_schema.concept cc2 on cc2.concept_id = unit_concept_id and cc2.concept_id!=0
    where cc.concept_id in (@measurements)
      and value_as_number is not null

    union

-- value_as_concept_id
    select person_id, cohort_definition_id, concat(cc.concept_name, ' (', cc2.concept_name, ', day ', datediff(day, cohort_start_date, measurement_date), ');') as concept_name,
    datediff(day, cohort_start_date, measurement_date) as date_order
    from #pts_cohort c
        join @cdm_database_schema.measurement m
    on m.person_id = subject_id
        and datediff(day, cohort_start_date, measurement_date)<=30
        and datediff(day, measurement_date, cohort_start_date)<=30
        join @cdm_database_schema.concept cc on cc.concept_id = measurement_concept_id and cc.concept_id!=0
        and cc.concept_id in (@measurements)
        and value_as_concept_id is not null and value_as_concept_id!=0
        join @cdm_database_schema.concept cc2 on cc2.concept_id = value_as_concept_id

    union

    -- everything else
    select person_id, cohort_definition_id, concat(cc.concept_name, ' (', 'day ', datediff(day, cohort_start_date, measurement_date), ');') as concept_name, 
    datediff(day, cohort_start_date, measurement_date) as date_order
    from #pts_cohort c
        join @cdm_database_schema.measurement m
    on m.person_id = subject_id
        and datediff(day, cohort_start_date, measurement_date)<=30
        and datediff(day, measurement_date, cohort_start_date)<=30
        join @cdm_database_schema.concept cc on cc.concept_id = measurement_concept_id and cc.concept_id!=0
        and cc.concept_id in (@measurements)
        and value_as_number is null and (value_as_concept_id is null or value_as_concept_id=0))
select person_id,
       concept_name,
       cohort_definition_id
into #measurements
from meas c
order by date_order asc;

-- drug treatment within the year [0;+365].
with drugs as (select distinct p.person_id,
                               cohort_definition_id,
                               concat(concept_name, ' (day ', datediff(day, cohort_start_date, drug_era_start_date),
                                      ', ',
                                      datediff(day, drug_era_start_date, drug_era_end_date),
                                      ' days);')                                     as concept_name,
                               datediff(day, cohort_start_date, drug_era_start_date) as date_order
               from #pts_cohort c
                   join @cdm_database_schema.person p
               on p.person_id= c.subject_id
                   join @cdm_database_schema.drug_era de on de.person_id = p.person_id and cohort_start_date = drug_era_start_date
                   and datediff(day, cohort_start_date, drug_era_start_date)<=365
                   and datediff(day, drug_era_start_date, cohort_start_date)<=0
                   join @cdm_database_schema.concept cc on cc.concept_id = drug_concept_id and cc.concept_id!=0
                   and cc.concept_id in (@medication_treatment))
select person_id, cohort_definition_id, concept_name
into #medication_treatment
from drugs
order by date_order asc
;


-- treatment procedures [0;+30]
with treatment as (select distinct person_id,
                                   cohort_definition_id,
                                   concat(concept_name, ' (day ', datediff(day, cohort_start_date, procedure_date),
                                          ');')                                     as concept_name,
                                   datediff(day, cohort_start_date, procedure_date) as date_order
                   from #pts_cohort c
                       join @cdm_database_schema.procedure_occurrence po
                   on po.person_id = subject_id
                       and datediff(day, cohort_start_date, procedure_date)<=30
                       and datediff(day, procedure_date, cohort_start_date)<=0
                       join @cdm_database_schema.concept cc on cc.concept_id = procedure_concept_id and cc.concept_id!=0
                       and cc.concept_id in (@treatment_procedures))
select person_id, cohort_definition_id, concept_name
into #treatment_procedures
from treatment
order by date_order asc
;


-- complications within the next year (0;+365].
with complications as (select distinct person_id,
                                       cohort_definition_id,
                                       concat(concept_name, ' (day ',
                                              datediff(day, cohort_start_date, condition_era_start_date),
                                              ');')                                               as concept_name,
                                       datediff(day, cohort_start_date, condition_era_start_date) as date_order

                       from #pts_cohort c
                           join @cdm_database_schema.condition_era co
                       on co.person_id = c.subject_id
                           and datediff(day, cohort_start_date, condition_era_start_date)<=365
                           and datediff(day, condition_era_start_date, cohort_start_date)<=0
                           join @cdm_database_schema.concept cc on cc.concept_id = condition_concept_id and cc.concept_id!=0
                           and cc.concept_id in (@complications))
select person_id, cohort_definition_id, concept_name
into #complications
from complications
order by date_order asc
;
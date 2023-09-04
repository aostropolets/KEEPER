-- presentation: everything on day 0
with presentation as (select distinct p.person_id, c.new_id, 
                                      case
                                          when birth_datetime is not null
                                              then datediff(year, birth_datetime, cohort_start_date)
                                          else year(cohort_start_date) - year_of_birth end             as age,
                                      case when gender_concept_id = 8507 then 'Male' else 'Female' end as gender,
                                      cohort_start_date,
                                      concat(datediff(day, cohort_start_date, observation_period_start_date), ' days - ', 
                                            datediff(day, cohort_start_date, observation_period_end_date), ' days') as observation_period,
                                      case
                                          when cc2.concept_name is not null and cc3.concept_name is not null
                                              then concat(cc.concept_name, ' (', cc2.concept_name, ', ', cc3.concept_name, ');')
                                          when cc2.concept_name is not null and cc3.concept_name is null 
                                              then concat(cc.concept_name, ' (', cc2.concept_name, ');')
                                          when cc2.concept_name is null and cc3.concept_name is not null 
                                              then concat(cc.concept_name, ' (', cc3.concept_name, ');')                                          
                                          else concat(cc.concept_name, ';') end                         as concept_name,
                                       cohort_definition_id
                      from #pts_cohort c
                          join @cdm_database_schema.person p
                      on p.person_id= c.subject_id
                          join @cdm_database_schema.observation_period op on op.person_id = p.person_id 
                                                                          and cohort_start_date > observation_period_start_date 
                                                                          and observation_period_end_date > cohort_start_date
                          join @cdm_database_schema.condition_occurrence co on co.person_id = p.person_id and cohort_start_date = condition_start_date
                          join @cdm_database_schema.concept cc on cc.concept_id = co.condition_concept_id and cc.concept_id!=0
                          left join @cdm_database_schema.concept cc2 on cc2.concept_id = co.condition_type_concept_id and cc2.concept_id!=0
                          left join @cdm_database_schema.concept cc3 on cc3.concept_id = co.condition_status_concept_id and cc3.concept_id!=0)
select person_id, new_id, age, gender, cohort_start_date, concept_name, cohort_definition_id
into #presentation
from presentation
order by concept_name asc
;

-- visits overlapping with the day 0
with visits as (select distinct vo.person_id,
                                datediff(day, visit_start_date, visit_end_date) as duration,
                                visit_start_date,
                                cc.concept_name                                 as visit_type,
                                cohort_start_date,
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
                a.cohort_start_date,    
                a.cohort_definition_id
into #visit_context
from visits2 a
    left join visits2 b
on a.person_id = b.person_id
    and b.rn = 2
where a.rn = 1;

-- comorbidities and risk factors anytime prior [-9999,0)
with conditions as (select distinct person_id,
                                    cohort_definition_id,
                                    cohort_start_date,
                                    concat(concept_name, ' (day ',
                                           datediff(day, cohort_start_date, condition_era_start_date),
                                           ');')                                               as concept_name,
                                    datediff(day, cohort_start_date, condition_era_start_date) as date_order

                    from #pts_cohort c
                        join @cdm_database_schema.condition_era co
                    on co.person_id = c.subject_id
                        and datediff(day, cohort_start_date, condition_era_start_date)<0
                        --and datediff(day, condition_era_start_date, cohort_start_date)<=365
                        {@use_ancestor} ? 
                        {join @cdm_database_schema.concept_ancestor ca on descendant_concept_id = condition_concept_id
                         and ancestor_concept_id in (@comorbidities) and ancestor_concept_id not in (@symptoms)
                         and ancestor_concept_id not in (@doi) and ancestor_concept_id not in (@complications)
                         join @cdm_database_schema.concept cc on cc.concept_id = condition_concept_id}
                        :{join @cdm_database_schema.concept cc on cc.concept_id = condition_concept_id and cc.concept_id!=0
                           and cc.concept_id in (@comorbidities) and cc.concept_id not in (@symptoms)
                            and cc.concept_id not in (@doi) and cc.concept_id not in (@complications)
                           }
                           )
select person_id, cohort_definition_id, cohort_start_date, concept_name
into #comorbidities
from conditions
order by date_order asc
;

-- prior symptoms within a prior month [-30,0)
with symptoms as (select distinct person_id,
                                       cohort_definition_id,
                                       cohort_start_date,
                                       concat(concept_name, ' (day ',
                                              datediff(day, cohort_start_date, condition_era_start_date),
                                              ');')                                               as concept_name,
                                       datediff(day, cohort_start_date, condition_era_start_date) as date_order
                       from #pts_cohort c
                           join @cdm_database_schema.condition_era co
                       on co.person_id = c.subject_id
                           and datediff(day, cohort_start_date, condition_era_start_date)<0
                           and datediff(day, condition_era_start_date, cohort_start_date)<=30
                        {@use_ancestor} ? 
                        {join @cdm_database_schema.concept_ancestor ca on descendant_concept_id = condition_concept_id
                         and ancestor_concept_id in (@symptoms) and ancestor_concept_id not in (@doi) and ancestor_concept_id not in (@complications)
                         join @cdm_database_schema.concept cc on cc.concept_id = condition_concept_id}
                        :{join @cdm_database_schema.concept cc on cc.concept_id = condition_concept_id and cc.concept_id!=0
                           and cc.concept_id in (@symptoms) and cc.concept_id not in (@doi) and cc.concept_id not in (@complications)   
                           }
                           )
select person_id, cohort_definition_id, cohort_start_date, concept_name
into #symptoms
from symptoms
order by date_order asc
;

insert into #symptoms
select person_id, 
       cohort_definition_id, 
       cohort_start_date,
       concept_name
from (
    select distinct                  person_id,
                                       cohort_definition_id,
                                       cohort_start_date,
                                       concat(concept_name, ' (day ',
                                              datediff(day, cohort_start_date, observation_date),
                                              ');')                                               as concept_name,
                                       datediff(day, cohort_start_date, observation_date) as date_order
                       from #pts_cohort c
                           join @cdm_database_schema.observation co
                       on co.person_id = c.subject_id
                           and datediff(day, cohort_start_date, observation_date)<0
                           and datediff(day, observation_date, cohort_start_date)<=30
                        {@use_ancestor} ? 
                        {join @cdm_database_schema.concept_ancestor ca on descendant_concept_id = observation_concept_id
                         and ancestor_concept_id in (@symptoms) 
                         join @cdm_database_schema.concept cc on cc.concept_id = observation_concept_id}
                        :{join @cdm_database_schema.concept cc on cc.concept_id = observation_concept_id and cc.concept_id!=0
                           and cc.concept_id in (@symptoms)}
        ) a 
order by date_order asc
;

-- prior disease history [-9999,0): DOI and complications
with prior_disease as (select distinct person_id,
                                       cohort_definition_id,
                                       cohort_start_date,
                                       concat(concept_name, ' (day ',
                                              datediff(day, cohort_start_date, condition_era_start_date),
                                              ');')                                               as concept_name,
                                       datediff(day, cohort_start_date, condition_era_start_date) as date_order
                       from #pts_cohort c
                           join @cdm_database_schema.condition_era co
                       on co.person_id = c.subject_id
                           and datediff(day, cohort_start_date, condition_era_start_date)<0
                        {@use_ancestor} ? 
                        {join @cdm_database_schema.concept_ancestor ca on descendant_concept_id = condition_concept_id
                         and (ancestor_concept_id in (@complications) or ancestor_concept_id in (@doi))
                         join @cdm_database_schema.concept cc on cc.concept_id = condition_concept_id}
                        :{join @cdm_database_schema.concept cc on cc.concept_id = condition_concept_id and cc.concept_id!=0
                           and (cc.concept_id in (@complications) or cc.concept_id in (@doi))}
                           )
select person_id, cohort_definition_id, cohort_start_date, concept_name
into #prior_disease
from prior_disease
order by date_order asc
;

-- disease history after (0,9999]: DOI and complications
with after_disease as (select distinct person_id,
                                       cohort_definition_id,
                                       cohort_start_date,
                                       concat(concept_name, ' (day ',
                                              datediff(day, cohort_start_date, condition_era_start_date),
                                              ');')                                               as concept_name,
                                       datediff(day, cohort_start_date, condition_era_start_date) as date_order
                       from #pts_cohort c
                           join @cdm_database_schema.condition_era co
                       on co.person_id = c.subject_id
                           and datediff(day, condition_era_start_date, cohort_start_date)<0
                        {@use_ancestor} ? 
                        {join @cdm_database_schema.concept_ancestor ca on descendant_concept_id = condition_concept_id
                         and (ancestor_concept_id in (@complications) or ancestor_concept_id in (@doi))
                         join @cdm_database_schema.concept cc on cc.concept_id = condition_concept_id}
                        :{join @cdm_database_schema.concept cc on cc.concept_id = condition_concept_id and cc.concept_id!=0
                           and (cc.concept_id in (@complications) or cc.concept_id in (@doi))}
                           )
select person_id, cohort_definition_id, cohort_start_date, concept_name
into #after_disease
from after_disease
order by date_order asc
;

-- drugs all time prior [-9999, 0), relies on drug_era
with drugs as (select distinct person_id,
                               cohort_definition_id,
                               cohort_start_date,
                               concat(concept_name, ' (day ', datediff(day, cohort_start_date, drug_era_start_date),
                                      ', for ',
                                      datediff(day, drug_era_start_date, drug_era_end_date), ' days);') as concept_name,
                               datediff(day, cohort_start_date, drug_era_start_date)                    as date_order

               from #pts_cohort c
                   join @cdm_database_schema.drug_era co
               on co.person_id = c.subject_id
                   and datediff(day, cohort_start_date, drug_era_start_date)<0
                   --and datediff(day, drug_era_start_date, cohort_start_date)<=365
                   join @cdm_database_schema.concept cc on cc.concept_id = drug_concept_id and cc.concept_id!=0
               where cc.concept_id in (@drugs)
               
               )
select person_id, cohort_definition_id, cohort_start_date, concept_name
into #prior_drugs
from drugs
order by date_order asc
;


-- drugs all time after [0;9999], relies on drug_era
with drugs as (select distinct person_id,
                               cohort_definition_id,
                               cohort_start_date,
                               concat(concept_name, ' (day ', datediff(day, cohort_start_date, drug_era_start_date),
                                      ', for ',
                                      datediff(day, drug_era_start_date, drug_era_end_date), ' days);') as concept_name,
                               datediff(day, cohort_start_date, drug_era_start_date)                    as date_order

               from #pts_cohort c
                   join @cdm_database_schema.drug_era co
               on co.person_id = c.subject_id
                   and datediff(day, cohort_start_date, drug_era_start_date)>=0
                   --and datediff(day, drug_era_start_date, cohort_start_date)<=365
                   join @cdm_database_schema.concept cc on cc.concept_id = drug_concept_id and cc.concept_id!=0
               where cc.concept_id in (@drugs)
               )
select person_id, cohort_definition_id, cohort_start_date, concept_name
into #after_drugs
from drugs
order by date_order asc
;

-- treatment procedures prior [-9999,0)
with treatment as (select distinct person_id,
                                   cohort_definition_id,
                                   cohort_start_date,
                                   concat(concept_name, ' (day ', datediff(day, cohort_start_date, procedure_date),
                                          ');')                                     as concept_name,
                                   datediff(day, cohort_start_date, procedure_date) as date_order
                   from #pts_cohort c
                       join @cdm_database_schema.procedure_occurrence po
                   on po.person_id = subject_id
                       and datediff(day, cohort_start_date, procedure_date)<0
                        {@use_ancestor} ? 
                        {join @cdm_database_schema.concept_ancestor ca on descendant_concept_id = procedure_concept_id
                         and ancestor_concept_id in (@treatment_procedures)
                         join @cdm_database_schema.concept cc on cc.concept_id = procedure_concept_id}
                        :{join @cdm_database_schema.concept cc on cc.concept_id = procedure_concept_id and cc.concept_id!=0
                           and cc.concept_id in (@treatment_procedures)}
                           )
select person_id, cohort_definition_id, cohort_start_date, concept_name
into #prior_treatment_procedures
from treatment
order by date_order asc
;
 
-- treatment procedures [0,9999]
with treatment as (select distinct person_id,
                                   cohort_definition_id,
                                   cohort_start_date,
                                   concat(concept_name, ' (day ', datediff(day, cohort_start_date, procedure_date),
                                          ');')                                     as concept_name,
                                   datediff(day, cohort_start_date, procedure_date) as date_order
                   from #pts_cohort c
                       join @cdm_database_schema.procedure_occurrence po
                   on po.person_id = subject_id
                       and datediff(day, procedure_date, cohort_start_date)<=0
                        {@use_ancestor} ? 
                        {join @cdm_database_schema.concept_ancestor ca on descendant_concept_id = procedure_concept_id
                         and ancestor_concept_id in (@treatment_procedures)
                         join @cdm_database_schema.concept cc on cc.concept_id = procedure_concept_id}
                        :{join @cdm_database_schema.concept cc on cc.concept_id = procedure_concept_id and cc.concept_id!=0
                           and cc.concept_id in (@treatment_procedures)}
                           )
select person_id, cohort_definition_id, cohort_start_date, concept_name
into #after_treatment_procedures
from treatment
order by date_order asc
;

-- alternative diagnosis within +-00 days [-90, 90].
with dx as (select distinct person_id,
                            cohort_definition_id,
                            cohort_start_date,
                            concat(concept_name, ' (day ', datediff(day, cohort_start_date, condition_era_start_date),
                                   ')')                                                as concept_name,
                            datediff(day, cohort_start_date, condition_era_start_date) as date_order
            from #pts_cohort c
                join @cdm_database_schema.condition_era co
            on co.person_id = c.subject_id
                and datediff(day, cohort_start_date, condition_era_start_date)<=90
                and datediff(day, condition_era_start_date, cohort_start_date)<=90
                        {@use_ancestor} ? 
                        {join @cdm_database_schema.concept_ancestor ca on descendant_concept_id = condition_concept_id
                         and ancestor_concept_id in (@alternative_diagnosis) and ancestor_concept_id not in (@symptoms)
                         and ancestor_concept_id not in (@doi) and ancestor_concept_id not in (@complications) 
                         and ancestor_concept_id not in (@comorbidities)
                         join @cdm_database_schema.concept cc on cc.concept_id = condition_concept_id}
                        :{join @cdm_database_schema.concept cc on cc.concept_id = condition_concept_id and cc.concept_id!=0
                           and cc.concept_id in (@alternative_diagnosis) and cc.concept_id not in (@symptoms)
                           and cc.concept_id not in (@doi) and cc.concept_id not in (@complications) 
                           and cc.concept_id not in (@comorbidities)
                           }
                           )
select person_id, cohort_definition_id, cohort_start_date, concept_name
into #alternative_diagnosis
from dx
order by date_order asc
;

-- diagnostic procedures around the day 0 [-30;+30]
with diagnostics as (select distinct person_id,
                                     cohort_definition_id,
                                     cohort_start_date,
                                     concat(concept_name, ' (day ', datediff(day, cohort_start_date, procedure_date),
                                            ');')                                     as concept_name,
                                     datediff(day, cohort_start_date, procedure_date) as date_order
                     from #pts_cohort c
                         left join @cdm_database_schema.procedure_occurrence po
                     on po.person_id = subject_id
                         and datediff(day, cohort_start_date, procedure_date)<=30
                         and datediff(day, procedure_date, cohort_start_date)<=30
                        {@use_ancestor} ? 
                        {join @cdm_database_schema.concept_ancestor ca on descendant_concept_id = procedure_concept_id
                         and ancestor_concept_id in (@diagnostic_procedures)
                         join @cdm_database_schema.concept cc on cc.concept_id = procedure_concept_id}
                        :{join @cdm_database_schema.concept cc on cc.concept_id = procedure_concept_id and cc.concept_id!=0
                           and cc.concept_id in (@diagnostic_procedures)}
                           )
select person_id, cohort_definition_id, cohort_start_date, concept_name
into #diagnostic_procedures
from diagnostics
order by date_order asc
;


-- measurements around day 0 [-30;+30].
with meas as (
-- value_as_number
    select person_id,
           cohort_definition_id, 
           cohort_start_date,
           {!@meas_values} ? {concat(cc.concept_name, ' (', case
        when value_as_number > range_high then 'abnormal, high'
        when value_as_number < range_low then 'abnormal, low'
        else 'normal' end, ', day ', datediff(day, cohort_start_date, measurement_date), ');') as concept_name}
        : {concat(cc.concept_name, ' (', value_as_number, ' ', cc2.concept_name, ', day ', datediff(day, cohort_start_date, measurement_date), ');') as concept_name }, datediff(day, cohort_start_date, measurement_date) as date_order
    from #pts_cohort c
        join @cdm_database_schema.measurement m
    on m.person_id = subject_id
        and datediff(day, cohort_start_date, measurement_date)<=30
        and datediff(day, measurement_date, cohort_start_date)<=30
                        {@use_ancestor} ? 
                        {join @cdm_database_schema.concept_ancestor ca on descendant_concept_id = measurement_concept_id
                         and ancestor_concept_id in (@measurements)
                         join @cdm_database_schema.concept cc on cc.concept_id = measurement_concept_id}
                        :{join @cdm_database_schema.concept cc on cc.concept_id = measurement_concept_id and cc.concept_id!=0
                           and cc.concept_id in (@measurements)}        
        left join @cdm_database_schema.concept cc2 on cc2.concept_id = unit_concept_id and cc2.concept_id!=0
    where value_as_number is not null

    union

-- value_as_concept_id
    select person_id,
           cohort_definition_id, 
           cohort_start_date,
           concat(cc.concept_name, ' (', cc2.concept_name, ', day ', datediff(day, cohort_start_date, measurement_date), ');') as concept_name,
           datediff(day, cohort_start_date, measurement_date) as date_order
    from #pts_cohort c
        join @cdm_database_schema.measurement m
    on m.person_id = subject_id
        and datediff(day, cohort_start_date, measurement_date)<=30
        and datediff(day, measurement_date, cohort_start_date)<=30
                        {@use_ancestor} ? 
                        {join @cdm_database_schema.concept_ancestor ca on descendant_concept_id = measurement_concept_id
                         and ancestor_concept_id in (@measurements)
                         join @cdm_database_schema.concept cc on cc.concept_id = measurement_concept_id}
                        :{join @cdm_database_schema.concept cc on cc.concept_id = measurement_concept_id and cc.concept_id!=0
                           and cc.concept_id in (@measurements)}    
        and value_as_concept_id is not null and value_as_concept_id!=0
        join @cdm_database_schema.concept cc2 on cc2.concept_id = value_as_concept_id

    union

    -- everything else
    select person_id, 
           cohort_definition_id, 
           cohort_start_date,
           concat(cc.concept_name, ' (', 'day ', datediff(day, cohort_start_date, measurement_date), ');') as concept_name, 
           datediff(day, cohort_start_date, measurement_date) as date_order
    from #pts_cohort c
        join @cdm_database_schema.measurement m
    on m.person_id = subject_id
        and datediff(day, cohort_start_date, measurement_date)<=30
        and datediff(day, measurement_date, cohort_start_date)<=30
                        {@use_ancestor} ? 
                        {join @cdm_database_schema.concept_ancestor ca on descendant_concept_id = measurement_concept_id
                         and ancestor_concept_id in (@measurements)
                         join @cdm_database_schema.concept cc on cc.concept_id = measurement_concept_id}
                        :{join @cdm_database_schema.concept cc on cc.concept_id = measurement_concept_id and cc.concept_id!=0
                           and cc.concept_id in (@measurements)}    
        and value_as_number is null and (value_as_concept_id is null or value_as_concept_id=0))
select person_id,
       concept_name,
       cohort_definition_id,
       cohort_start_date
into #measurements
from meas c
order by date_order asc;



--death  
with death as (select distinct person_id,
                                       cohort_definition_id,
                                       cohort_start_date,
                                       concat(concept_name, ' (day ',
                                              datediff(day, cohort_start_date, death_date),
                                              ');')                                               as concept_name
                       from #pts_cohort c
                           join @cdm_database_schema.death d
                       on d.person_id = c.subject_id and death_date>=cohort_start_date
                           join @cdm_database_schema.concept cc on cc.concept_id = cause_concept_id and cc.concept_id!=0
)
select person_id, 
       cohort_definition_id, 
       cohort_start_date,
       concept_name
into #death
from death
order by concept_name asc
;

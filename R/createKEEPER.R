# Copyright 2023 Observational Health Data Sciences and Informatics
#
# This file is part of KEEPER
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#' Creates a folder with the KEEPER to review person level profiles.
#'
#' @description
#' Export person level data from omop cdm tables for eligible persons in the cohort. Creates a folder with the KEEPER to review person level profiles.
#'
#' @template Connection
#'
#' @template CohortDatabaseSchema
#'
#' @template CdmDatabaseSchema
#'
#' @template VocabularyDatabaseSchema
#'
#' @template CohortTable
#'
#' @template TempEmulationSchema
#'
#' @param cohortDefinitionId          The cohort id to extract records.
#'
#' @param cohortName                  (optional) Cohort Name
#'
#' @param sampleSize                  (Optional, default = 20) The number of persons to randomly sample. Ignored, if personId is given.
#'
#' @param personIds                   (Optional) An array of personId's to look for in Cohort table and CDM.
#'
#' @param exportFolder                The folder where the output will be exported to. If this folder
#'                                    does not exist it will be created.
#' @param databaseId                  A short string for identifying the database (e.g. 'Synpuf'). This will be displayed
#'                                    in shiny app to toggle between databases. Should not have space or underscore (_).
#'
#' @param assignNewId                 (Default = FALSE) Do you want to assign a newId for persons. This will replace the personId in the source with a randomly assigned newId.
#'
#' @param userCovariates              (KEEPER: for future: turn recommendations for KEEPER on and off)
#'
#' @param PriorDrugs                  KEEPER: input string for concept_ids for prior drug exposures relevant to the condition of interest within a year prior to the index date
#'
#' @param PriorConditions             KEEPER: input string for concept_ids for prior conditions relevant to the condition of interest within a year prior to the index date
#'
#' @param DiagnosticProcedures        KEEPER: input string for concept_ids for diagnostic procedures relevant to the condition of interest within a month prior and after the index date
#'
#' @param Measurements	              KEEPER: input string for concept_ids for lab tests relevant to the condition of interest within a month prior and after the index date
#'
#' @param AlternativeDiagnosis        KEEPER: input string for concept_ids for competing diagnosis within a month after the index date
#'
#' @param TreatmentProcedures	        KEEPER: input string for concept_ids for treatment procedures relevant to the condition of interest within a month after the index date
#'
#' @param MedicationTreatment         KEEPER: input string for concept_ids for treatment medications relevant to the condition of interest within a month after the index date
#'
#' @param Complications               KEEPER: input string for concept_ids for complications of the condition of interest within a year after the index date
#'
#' @param MeasValues                   KEEPER: a switch for displaying measurement values vs comparison to normal range
#'
#'
#' @examples
#' \dontrun{
#' connectionDetails <- createConnectionDetails(
#'   dbms = "postgresql",
#'   server = "ohdsi.com",
#'   port = 5432,
#'   user = "me",
#'   password = "secure"
#' )
#'
#' createKEEPER(
#'   connectionDetails = connectionDetails,
#'   cohortDefinitionId = 1234,
#'   cohortName = "DM type I",
#'   PriorConditions = c(201820,442793,443238,4016045,4065354,45757392, 4051114, 433968, 375545, 29555009, 4209145, 4034964, 380834, 4299544, 4226354, 4159742, 43530690, 433736,
#'                     320128, 4170226, 40443308, 441267, 4163735, 192963, 85828009),
#'   PriorDrugs = c(1730370, 21604490, 21601682, 21601855, 21601462, 21600280, 21602728, 1366773, 21602689, 21603923, 21603746),
#'   DiagnosticProcedures = "",
#'   Measurements	= c(3034962, 3000483, 3034962, 3000483, 3004501, 3033408, 3005131, 3024629, 3031266, 3037110, 3009261, 3022548, 3019210, 3025232, 3033819,
#'                  3000845, 3002666, 3004077, 3026300, 3014737, 3027198, 3025398, 3010300, 3020399, 3007332, 3025673, 3027457, 3010084, 3004410, 3005673),
#'   AlternativeDiagnosis = c(201820,442793,443238,4016045,4065354,45757392, 4051114, 433968, 375545, 29555009, 4209145, 4034964, 380834, 4299544, 4226354, 4159742, 43530690, 433736,
#'                          320128, 4170226, 40443308, 441267, 4163735, 192963, 85828009),
#'   TreatmentProcedures = c(40756884, 4143852, 2746768, 2746766),
#'   MedicationTreatment = c(741530, 42873378, 45774489, 1502809,1502826,1503297,1510202, 1515249,1516766,1525215,1529331,1530014,1547504,
#'                          1559684,1560171,1580747,1583722,1594973,1597756,19067100,1502905,1513876,1516976,1517998,1531601,1544838,1550023, 1567198,19122121,21600713),
#'   Complications =  c(201820,442793,443238,4016045,4065354,45757392, 4051114, 433968, 375545, 29555009, 4209145, 4034964,
#'                       380834, 4299544, 4226354, 4159742, 43530690, 433736, 320128, 4170226, 40443308, 441267, 4163735, 192963, 85828009)                             
#' )
#' }
#'
# 
#' @export
createKEEPER <- function(connectionDetails = NULL,
                                    connection = NULL,
                                    cohortDatabaseSchema = NULL,
                                    cdmDatabaseSchema,
                                    vocabularyDatabaseSchema = cdmDatabaseSchema,
                                    tempEmulationSchema = getOption("sqlRenderTempEmulationSchema"),
                                    cohortTable = "cohort",
                                    cohortDefinitionId,
                                    cohortName = NULL,
                                    sampleSize = 20,
                                    personIds = NULL,
                                    exportFolder,
                                    databaseId,
                                    assignNewId = FALSE,
                                    #userCovariates = TRUE,
                                    PriorDrugs,
                                    PriorConditions,
                                    DiagnosticProcedures,
                                    MeasValues = TRUE,
                                    Measurements,
                                    AlternativeDiagnosis,
                                    TreatmentProcedures,
                                    MedicationTreatment,
                                    Complications
                                    ) {
  errorMessage <- checkmate::makeAssertCollection()

# checking parameters

  checkmate::reportAssertions(collection = errorMessage)

  checkmate::assertCharacter(
    x = cohortDatabaseSchema,
    min.len = 0,
    max.len = 1,
    null.ok = TRUE,
    add = errorMessage
  )

  checkmate::assertCharacter(
    x = cdmDatabaseSchema,
    min.len = 1,
    add = errorMessage
  )

  checkmate::assertCharacter(
    x = vocabularyDatabaseSchema,
    min.len = 1,
    add = errorMessage
  )

  checkmate::assertCharacter(
    x = cohortTable,
    min.len = 1,
    add = errorMessage
  )

  checkmate::assertCharacter(
    x = databaseId,
    min.len = 1,
    max.len = 1,
    add = errorMessage
  )

  checkmate::assertCharacter(
    x = tempEmulationSchema,
    min.len = 1,
    null.ok = TRUE,
    add = errorMessage
  )

  checkmate::assertIntegerish(
    x = cohortDefinitionId,
    lower = 0,
    len = 1,
    add = errorMessage
  )

  checkmate::assertIntegerish(
    x = sampleSize,
    lower = 0,
    len = 1,
    null.ok = TRUE,
    add = errorMessage
  )

  if (is.null(personIds)) {
    checkmate::assertIntegerish(
      x = sampleSize,
      lower = 0,
      len = 1,
      null.ok = TRUE,
      add = errorMessage
    )
  } else {
    checkmate::assertIntegerish(
      x = personIds,
      lower = 0,
      min.len = 1,
      null.ok = TRUE
    )
  }

# create export folder

  exportFolder <- normalizePath(exportFolder, mustWork = FALSE)

  dir.create(
    path = exportFolder,
    showWarnings = FALSE,
    recursive = TRUE
  )

  checkmate::assertDirectory(
    x = exportFolder,
    access = "x",
    add = errorMessage
  )

  checkmate::reportAssertions(collection = errorMessage)

  ParallelLogger::addDefaultFileLogger(
    fileName = file.path(exportFolder, "log.txt"),
    name = "keeper_file_logger"
  )
  ParallelLogger::addDefaultErrorReportLogger(
    fileName = file.path(exportFolder, "errorReportR.txt"),
    name = "keeper_error_logger"
  )
  on.exit(ParallelLogger::unregisterLogger("keeper_file_logger", silent = TRUE))
  on.exit(
    ParallelLogger::unregisterLogger("keeper_error_logger", silent = TRUE),
    add = TRUE
  )

  originalDatabaseId <- databaseId

  cohortTableIsTemp <- FALSE
  if (is.null(cohortDatabaseSchema)) {
    if (grepl(
      pattern = "#",
      x = cohortTable,
      fixed = TRUE
    )) {
      cohortTableIsTemp <- TRUE
    } else {
      stop("cohortDatabaseSchema is NULL, but cohortTable is not temporary.")
    }
  }

  databaseId <- as.character(gsub(
    pattern = " ",
    replacement = "",
    x = databaseId
  ))

  if (nchar(databaseId) < nchar(originalDatabaseId)) {
    stop(paste0(
      "databaseId should not have space or underscore: ",
      originalDatabaseId
    ))
  }

  #XXX remove
 
 # rdsFileName <- paste0(
 #   "KEEPER_",
 #   abs(cohortDefinitionId),
 #   "_",
 #   databaseId,
 #   ".rds"
 # )

  # Set up connection to server ----------------------------------------------------
  

  # XXX support cohort definition id as a list

  if (is.null(connection)) {
    if (!is.null(connectionDetails)) {
      connection <- DatabaseConnector::connect(connectionDetails)
      on.exit(DatabaseConnector::disconnect(connection))
    } else {
      stop("No connection or connectionDetails provided.")
    }
  }

  if (cohortTableIsTemp) {
    DatabaseConnector::renderTranslateExecuteSql(
      connection = connection,
      sql = " DROP TABLE IF EXISTS #person_id_data;
                SELECT DISTINCT subject_id
                INTO #person_id_data
                FROM @cohort_table
                WHERE cohort_definition_id = @cohort_definition_id;",
      cohort_table = cohortTable,
      tempEmulationSchema = tempEmulationSchema,
      cohort_definition_id = cohortDefinitionId
    )
  } else { 
      DatabaseConnector::renderTranslateExecuteSql(
        connection = connection,
        sql = " DROP TABLE IF EXISTS #person_id_data;
                  SELECT DISTINCT subject_id
                  INTO #person_id_data
                  FROM @cohort_database_schema.@cohort_table
                  WHERE cohort_definition_id = @cohort_definition_id;",
        cohort_table = cohortTable,
        cohort_database_schema = cohortDatabaseSchema,
        tempEmulationSchema = tempEmulationSchema,
        cohort_definition_id = cohortDefinitionId
      )
    }

  if (!is.null(personIds)) {
    DatabaseConnector::insertTable(
      connection = connection,
      tableName = "#persons_to_filter",
      createTable = TRUE,
      dropTableIfExists = TRUE,
      tempTable = TRUE,
      tempEmulationSchema = tempEmulationSchema,
      progressBar = TRUE,
      bulkLoad = (Sys.getenv("bulkLoad") == TRUE),
      camelCaseToSnakeCase = TRUE,
      data = dplyr::tibble(subjectId = as.double(personIds) %>% unique())
    )

    DatabaseConnector::renderTranslateExecuteSql(
      connection = connection,
      sql = "     DROP TABLE IF EXISTS #person_id_data2;
                  SELECT DISTINCT a.subject_id
                  INTO #person_id_data2
                  FROM #person_id_data a
                  INNER JOIN #persons_to_filter b
                  ON a.subject_id = b.subject_id;

                  DROP TABLE IF EXISTS #person_id_data;
                  SELECT DISTINCT subject_id
                  INTO #person_id_data
                  FROM #person_id_data2;

                  DROP TABLE IF EXISTS #person_id_data2;
                  ",
      tempEmulationSchema = tempEmulationSchema
    )
  }

  # assign new id and filter to sample size
  DatabaseConnector::renderTranslateExecuteSql(
    connection = connection,
    sql = "   DROP TABLE IF EXISTS #persons_filter;
              SELECT new_id, subject_id person_id
              INTO #persons_filter
              FROM
              (
                SELECT *
                FROM
                (
                  SELECT ROW_NUMBER() OVER (ORDER BY NEWID()) AS new_id, subject_id
                  FROM #person_id_data
                ) f
    ) t
    WHERE new_id <= @sample_size;",
    tempEmulationSchema = tempEmulationSchema,
    sample_size = sampleSize
  )

  if (cohortTableIsTemp) {
    writeLines("Getting cohort table.")
    DatabaseConnector::renderTranslateExecuteSql(
      connection = connection,
      sql = " DROP TABLE IF EXISTS #pts_cohort;

              SELECT c.subject_id, p.new_id, c.cohort_start_date, c.cohort_end_date, c.cohort_definition_id
              INTO #pts_cohort
              FROM @cohort_table c
              INNER JOIN #persons_filter p
              ON c.subject_id = p.person_id
              WHERE c.cohort_definition_id = @cohort_definition_id
              ORDER BY c.subject_id, c.cohort_start_date;",
      cohort_table = cohortTable,
      tempEmulationSchema = tempEmulationSchema,
      cohort_definition_id = cohortDefinitionId,
      snakeCaseToCamelCase = TRUE
    ) 
  } else {
    writeLines("Getting cohort table.")
    DatabaseConnector::renderTranslateExecuteSql(
      connection = connection,
      sql = " DROP TABLE IF EXISTS #pts_cohort;

              SELECT c.subject_id, p.new_id, cohort_start_date, cohort_end_date, c.cohort_definition_id
              INTO #pts_cohort
              FROM @cohort_database_schema.@cohort_table c
              INNER JOIN #persons_filter p
              ON c.subject_id = p.person_id
              WHERE cohort_definition_id = @cohort_definition_id
          ORDER BY c.subject_id, cohort_start_date;",
      cohort_database_schema = cohortDatabaseSchema,
      cohort_table = cohortTable,
      tempEmulationSchema = tempEmulationSchema,
      cohort_definition_id = cohortDefinitionId,
      snakeCaseToCamelCase = TRUE
    )
  }

  # check if patients exist
  cohort <- DatabaseConnector::renderTranslateQuerySql(
      connection = connection,
      sql = "SELECT count(*) FROM #pts_cohort;")

  if (nrow(cohort) == 0) {
    warning("Cohort does not have the selected subject ids.")
    return(NULL)
  }

  # KEEPER code

pullDataSql <- SqlRender::readSql(system.file("sql/sql_server/pullData.sql", package = "KEEPER", mustWork = TRUE))

  writeLines("Getting patient data for KEEPER.")
   DatabaseConnector::renderTranslateExecuteSql(
    connection = connection,
    sql = pullDataSql,
    cdm_database_schema = cdmDatabaseSchema,
    tempEmulationSchema = tempEmulationSchema,
    snakeCaseToCamelCase = TRUE,
    meas_values = MeasValues,
    alternative_diagnosis = AlternativeDiagnosis,
    complications = Complications,
    diagnostic_procedures = DiagnosticProcedures,
    measurements = Measurements,
    medication_treatment = MedicationTreatment,
    prior_conditions = PriorConditions,
    prior_drugs = PriorDrugs,
    treatment_procedures = TreatmentProcedures
  ) 

# XXX consider loop for future
#list = c(presentation, visit_context, prior_conditions, prior_drugs, diagnostic_procedures, measurements, alternative_diagnosis, medication_treatment, treatment_procedures, complications)

#for (val in list){
##allfour <- lapply(setNames(paste("select * from", list),
#                          list),
#                  DBI::dbGetQuery, conn = con)}


# XXX adding cohort sets will require rewriting this code
presentation = DatabaseConnector::renderTranslateQuerySql(
      connection = connection,
      sql = "SELECT * FROM #presentation;",
      snakeCaseToCamelCase = TRUE) %>% as_tibble()

 subjects = presentation%>%
 dplyr::select(personId, newId, age, gender)%>%
 dplyr::distinct()  
      
 presentation = presentation%>%
  dplyr::group_by(personId) %>% 
  dplyr::summarise(presentation = stringr::str_c(conceptName, collapse = " ")) 


visit_context = DatabaseConnector::renderTranslateQuerySql(
      connection = connection,
      sql = "SELECT * FROM #visit_context;",
      snakeCaseToCamelCase = TRUE) %>% as_tibble()
      
visit_context = visit_context%>%
  dplyr::group_by(personId) %>% 
  dplyr::summarise(visit_context = stringr::str_c(conceptName, collapse = " ")) 


prior_conditions = DatabaseConnector::renderTranslateQuerySql(
      connection = connection,
      sql = "SELECT * FROM #prior_conditions;",
      snakeCaseToCamelCase = TRUE) %>% as_tibble()
      
prior_conditions = prior_conditions%>%
  dplyr::group_by(cohortDefinitionId, personId) %>% 
  dplyr::summarise(prior_conditions = stringr::str_c(conceptName, collapse = " ")) 


prior_drugs = DatabaseConnector::renderTranslateQuerySql(
      connection = connection,
      sql = "SELECT * FROM #prior_drugs;",
      snakeCaseToCamelCase = TRUE) %>% as_tibble()
      
prior_drugs = prior_drugs%>%
  dplyr::group_by(personId) %>% 
  dplyr::summarise(prior_drugs = stringr::str_c(conceptName, collapse = " ")) 

diagnostic_procedures = DatabaseConnector::renderTranslateQuerySql(
      connection = connection,
      sql = "SELECT * FROM #diagnostic_procedures;",
      snakeCaseToCamelCase = TRUE) %>% as_tibble()
      
diagnostic_procedures = diagnostic_procedures%>%
  dplyr::group_by(personId) %>% 
  dplyr::summarise(diagnostic_procedures = stringr::str_c(conceptName, collapse = " ")) 


measurements = DatabaseConnector::renderTranslateQuerySql(
      connection = connection,
      sql = "SELECT * FROM #measurements;",
      snakeCaseToCamelCase = TRUE) %>% as_tibble()
      
measurements = measurements%>%
  dplyr::group_by(personId) %>% 
  dplyr::summarise(measurements = stringr::str_c(conceptName, collapse = " ")) 


alternative_diagnosis = DatabaseConnector::renderTranslateQuerySql(
      connection = connection,
      sql = "SELECT * FROM #alternative_diagnosis;",
      snakeCaseToCamelCase = TRUE) %>% as_tibble()
      
alternative_diagnosis = alternative_diagnosis%>%
  dplyr::group_by(personId) %>% 
  dplyr::summarise(alternative_diagnosis = stringr::str_c(conceptName, collapse = " ")) 


medication_treatment = DatabaseConnector::renderTranslateQuerySql(
      connection = connection,
      sql = "SELECT * FROM #medication_treatment;",
      snakeCaseToCamelCase = TRUE) %>% as_tibble()
      
medication_treatment = medication_treatment%>%
  dplyr::group_by(personId) %>% 
  dplyr::summarise(medication_treatment = stringr::str_c(conceptName, collapse = " ")) 


treatment_procedures = DatabaseConnector::renderTranslateQuerySql(
      connection = connection,
      sql = "SELECT * FROM #treatment_procedures;",
      snakeCaseToCamelCase = TRUE) %>% as_tibble()
      
treatment_procedures = treatment_procedures%>%
  dplyr::group_by(personId) %>% 
  dplyr::summarise(treatment_procedures = stringr::str_c(conceptName, collapse = " ")) 

complications = DatabaseConnector::renderTranslateQuerySql(
      connection = connection,
      sql = "SELECT * FROM #complications;",
      snakeCaseToCamelCase = TRUE) %>% as_tibble()
      
complications = complications%>%
  dplyr::group_by(personId) %>% 
  dplyr::summarise(complications = stringr::str_c(conceptName, collapse = " ")) 

  writeLines("Writing KEEPER file.")


# XXXXX works weird with multiple strings in prior_conditions
  KEEPER = subjects%>%
  dplyr::left_join(presentation, by = "personId")%>%
  dplyr::left_join(visit_context, by = "personId")%>%
  dplyr::left_join(prior_conditions, by = "personId")%>%
  dplyr::left_join(prior_drugs, by = "personId")%>%
  dplyr::left_join(diagnostic_procedures, by = "personId")%>%
  dplyr::left_join(measurements, by = "personId")%>%
  dplyr::left_join(alternative_diagnosis, by = "personId")%>%
  dplyr::left_join(medication_treatment, by = "personId")%>%
  dplyr::left_join(treatment_procedures, by = "personId")%>%
  dplyr::left_join(complications, by = "personId")%>%
  dplyr::select(personId, newId, age, gender, presentation, prior_conditions, prior_drugs, diagnostic_procedures, measurements,
         alternative_diagnosis, treatment_procedures, medication_treatment, complications)%>%
  dplyr::distinct()%>%
  # add columns for review
  tibble::add_column(reviewer = NA, status = NA, index_misspecification = NA, notes = NA)
  
  KEEPER <- replace(KEEPER, is.na(KEEPER), "")
  KEEPER <- replaceId(data = KEEPER, useNewId = assignNewId)
  
  #XXX
  KEEPER%>%
  write.csv(paste0("KEEPER_cohort_", cohortDefinitionId,".csv"), row.names=F)




}

test_that("Create app with cohort data in temp table", {
  skip_if(skipCdmTests, "cdm settings not configured")

  library(dplyr)

  createCohortTableSql <- "
    DROP TABLE IF EXISTS #temp_cohort_table;

    SELECT o1.person_id subject_id,
            1 cohort_definition_id,
            o1.observation_period_start_date cohort_start_date,
            o1.observation_period_end_date cohort_end_date
    INTO #temp_cohort_table
    FROM @cdm_database_schema.observation_period o1
    INNER JOIN
          (
            SELECT person_id,
                    ROW_NUMBER() OVER (ORDER BY NEWID()) AS new_id
            FROM
              (
                SELECT DISTINCT person_id
                FROM @cdm_database_schema.observation_period
              ) a
          ) b
    ON o1.person_id = b.person_id
    WHERE new_id < 10
  ;"

  connection <-
    DatabaseConnector::connect(connectionDetails = connectionDetails)
  on.exit(DatabaseConnector::disconnect(connection))

  DatabaseConnector::renderTranslateExecuteSql(
    connection = connection,
    sql = createCohortTableSql,
    profile = FALSE,
    progressBar = FALSE,
    reportOverallTime = FALSE,
    cdm_database_schema = cdmDatabaseSchema
  )

  outputDir <- tempfile()

  outputLocation <- createCohortExplorerApp(
    connection = connection,
    cohortDatabaseSchema = NULL,
    cdmDatabaseSchema = cdmDatabaseSchema,
    vocabularyDatabaseSchema = vocabularyDatabaseSchema,
    cohortTable = "#temp_cohort_table",
    cohortDefinitionId = c(1),
    sampleSize = 100,
    databaseId = "databaseData",
    exportFolder = outputDir
  )

  testthat::expect_true(file.exists(file.path(outputDir, "data")))
})


test_that("Error because database has space", {
  skip_if(skipCdmTests, "cdm settings not configured")

  outputDir <- tempfile()

  testthat::expect_error(
    createCohortExplorerApp(
      connectionDetails = connectionDetails,
      cohortDatabaseSchema = cohortDatabaseSchema,
      cdmDatabaseSchema = cdmDatabaseSchema,
      vocabularyDatabaseSchema = vocabularyDatabaseSchema,
      cohortTable = cohortTable,
      cohortDefinitionId = c(1),
      sampleSize = 100,
      databaseId = "database Data",
      exportFolder = outputDir
    )
  )

  unlink(
    x = outputDir,
    recursive = TRUE,
    force = TRUE
  )
})

test_that("no connection or connection details", {
  skip_if(skipCdmTests, "cdm settings not configured")

  outputDir <- tempfile()

  testthat::expect_error(
    createCohortExplorerApp(
      cdmDatabaseSchema = cdmDatabaseSchema,
      vocabularyDatabaseSchema = vocabularyDatabaseSchema,
      cohortTable = cohortTable,
      cohortDefinitionId = c(1),
      sampleSize = 100,
      databaseId = "database Data",
      exportFolder = outputDir
    )
  )

  unlink(
    x = outputDir,
    recursive = TRUE,
    force = TRUE
  )
})

test_that("Cohort has no data", {
  skip_if(skipCdmTests, "cdm settings not configured")

  library(dplyr)

  createCohortTableSql <- "
    DROP TABLE IF EXISTS @cohort_database_schema.@cohort_table;

  CREATE TABLE @cohort_database_schema.@cohort_table (
  	cohort_definition_id BIGINT,
  	subject_id BIGINT,
  	cohort_start_date DATE,
  	cohort_end_date DATE
  );"

  DatabaseConnector::renderTranslateExecuteSql(
    connection = DatabaseConnector::connect(connectionDetails),
    sql = createCohortTableSql,
    profile = FALSE,
    progressBar = FALSE,
    reportOverallTime = FALSE,
    cohort_database_schema = cohortDatabaseSchema,
    cohort_table = cohortTable
  )

  outputDir <- tempfile()

  # cohort table has no subjects
  testthat::expect_warning(
    createCohortExplorerApp(
      connectionDetails = connectionDetails,
      cohortDatabaseSchema = cohortDatabaseSchema,
      cdmDatabaseSchema = cdmDatabaseSchema,
      vocabularyDatabaseSchema = vocabularyDatabaseSchema,
      cohortTable = cohortTable,
      cohortDefinitionId = c(1),
      sampleSize = 100,
      databaseId = "databaseData",
      exportFolder = outputDir
    )
  )

  unlink(
    x = outputDir,
    recursive = TRUE,
    force = TRUE
  )
})


test_that("create rand 100 in cohort", {
  skip_if(skipCdmTests, "cdm settings not configured")

  library(dplyr)

  connection <-
    DatabaseConnector::connect(connectionDetails = connectionDetails)
  on.exit(DatabaseConnector::disconnect(connection))

  # create a cohort with 1000 persons
  createCohortTableSql <- "
    DROP TABLE IF EXISTS @cohort_database_schema.@cohort_table;

    SELECT o1.person_id subject_id,
            1 cohort_definition_id,
            o1.observation_period_start_date cohort_start_date,
            o1.observation_period_end_date cohort_end_date
    INTO @cohort_database_schema.@cohort_table
    FROM @cdm_database_schema.observation_period o1
    INNER JOIN
          (
            SELECT person_id,
                    ROW_NUMBER() OVER (ORDER BY NEWID()) AS new_id
            FROM
              (
                SELECT DISTINCT person_id
                FROM @cdm_database_schema.observation_period
              ) a
          ) b
    ON o1.person_id = b.person_id
    WHERE new_id <= 1000
  ;"

  DatabaseConnector::renderTranslateExecuteSql(
    connection = connection,
    sql = createCohortTableSql,
    profile = FALSE,
    progressBar = FALSE,
    reportOverallTime = FALSE,
    cohort_database_schema = cohortDatabaseSchema,
    cdm_database_schema = cdmDatabaseSchema,
    cohort_table = cohortTable
  )

  outputDir <- tempfile()

  createCohortExplorerApp(
    connection = connection,
    cohortDatabaseSchema = cohortDatabaseSchema,
    cdmDatabaseSchema = cdmDatabaseSchema,
    vocabularyDatabaseSchema = vocabularyDatabaseSchema,
    cohortTable = cohortTable,
    cohortDefinitionId = c(1),
    sampleSize = 100,
    databaseId = "databaseData",
    exportFolder = outputDir
  )

  testthat::expect_true(file.exists(file.path(outputDir)))
  testthat::expect_true(file.exists(file.path(outputDir, "data")))
})



test_that("create rand 100 in cohort with date shifting", {
  skip_if(skipCdmTests, "cdm settings not configured")

  library(dplyr)

  connection <-
    DatabaseConnector::connect(connectionDetails = connectionDetails)
  on.exit(DatabaseConnector::disconnect(connection))

  # create a cohort with 1000 persons
  createCohortTableSql <- "
    DROP TABLE IF EXISTS @cohort_database_schema.@cohort_table;

    SELECT o1.person_id subject_id,
            1 cohort_definition_id,
            o1.observation_period_start_date cohort_start_date,
            o1.observation_period_end_date cohort_end_date
    INTO @cohort_database_schema.@cohort_table
    FROM @cdm_database_schema.observation_period o1
    INNER JOIN
          (
            SELECT person_id,
                    ROW_NUMBER() OVER (ORDER BY NEWID()) AS new_id
            FROM
              (
                SELECT DISTINCT person_id
                FROM @cdm_database_schema.observation_period
              ) a
          ) b
    ON o1.person_id = b.person_id
    WHERE new_id <= 1000
  ;"

  DatabaseConnector::renderTranslateExecuteSql(
    connection = connection,
    sql = createCohortTableSql,
    profile = FALSE,
    progressBar = FALSE,
    reportOverallTime = FALSE,
    cohort_database_schema = cohortDatabaseSchema,
    cdm_database_schema = cdmDatabaseSchema,
    cohort_table = cohortTable
  )

  outputDir <- tempfile()

  createCohortExplorerApp(
    connection = connection,
    cohortDatabaseSchema = cohortDatabaseSchema,
    cdmDatabaseSchema = cdmDatabaseSchema,
    vocabularyDatabaseSchema = vocabularyDatabaseSchema,
    cohortTable = cohortTable,
    cohortDefinitionId = c(1),
    sampleSize = 100,
    personIds = c(10, 11),
    databaseId = "databaseData",
    exportFolder = outputDir,
    assignNewId = TRUE,
    shiftDates = TRUE
  )

  testthat::expect_true(file.exists(file.path(outputDir)))
  testthat::expect_true(file.exists(file.path(outputDir, "data")))
})


test_that("do Not Export CohortData", {
  skip_if(skipCdmTests, "cdm settings not configured")

  library(dplyr)

  connection <-
    DatabaseConnector::connect(connectionDetails = connectionDetails)
  on.exit(DatabaseConnector::disconnect(connection))

  createCohortTableSql <- "
    DROP TABLE IF EXISTS @cohort_database_schema.@cohort_table;"

  DatabaseConnector::renderTranslateExecuteSql(
    connection = connection,
    sql = createCohortTableSql,
    profile = FALSE,
    progressBar = FALSE,
    reportOverallTime = FALSE,
    cohort_database_schema = cohortDatabaseSchema,
    cohort_table = cohortTable
  )
  outputDir <- tempfile()
  outputPath <- createKEEPER(
    connection = connection,
    cdmDatabaseSchema = cdmDatabaseSchema,
    vocabularyDatabaseSchema = vocabularyDatabaseSchema,
    cohortTable = cohortTable,
    sampleSize = 20,
    doNotExportCohortData = TRUE,
    databaseId = "databaseData",
    exportFolder = outputDir,
    MeasValues = TRUE,
    PriorConditions = c(201820,442793,443238,4016045,4065354,45757392, 4051114, 433968, 375545, 29555009, 4209145, 4034964, 380834, 4299544, 4226354, 4159742, 43530690, 433736,
                      320128, 4170226, 40443308, 441267, 4163735, 192963, 85828009),
    PriorDrugs = c(1730370, 21604490, 21601682, 21601855, 21601462, 21600280, 21602728, 1366773, 21602689, 21603923, 21603746),
    DiagnosticProcedures = c(40756884),
    Measurements	= c(3034962, 3000483, 3034962, 3000483, 3004501, 3033408, 3005131, 3024629, 3031266, 3037110, 3009261, 3022548, 3019210, 3025232, 3033819,
                   3000845, 3002666, 3004077, 3026300, 3014737, 3027198, 3025398, 3010300, 3020399, 3007332, 3025673, 3027457, 3010084, 3004410, 3005673),
    AlternativeDiagnosis = c(201820,442793,443238,4016045,4065354,45757392, 4051114, 433968, 375545, 29555009, 4209145, 4034964, 380834, 4299544, 4226354, 4159742, 43530690, 433736,
                           320128, 4170226, 40443308, 441267, 4163735, 192963, 85828009),
    TreatmentProcedures = c(40756884, 4143852, 2746768, 2746766),
    MedicationTreatment = c(741530, 42873378, 45774489, 1502809,1502826,1503297,1510202, 1515249,1516766,1525215,1529331,1530014,1547504,
                          1559684,1560171,1580747,1583722,1594973,1597756,19067100,1502905,1513876,1516976,1517998,1531601,1544838,1550023, 1567198,19122121,21600713),
    Complications =  c(201820,442793,443238,4016045,4065354,45757392, 4051114, 433968, 375545, 29555009, 4209145, 4034964,
                     380834, 4299544, 4226354, 4159742, 43530690, 433736, 320128, 4170226, 40443308, 441267, 4163735, 192963, 85828009) 

  )

# XXX
  testthat::expect_true(file.exists(
    file.path(
      outputDir,
      "data",
      "KEEPER.csv"
    )
  ))
})

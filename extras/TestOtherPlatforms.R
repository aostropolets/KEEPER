# Code to test KEEPER on database platforms not available to GitHub Actions
library(KEEPER)

exportFolder <- "s:/temp/KEEPER"

# RedShift
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "redshift",
  connectionString = keyring::key_get("redShiftConnectionStringOhdaCcae"),
  user = keyring::key_get("redShiftUserName"),
  password = keyring::key_get("redShiftPassword")
)
cdmDatabaseSchema <- "cdm_truven_ccae_v2136"
cohortDatabaseSchema <- "results_truven_ccae_v2136"
cohortTable <- "cohort"
cohortDefinitionId <- 544
tempEmulationSchema <- NULL
databaseId <- "CCAE"

# BigQuery
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "bigquery",
  connectionString = keyring::key_get("bigQueryConnString"),
  user = "",
  password = "")

cdmDatabaseSchema <- "synpuf_2m"
cohortDatabaseSchema <- "synpuf_2m"
cohortTable <- "cohort"
cohortDefinitionId <- 787641790
tempEmulationSchema <- "synpuf_2m_results"
databaseId <- "Synpuf"

# Code to find cohorts in cohort table:
# library(dplyr)
# connection <- DatabaseConnector::connect(connectionDetails)
# cohort <- tbl(connection, DatabaseConnector::inDatabaseSchema(cohortDatabaseSchema, cohortTable))
# cohort %>%
#   group_by(cohort_definition_id) %>%
#   summarise(cohort_count = n()) %>%
#   collect() %>%
#   SqlRender::snakeCaseToCamelCaseNames()
# DatabaseConnector::disconnect(connection)

KEEPER::createKEEPER(
  connectionDetails = connectionDetails,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cdmDatabaseSchema = cdmDatabaseSchema,
  vocabularyDatabaseSchema = cdmDatabaseSchema,
  tempEmulationSchema = tempEmulationSchema,
  cohortTable = cohortTable,
  cohortDefinitionId = cohortDefinitionId,
  exportFolder = exportFolder,
  databaseId = databaseId,
  shiftDates = TRUE,
  assignNewId = TRUE,
  MeasValues = TRUE,
  PriorConditions = c(201820,442793,443238,4016045,4065354,45757392, 4051114, 433968, 375545, 29555009, 4209145, 4034964, 380834, 4299544, 4226354, 4159742, 43530690, 433736,
                    320128, 4170226, 40443308, 441267, 4163735, 192963, 85828009),
  PriorDrugs = c(1730370, 21604490, 21601682, 21601855, 21601462, 21600280, 21602728, 1366773, 21602689, 21603923, 21603746),
  DiagnosticProcedures = "",
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

# Code to verify all temp tables have been cleaned up:
# connection <- DatabaseConnector::connect(connectionDetails)
# DatabaseConnector::dropEmulatedTempTables(connection, tempEmulationSchema)
# DatabaseConnector::disconnect(connection)

# SETUP --------------------------------------------------------------------
library(magrittr)
# Pre-requisites ----
# remotes::install_github('aostropolets/KEEPER')

cohortDefinitionIds <- c(256)

ROhdsiWebApi::authorizeWebApi(
  baseUrl = Sys.getenv("ohdsiAtlasPhenotype"),
  authMethod = "db",
  webApiUsername = keyring::key_get("ohdsiAtlasPhenotypeUser"),
  webApiPassword = keyring::key_get("ohdsiAtlasPhenotypePassword")
)

cohortDefinitionSet <-
  ROhdsiWebApi::getCohortDefinitionsMetaData(baseUrl = Sys.getenv("ohdsiAtlasPhenotype")) %>%
  dplyr::filter(id %in% c(cohortDefinitionIds)) %>%
  dplyr::select(id, name) %>%
  dplyr::rename(cohortId = id, cohortName = name) %>%
  dplyr::arrange(cohortId)

exportFolder <- "d:/temp/KEEPER"
projectCode <- "pl_"


######################################################################################
############## databaseIds to run cohort diagnostics on that source  #################
######################################################################################

databaseIds <-
  c(
    'truven_ccae',
    'truven_mdcd',
    'cprd',
    'jmdc',
    'optum_extended_dod',
    'optum_ehr',
    'truven_mdcr',
    'ims_australia_lpd',
    'ims_germany',
    'ims_france',
    'iqvia_amb_emr',
    'iqvia_pharmetrics_plus'
  )

for (i in (1:length(databaseIds))) {
  for (j in (1:length(cohortDefinitionIds))) {
    cdmSource <- cdmSources %>%
      dplyr::filter(.data$sequence == 1) %>%
      dplyr::filter(database == databaseIds[[i]])
    
    connectionDetails <-
      DatabaseConnector::createConnectionDetails(
        dbms = cdmSource$dbms,
        server = as.character(cdmSource$serverFinal),
        user = keyring::key_get(service = 'OHDSI_USER'),
        password = keyring::key_get(service = 'OHDSI_PASSWORD'),
        port = cdmSource$port
      )
    
    cohortTableName <- paste0(stringr::str_squish(projectCode),
                              stringr::str_squish(cdmSource$sourceKey))
    
    # EXECUTE --------------------------------------------------------------------
    tryCatch(
      expr = {
      KEEPER::createKEEPER(
      connectionDetails = connectionDetails,
      cohortDatabaseSchema = as.character(cdmSource$cohortDatabaseSchemaFinal),
      cdmDatabaseSchema = as.character(cdmSource$cdmDatabaseSchemaFinal),
      vocabularyDatabaseSchema = as.character(cdmSource$cdmDatabaseSchemaFinal),
      cohortTable = cohortTableName,
      cohortDefinitionId = cohortDefinitionSet[j, ]$cohortId,
      cohortName = cohortDefinitionSet[j, ]$cohortName,
      exportFolder = exportFolder,
      databaseId = SqlRender::snakeCaseToCamelCase(cdmSource$database),
      shiftDate = TRUE,
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
      },
      error = function(e) {
      }
    )
  }
}

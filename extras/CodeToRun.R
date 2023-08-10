# SETUP --------------------------------------------------------------------

# Pre-requisites ----
remotes::install_github('aostropolets/KEEPER')

# connection details ----
# Details for connecting to the server:
# See ?DatabaseConnector::createConnectionDetails for help
connectionDetails <-
  DatabaseConnector::createConnectionDetails(
    dbms = "postgresql",
    server = "some.server.com/ohdsi",
    user = "joe",
    password = "secret"
  )

# EXECUTE --------------------------------------------------------------------
KEEPER::createKEEPER(
  connectionDetails = connectionDetails,
  cohortDatabaseSchema = "cohort",
  cdmDatabaseSchema = "cdm",
  vocabularyDatabaseSchema = "cdm",
  cohortTable = "cohort",
  cohortDefinitionId = 1234,
  exportFolder = "export",
  databaseId = "ccae",
  cohortName = "my cohort",
  PriorConditions = c("my string"),
  PriorDrugs = c("my string"),
  DiagnosticProcedures = c("my string"),
  Measurements	== c("my string"),
  AlternativeDiagnosis = c("my string"),
  TreatmentProcedures = c("my string"),
  MedicationTreatment = c("my string"),
  Complications =  = c("my string")
)

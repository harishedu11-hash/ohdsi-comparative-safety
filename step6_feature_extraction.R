library(DatabaseConnector)
library(SqlRender)
library(Eunomia)
library(CohortMethod)
library(FeatureExtraction)
library(dplyr)

# 1. Connect to Eunomia
connectionDetails <- Eunomia::getEunomiaConnectionDetails()

cdmDatabaseSchema <- "main"
cohortDatabaseSchema <- "main"
cohortTable <- "cohort"

cat(">>> Step 6.1: Configuring default high-dimensional covariate settings...\n")

# Default baseline covariates: demographics, condition eras, drug eras, Charlson comorbidity index
covariateSettings <- FeatureExtraction::createDefaultCovariateSettings()

# Bundle covariate settings and study window filters into getDbCohortMethodDataArgs
getDataArgs <- CohortMethod::createGetDbCohortMethodDataArgs(
  washoutPeriod = 180,
  firstExposureOnly = TRUE,
  removeDuplicateSubjects = "remove all",
  covariateSettings = covariateSettings
)

cat(">>> Step 6.2: Extracting cohort method data (T=1, C=2, O=3)...\n")

cmdData <- CohortMethod::getDbCohortMethodData(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  targetId = 1,                 # Celecoxib
  comparatorId = 2,             # Diclofenac
  outcomeIds = 3,               # GI bleed
  exposureDatabaseSchema = cohortDatabaseSchema,
  exposureTable = cohortTable,
  outcomeDatabaseSchema = cohortDatabaseSchema,
  outcomeTable = cohortTable,
  getDbCohortMethodDataArgs = getDataArgs
)

cat("\n>>> Step 6.3: Inspecting extracted cohort and covariate metadata...\n")

# Summary of extracted cohort size
cohortSummary <- cmdData$cohorts %>% 
  dplyr::group_by(treatment) %>% 
  dplyr::summarise(patient_count = dplyr::n(), .groups = "drop") %>% 
  dplyr::collect()

print(cohortSummary)

# Number of distinct baseline covariates generated
covariateCount <- cmdData$covariateRef %>% 
  dplyr::count() %>% 
  dplyr::collect()

cat(sprintf("\nTotal unique baseline covariates generated: %d\n", covariateCount$n))

# Save the Andromeda object locally for subsequent steps
CohortMethod::saveCohortMethodData(cmdData, "cmData")

cat("\n[SUCCESS] Feature extraction completed and cached to 'cmData'.\n")

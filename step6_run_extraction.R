library(DatabaseConnector)
library(CohortMethod)
library(FeatureExtraction)
library(dplyr)

dbFile <- file.path(getwd(), "eunomia.sqlite")

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "sqlite",
  server = dbFile
)

cdmDatabaseSchema <- "main"
cohortDatabaseSchema <- "main"
cohortTable <- "cohort"

cat(">>> Step 6.2.1: Defining covariate settings and study arguments...\n")

# Use standard default baseline covariates
covariateSettings <- FeatureExtraction::createDefaultCovariateSettings()

getDataArgs <- CohortMethod::createGetDbCohortMethodDataArgs(
  washoutPeriod = 0,               # synthetic Eunomia users have varied lookback; keep 0 to retain synthetic sample
  firstExposureOnly = TRUE,
  removeDuplicateSubjects = "keep first",
  covariateSettings = covariateSettings
)

cat(">>> Step 6.2.2: Extracting CohortMethodData from eunomia.sqlite...\n")

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

cat("\n>>> Step 6.2.3: Cohort and Covariate Diagnostics...\n")

# Treatment arm breakdown (1 = Target / Celecoxib, 0 = Comparator / Diclofenac)
cohortSummary <- cmdData$cohorts %>% 
  dplyr::group_by(treatment) %>% 
  dplyr::summarise(patient_count = dplyr::n(), .groups = "drop") %>% 
  dplyr::collect()

print(cohortSummary)

# Total unique baseline covariates extracted
covariateCount <- cmdData$covariateRef %>% 
  dplyr::count() %>% 
  dplyr::collect()

cat(sprintf("\nTotal unique baseline covariates generated: %d\n", covariateCount$n))

# Check outcome count captured during observation
outcomeCount <- cmdData$outcomes %>% 
  dplyr::count() %>% 
  dplyr::collect()

cat(sprintf("Total outcome events linked: %d\n", outcomeCount$n))

# Save the Andromeda object to disk
if (dir.exists("cmData")) unlink("cmData", recursive = TRUE)
CohortMethod::saveCohortMethodData(cmdData, "cmData")

cat("\n[SUCCESS] Feature extraction completed and cached to 'cmData'.\n")

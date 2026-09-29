#!/usr/bin/env Rscript
# ==============================================================================
# Title: Comparative Safety of Celecoxib vs. Diclofenac for GI Bleeding Risk
# Design: New-User Active-Comparator Cohort Design (NUACCD) with 1:1 PS Matching
# Framework: OHDSI HADES (CohortMethod, Cyclops, FeatureExtraction, DatabaseConnector)
# ==============================================================================

suppressPackageStartupMessages({
  library(DatabaseConnector)
  library(SqlRender)
  library(Eunomia)
  library(CohortMethod)
  library(FeatureExtraction)
  library(Cyclops)
  library(dplyr)
  library(readr)
})

cat("====================================================================\n")
cat("      OHDSI Comparative Safety Study: Celecoxib vs. Diclofenac      \n")
cat("====================================================================\n\n")

# --- Stage 1: Database & Cohort Instantiation ---
cat(">>> Stage 1: Initializing Database & Target/Comparator/Outcome Cohorts...\n")
dbFile <- file.path(getwd(), "eunomia.sqlite")
if (!file.exists(dbFile)) {
  archivePath <- Eunomia::downloadEunomiaData(datasetName = "GiBleed")
  Eunomia::extractLoadData(from = archivePath, to = dbFile, dbms = "sqlite")
}

connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "sqlite", server = dbFile)
conn <- DatabaseConnector::connect(connectionDetails)

populateSql <- "
DELETE FROM main.cohort WHERE cohort_definition_id IN (1, 2, 3);
INSERT INTO main.cohort SELECT 1, person_id, drug_era_start_date, drug_era_end_date FROM main.drug_era WHERE drug_concept_id = 1118084;
INSERT INTO main.cohort SELECT 2, person_id, drug_era_start_date, drug_era_end_date FROM main.drug_era WHERE drug_concept_id = 1124300;
INSERT INTO main.cohort SELECT 3, person_id, condition_era_start_date, condition_era_end_date FROM main.condition_era WHERE condition_concept_id = 192671;
"
DatabaseConnector::executeSql(conn, populateSql)
DatabaseConnector::disconnect(conn)

# --- Stage 2: Feature Extraction ---
cat(">>> Stage 2: Extracting Baseline High-Dimensional Features...\n")
covariateSettings <- FeatureExtraction::createDefaultCovariateSettings()
getDataArgs <- CohortMethod::createGetDbCohortMethodDataArgs(
  washoutPeriod = 0,
  firstExposureOnly = TRUE,
  removeDuplicateSubjects = "keep first",
  covariateSettings = covariateSettings
)

cmdData <- CohortMethod::getDbCohortMethodData(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = "main",
  targetId = 1,
  comparatorId = 2,
  outcomeIds = 3,
  exposureDatabaseSchema = "main",
  exposureTable = "cohort",
  outcomeDatabaseSchema = "main",
  outcomeTable = "cohort",
  getDbCohortMethodDataArgs = getDataArgs
)
if (dir.exists("cmData")) unlink("cmData", recursive = TRUE)
CohortMethod::saveCohortMethodData(cmdData, "cmData")

# --- Stage 3: Study Population Construction (Time-at-Risk) ---
cat(">>> Stage 3: Constructing On-Treatment Study Population...\n")
studyPopArgs <- CohortMethod::createCreateStudyPopulationArgs(
  removeSubjectsWithPriorOutcome = TRUE,
  priorOutcomeLookback = 99999,
  minDaysAtRisk = 1,
  riskWindowStart = 1,
  startAnchor = "cohort start",
  riskWindowEnd = 30,
  endAnchor = "cohort end",
  censorAtNewRiskWindow = TRUE
)
studyPop <- CohortMethod::createStudyPopulation(
  cohortMethodData = cmdData,
  outcomeId = 3,
  createStudyPopulationArgs = studyPopArgs
)
saveRDS(studyPop, "studyPop.rds")

# --- Stage 4: Propensity Score Estimation ---
cat(">>> Stage 4: Fitting Lasso Regularized Logistic Regression (Cyclops)...\n")
exposureCovariates <- cmdData$covariateRef %>%
  dplyr::filter(conceptId %in% c(1118084, 1124300)) %>%
  dplyr::select(covariateId) %>%
  dplyr::collect()

psArgs <- CohortMethod::createCreatePsArgs(
  excludeCovariateIds = exposureCovariates$covariateId,
  prior = Cyclops::createPrior("laplace", variance = 0.01, useCrossValidation = TRUE),
  control = Cyclops::createControl(cvType = "auto", seed = 42, resetCoefficients = TRUE, startingVariance = 0.01, tolerance = 2e-07, cvRepetitions = 1, noiseLevel = "quiet"),
  stopOnError = FALSE,
  errorOnHighCorrelation = TRUE
)
ps <- CohortMethod::createPs(cohortMethodData = cmdData, population = studyPop, createPsArgs = psArgs)
saveRDS(ps, "ps_model.rds")

# --- Stage 5: PS Matching & Balance Evaluation ---
cat(">>> Stage 5: Performing 1:1 Greedy Caliper Matching & Balance Assessment...\n")
matchedPop <- CohortMethod::matchOnPs(
  population = ps,
  matchOnPsArgs = CohortMethod::createMatchOnPsArgs(caliper = 0.2, caliperScale = "standardized logit", maxRatio = 1)
)
saveRDS(matchedPop, "matchedPop.rds")

balance <- CohortMethod::computeCovariateBalance(population = matchedPop, cohortMethodData = cmdData)
dir.create("diagnostics", showWarnings = FALSE)
readr::write_csv(balance, "diagnostics/covariate_balance.csv")

# --- Stage 6: Outcome Modeling (Stratified Cox Regression) ---
cat(">>> Stage 6: Estimating Conditional Cox Proportional Hazards Model...\n")
outcomeModel <- CohortMethod::fitOutcomeModel(
  population = matchedPop,
  cohortMethodData = cmdData,
  fitOutcomeModelArgs = CohortMethod::createFitOutcomeModelArgs(modelType = "cox", stratified = TRUE, useCovariates = FALSE)
)
saveRDS(outcomeModel, "outcomeModel.rds")

# --- Stage 7: Publication Visualizations ---
cat(">>> Stage 7: Exporting Visual Artifacts...\n")
dir.create("figures", showWarnings = FALSE)

CohortMethod::plotPs(
  data = ps,
  scale = "preference",
  targetLabel = "Celecoxib",
  comparatorLabel = "Diclofenac",
  title = "Preference Score Distribution",
  fileName = "figures/ps_preference_distribution.png"
)

CohortMethod::plotCovariateBalanceScatterPlot(
  balance = balance,
  threshold = 0.1,
  beforeLabel = "Before Matching",
  afterLabel = "After Matching",
  title = "Covariate Balance (Standardized Mean Difference)",
  fileName = "figures/covariate_balance_scatter.png"
)

CohortMethod::plotKaplanMeier(
  population = matchedPop,
  targetLabel = "Celecoxib (Matched)",
  comparatorLabel = "Diclofenac (Matched)",
  title = "Kaplan-Meier Analysis of GI Bleeding Risk",
  includeZero = FALSE,
  confidenceIntervals = TRUE,
  fileName = "figures/kaplan_meier_survival.png"
)

hr <- exp(outcomeModel$outcomeModelTreatmentEstimate$logRr)
lb <- exp(outcomeModel$outcomeModelTreatmentEstimate$logLb95)
ub <- exp(outcomeModel$outcomeModelTreatmentEstimate$logUb95)
cat(sprintf("\n[COMPLETE] Analysis finished successfully. Matched HR = %.3f [%.3f, %.3f].\n", hr, lb, ub))

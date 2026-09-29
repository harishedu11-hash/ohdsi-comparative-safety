library(CohortMethod)
library(Cyclops)
library(dplyr)

cat(">>> Step 8.1: Loading study population and high-dimensional covariate data...\n")
cmData <- CohortMethod::loadCohortMethodData("cmData")
studyPop <- readRDS("studyPop.rds")

cat(">>> Step 8.2: Identifying and excluding exposure concepts (Celecoxib & Diclofenac)...\n")

# Find all covariate IDs associated with Celecoxib (1118084) and Diclofenac (1124300)
exposureCovariates <- cmData$covariateRef %>%
  dplyr::filter(conceptId %in% c(1118084, 1124300)) %>%
  dplyr::select(covariateId) %>%
  dplyr::collect()

excludeIds <- exposureCovariates$covariateId
cat(sprintf("Excluding %d exposure-derived covariate IDs from propensity model.\n", length(excludeIds)))

cat(">>> Step 8.3: Configuring regularized regression controls...\n")
prior <- Cyclops::createPrior(
  priorType = "laplace",
  variance = 0.01,
  useCrossValidation = TRUE
)

control <- Cyclops::createControl(
  cvType = "auto",
  seed = 42,
  resetCoefficients = TRUE,
  startingVariance = 0.01,
  tolerance = 2e-07,
  cvRepetitions = 1,
  noiseLevel = "quiet"
)

psArgs <- CohortMethod::createCreatePsArgs(
  excludeCovariateIds = excludeIds,
  prior = prior,
  control = control,
  stopOnError = FALSE,
  errorOnHighCorrelation = TRUE
)

cat(">>> Step 8.4: Fitting Propensity Score model with Cyclops...\n")
ps <- CohortMethod::createPs(
  cohortMethodData = cmData,
  population = studyPop,
  createPsArgs = psArgs
)

cat("\n>>> Step 8.5: Evaluating Propensity Score Model Performance...\n")
auc <- CohortMethod::computePsAuc(ps)
cat(sprintf("Propensity Score Model AUC: %.4f\n", auc))

# Inspect non-zero predictors retained by Lasso
psModel <- CohortMethod::getPsModel(ps, cmData)
nonZero <- psModel %>% dplyr::filter(!is.na(coefficient) & coefficient != 0)
cat(sprintf("Covariates retained with non-zero weights: %d out of %d\n", nrow(nonZero), nrow(psModel)))

cat("\nTop 5 predictive clinical covariates:\n")
topPredictors <- nonZero %>%
  dplyr::arrange(desc(abs(coefficient))) %>%
  dplyr::select(covariateName, coefficient) %>%
  head(5)
print(topPredictors)

# Persist the clean fitted PS object to disk
saveRDS(ps, file = "ps_model.rds")

cat("\n[SUCCESS] Clean propensity score model generated and persisted to 'ps_model.rds'.\n")

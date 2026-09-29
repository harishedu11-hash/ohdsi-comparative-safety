library(CohortMethod)
library(dplyr)

cat(">>> Step 10.1: Loading matched population and cohort method data...\n")
cmData <- CohortMethod::loadCohortMethodData("cmData")
matchedPop <- readRDS("matchedPop.rds")

cat(">>> Step 10.2: Configuring Conditional Cox Proportional Hazards Model...\n")
# Stratified by matched set (stratumId created by matchOnPs)
# modelType = "cox"
fitModelArgs <- CohortMethod::createFitOutcomeModelArgs(
  modelType = "cox",
  stratified = TRUE,
  useCovariates = FALSE,
  inversePtWeighting = FALSE
)

cat(">>> Step 10.3: Fitting Outcome Model...\n")
outcomeModel <- CohortMethod::fitOutcomeModel(
  population = matchedPop,
  cohortMethodData = cmData,
  fitOutcomeModelArgs = fitModelArgs
)

cat("\n=======================================================\n")
cat("            STUDY OUTCOME ESTIMATION RESULTS           \n")
cat("=======================================================\n")

# Extract clinical point estimates
hr <- exp(outcomeModel$outcomeModelTreatmentEstimate$logRr)
lb <- exp(outcomeModel$outcomeModelTreatmentEstimate$logLb95)
ub <- exp(outcomeModel$outcomeModelTreatmentEstimate$logUb95)
p  <- outcomeModel$outcomeModelTreatmentEstimate$p
se <- outcomeModel$outcomeModelTreatmentEstimate$seLogRr

cat(sprintf("Target Cohort     : Celecoxib (New Users)\n"))
cat(sprintf("Comparator Cohort : Diclofenac (New Users)\n"))
cat(sprintf("Outcome           : Gastrointestinal (GI) Bleed\n"))
cat(sprintf("Analysis Model    : 1:1 Matched Conditional Cox Regression\n\n"))

cat(sprintf("Hazard Ratio (HR) : %.3f\n", hr))
cat(sprintf("95%% CI            : [%.3f, %.3f]\n", lb, ub))
cat(sprintf("Standard Error    : %.4f\n", se))
cat(sprintf("p-value           : %.4e\n", p))
cat("=======================================================\n\n")

# Event breakdown in matched population
eventsSummary <- matchedPop %>%
  dplyr::group_by(treatment) %>%
  dplyr::summarise(
    patients = dplyr::n(),
    events = sum(outcomeCount > 0),
    person_days = sum(survivalTime),
    incidence_rate_per_1000py = (sum(outcomeCount > 0) / sum(survivalTime)) * 365.25 * 1000,
    .groups = "drop"
  )
print(eventsSummary)

# Persist fitted model to disk
saveRDS(outcomeModel, file = "outcomeModel.rds")

cat("\n[SUCCESS] Outcome model estimated and cached to 'outcomeModel.rds'.\n")

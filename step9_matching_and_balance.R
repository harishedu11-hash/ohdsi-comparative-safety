library(CohortMethod)
library(dplyr)
library(ggplot2)

cat(">>> Step 9.1: Loading fitted Propensity Scores and CohortMethodData...\n")
cmData <- CohortMethod::loadCohortMethodData("cmData")
ps <- readRDS("ps_model.rds")

cat(">>> Step 9.2: Checking match arguments and performing 1:1 PS Matching...\n")

# Use createMatchOnPsArgs to match Target to Comparator within a 0.2 caliper
matchArgs <- CohortMethod::createMatchOnPsArgs(
  caliper = 0.2,
  caliperScale = "standardized logit",
  maxRatio = 1
)

matchedPop <- CohortMethod::matchOnPs(
  population = ps,
  matchOnPsArgs = matchArgs
)

cat(sprintf("Patients prior to matching: %d (Target: %d, Comparator: %d)\n",
            nrow(ps), sum(ps$treatment == 1), sum(ps$treatment == 0)))
cat(sprintf("Patients after 1:1 matching: %d (Target: %d, Comparator: %d)\n",
            nrow(matchedPop), sum(matchedPop$treatment == 1), sum(matchedPop$treatment == 0)))

cat("\n>>> Step 9.3: Computing Covariate Balance (Pre vs. Post Matching)...\n")
# Compute standardized mean difference across all baseline covariates
balance <- CohortMethod::computeCovariateBalance(
  population = matchedPop,
  cohortMethodData = cmData
)

# Summary of balance
beforeSMD <- abs(balance$beforeMatchingStdDiff)
afterSMD <- abs(balance$afterMatchingStdDiff)

cat(sprintf("Baseline covariates evaluated: %d\n", nrow(balance)))
cat(sprintf("Covariates with SMD > 0.1 before matching: %d (%.1f%%)\n",
            sum(beforeSMD > 0.1, na.rm = TRUE),
            100 * mean(beforeSMD > 0.1, na.rm = TRUE)))
cat(sprintf("Covariates with SMD > 0.1 after matching: %d (%.1f%%)\n",
            sum(afterSMD > 0.1, na.rm = TRUE),
            100 * mean(afterSMD > 0.1, na.rm = TRUE)))

maxAfterSMD <- max(afterSMD, na.rm = TRUE)
cat(sprintf("Maximum SMD after matching: %.4f\n", maxAfterSMD))

cat("\n>>> Step 9.4: Exporting diagnostic tables and persisting matched population...\n")
dir.create("diagnostics", showWarnings = FALSE)

# Save balance table to CSV for presentation and report generation
readr::write_csv(balance, "diagnostics/covariate_balance.csv")

# Save matched population
saveRDS(matchedPop, file = "matchedPop.rds")

cat("[SUCCESS] Matching and balance computation completed. Artifacts saved.\n")

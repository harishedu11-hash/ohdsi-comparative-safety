library(CohortMethod)
library(dplyr)

cat(">>> Step 7.1: Loading extracted CohortMethodData from 'cmData'...\n")
cmData <- CohortMethod::loadCohortMethodData("cmData")

cat(">>> Step 7.2: Defining Time-at-Risk (TAR) and inclusion criteria...\n")

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
  cohortMethodData = cmData,
  outcomeId = 3,
  createStudyPopulationArgs = studyPopArgs
)

cat("\n>>> Step 7.3: Population Attrition Summary...\n")
attrition <- CohortMethod::getAttritionTable(studyPop)
print(attrition)

cat("\n>>> Step 7.4: Schema inspection of study population...\n")
cat("Columns in studyPop:\n")
print(names(studyPop))

# Identify the event column dynamically (usually outcomeCount or daysToEvent)
eventCol <- if ("outcomeCount" %in% names(studyPop)) "outcomeCount" else if ("events" %in% names(studyPop)) "events" else NULL

cat("\n>>> Step 7.5: Treatment arm metrics in analytical population...\n")
if (!is.null(eventCol)) {
  popSummary <- studyPop %>%
    dplyr::group_by(treatment) %>%
    dplyr::summarise(
      patients = dplyr::n(),
      total_outcomes = sum(.data[[eventCol]] > 0),
      total_person_days = sum(survivalTime),
      incidence_rate_per_1000py = (sum(.data[[eventCol]] > 0) / sum(survivalTime)) * 365.25 * 1000,
      .groups = "drop"
    )
  print(popSummary)
} else {
  print(table(studyPop$treatment))
}

# Save analytical population for downstream Propensity Score modeling
saveRDS(studyPop, file = "studyPop.rds")

cat("\n[SUCCESS] Analytical study population defined and persisted to 'studyPop.rds'.\n")

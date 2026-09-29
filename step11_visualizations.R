library(CohortMethod)
library(ggplot2)
library(dplyr)

figuresDir <- file.path(getwd(), "figures")
dir.create(figuresDir, showWarnings = FALSE)

cat(">>> Step 11.1: Loading study artifacts...\n")
cmData <- CohortMethod::loadCohortMethodData("cmData")
ps <- readRDS("ps_model.rds")
matchedPop <- readRDS("matchedPop.rds")
balance <- readr::read_csv("diagnostics/covariate_balance.csv", show_col_types = FALSE)

cat(">>> Step 11.2: Generating Preference Score Distribution Plot...\n")
psPlotFile <- file.path(figuresDir, "ps_preference_distribution.png")
CohortMethod::plotPs(
  data = ps,
  scale = "preference",
  targetLabel = "Celecoxib",
  comparatorLabel = "Diclofenac",
  title = "Preference Score Distribution (Clinical Equipoise)",
  showCountsLabel = TRUE,
  showAucLabel = TRUE,
  showEquipoiseLabel = TRUE,
  fileName = psPlotFile
)
cat("Saved:", psPlotFile, "\n")

cat(">>> Step 11.3: Generating Covariate Balance Scatter Plot (Love Plot)...\n")
balancePlotFile <- file.path(figuresDir, "covariate_balance_scatter.png")
CohortMethod::plotCovariateBalanceScatterPlot(
  balance = balance,
  threshold = 0.1,
  beforeLabel = "Before PS Matching",
  afterLabel = "After 1:1 PS Matching",
  title = "Standardized Mean Difference (Covariate Balance)",
  showCovariateCountLabel = TRUE,
  fileName = balancePlotFile
)
cat("Saved:", balancePlotFile, "\n")

cat(">>> Step 11.4: Generating Kaplan-Meier Survival Curve...\n")
kmPlotFile <- file.path(figuresDir, "kaplan_meier_survival.png")
CohortMethod::plotKaplanMeier(
  population = matchedPop,
  targetLabel = "Celecoxib (Matched)",
  comparatorLabel = "Diclofenac (Matched)",
  title = "Kaplan-Meier: GI Bleeding Risk in Matched Cohort",
  includeZero = FALSE,
  confidenceIntervals = TRUE,
  fileName = kmPlotFile
)
cat("Saved:", kmPlotFile, "\n")

cat("\n>>> Step 11.5: Verifying exported visual artifacts:\n")
figFiles <- list.files(figuresDir, full.names = TRUE)
for (f in figFiles) {
  cat(sprintf(" - %s (%d KB)\n", basename(f), round(file.size(f) / 1024)))
}

cat("\n[SUCCESS] Visualizations successfully exported to 'figures/'.\n")

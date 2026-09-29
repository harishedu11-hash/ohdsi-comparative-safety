library(DatabaseConnector)
library(SqlRender)
library(Eunomia)
library(dplyr)

# 1. Connect to Eunomia
connectionDetails <- Eunomia::getEunomiaConnectionDetails()
connection <- DatabaseConnector::connect(connectionDetails)

cdmDatabaseSchema <- "main"
cohortDatabaseSchema <- "main"
cohortTable <- "cohort"

cat(">>> Step 5.1: Querying available cohorts in Eunomia...\n")

# Eunomia contains standard pre-generated cohorts:
# 1 = Celecoxib (Target)
# 2 = Diclofenac (Comparator)
# 3 = GI bleed (Outcome)
sql <- "
SELECT cohort_definition_id, COUNT(*) AS subject_count, COUNT(DISTINCT subject_id) AS distinct_patients
FROM @cohort_database_schema.@cohort_table
GROUP BY cohort_definition_id
ORDER BY cohort_definition_id;
"
renderedSql <- SqlRender::render(
  sql,
  cohort_database_schema = cohortDatabaseSchema,
  cohort_table = cohortTable
)
translatedSql <- SqlRender::translate(renderedSql, targetDialect = connectionDetails$dbms)
cohortCounts <- DatabaseConnector::querySql(connection, translatedSql)
names(cohortCounts) <- tolower(names(cohortCounts))

# Map definitions
cohortMap <- data.frame(
  cohort_definition_id = c(1, 2, 3),
  cohort_name = c("Target: Celecoxib (New Users)", "Comparator: Diclofenac (New Users)", "Outcome: GI Bleed"),
  stringsAsFactors = FALSE
)

cohortSummary <- merge(cohortMap, cohortCounts, by = "cohort_definition_id", all.x = TRUE)
print(cohortSummary)

cat("\n>>> Step 5.2: Inspecting patient overlap across Target and Comparator...\n")
overlapSql <- "
SELECT 
  COUNT(DISTINCT t.subject_id) AS target_patients,
  COUNT(DISTINCT c.subject_id) AS comparator_patients,
  COUNT(DISTINCT CASE WHEN t.subject_id = c.subject_id THEN t.subject_id END) AS overlapping_patients
FROM (SELECT subject_id FROM @cohort_database_schema.@cohort_table WHERE cohort_definition_id = 1) t
FULL OUTER JOIN (SELECT subject_id FROM @cohort_database_schema.@cohort_table WHERE cohort_definition_id = 2) c
  ON t.subject_id = c.subject_id;
"
overlapRendered <- SqlRender::render(
  overlapSql,
  cohort_database_schema = cohortDatabaseSchema,
  cohort_table = cohortTable
)
overlapTranslated <- SqlRender::translate(overlapRendered, targetDialect = connectionDetails$dbms)
overlapRes <- DatabaseConnector::querySql(connection, overlapTranslated)
names(overlapRes) <- tolower(names(overlapRes))
print(overlapRes)

DatabaseConnector::disconnect(connection)
cat("\n[SUCCESS] Cohort verification complete.\n")

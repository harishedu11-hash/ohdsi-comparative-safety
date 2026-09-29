library(DatabaseConnector)
library(SqlRender)
library(Eunomia)

dbFile <- file.path(getwd(), "eunomia.sqlite")

if (!file.exists(dbFile)) {
  cat("Extracting Eunomia dataset into persistent local file:", dbFile, "...\n")
  # Download dataset zip if not cached, then extract directly to dbFile
  archivePath <- Eunomia::downloadEunomiaData(datasetName = "GiBleed")
  Eunomia::extractLoadData(from = archivePath, to = dbFile, dbms = "sqlite")
} else {
  cat("Found existing local Eunomia database at:", dbFile, "\n")
}

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "sqlite",
  server = dbFile
)

conn <- DatabaseConnector::connect(connectionDetails)

cat("\n>>> Checking exposure counts in DRUG_ERA...\n")
# Celecoxib: 1118084 | Diclofenac: 1124300 | GI Bleed: 192671
drugSql <- "
SELECT drug_concept_id, COUNT(*) AS occurrences, COUNT(DISTINCT person_id) AS patients
FROM main.drug_era
WHERE drug_concept_id IN (1118084, 1124300)
GROUP BY drug_concept_id;
"
drugs <- DatabaseConnector::querySql(conn, drugSql)
names(drugs) <- tolower(names(drugs))
print(drugs)

cat("\n>>> Populating cohort table...\n")
populateSql <- "
DELETE FROM main.cohort WHERE cohort_definition_id IN (1, 2, 3);

-- Target: Celecoxib (1118084)
INSERT INTO main.cohort (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT 1 AS cohort_definition_id,
       person_id AS subject_id,
       drug_era_start_date AS cohort_start_date,
       drug_era_end_date AS cohort_end_date
FROM main.drug_era
WHERE drug_concept_id = 1118084;

-- Comparator: Diclofenac (1124300)
INSERT INTO main.cohort (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT 2 AS cohort_definition_id,
       person_id AS subject_id,
       drug_era_start_date AS cohort_start_date,
       drug_era_end_date AS cohort_end_date
FROM main.drug_era
WHERE drug_concept_id = 1124300;

-- Outcome: GI Bleed (192671)
INSERT INTO main.cohort (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT 3 AS cohort_definition_id,
       person_id AS subject_id,
       condition_era_start_date AS cohort_start_date,
       condition_era_end_date AS cohort_end_date
FROM main.condition_era
WHERE condition_concept_id = 192671;
"

DatabaseConnector::executeSql(conn, populateSql)

cat("\n>>> Verifying instantiated cohort counts:\n")
verifySql <- "
SELECT cohort_definition_id, COUNT(*) AS total_records, COUNT(DISTINCT subject_id) AS distinct_subjects
FROM main.cohort
GROUP BY cohort_definition_id
ORDER BY cohort_definition_id;
"
res <- DatabaseConnector::querySql(conn, verifySql)
names(res) <- tolower(names(res))
print(res)

DatabaseConnector::disconnect(conn)
cat("\n[SUCCESS] Cohorts instantiated successfully in local persistent database.\n")

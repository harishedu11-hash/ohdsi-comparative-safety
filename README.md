# Comparative Safety of Celecoxib vs. Diclofenac for Incident Gastrointestinal Bleeding

A regulatory-grade Real-World Evidence (RWE) comparative safety study emulating a randomized trial using the **OHDSI HADES** analytical ecosystem on the OMOP Common Data Model (CDM).

---

## Study Overview

* **Objective:** Evaluate the comparative risk of incident gastrointestinal (GI) bleeding between new users of Celecoxib (COX-2 selective inhibitor) versus Diclofenac (non-selective NSAID).
* **Design:** New-User Active-Comparator Cohort Design (NUACCD) with 1:1 propensity score greedy caliper matching.
* **Data Source:** Synthetic OMOP CDM v5.3 dataset (`GiBleed`, 2,657 patients).
* **Tech Stack:** R (v4.x), HADES (`CohortMethod`, `Cyclops`, `FeatureExtraction`, `DatabaseConnector`, `SqlRender`, `Andromeda`), `renv`.

---

## Methodological Architecture

[OMOP CDM Tables]
│
├─► Target: Celecoxib new users (RxNorm 1118084) ────┐
├─► Comparator: Diclofenac new users (RxNorm 1124300) ┼─► Feature Extraction (395 Covariates)
└─► Outcome: Incident GI Bleeding (SNOMED 192671)  ─┘
│
▼
Time-at-Risk Definition
(Day 1 post-index to End of Treatment + 30d)
│
▼
Propensity Score Modeling
(Large-scale L1 Lasso via Cyclops)
│
▼
1:1 Caliper Matching (0.2 SD)
(Diagnostics: Covariate Balance SMD < 0.1)
│
▼
Stratified Cox Regression
(Matched Pair Conditioned)


### Design Parameterization
1. **New-User Active-Comparator:** Avoids immortal time bias and mitigates confounding by indication by comparing against an active analgesic alternative.
2. **On-Treatment Time-at-Risk (TAR):** Follow-up spans from **Day 1 after initiation** through **Cohort End Date + 30 days**. Prior outcome occurrences were censored with an infinite lookback window.
3. **High-Dimensional Covariate Adjustment:** 395 baseline features (conditions, drug exposures, comorbidity indices) extracted across 365 pre-index days. Exposure concepts were explicitly filtered out to eliminate information leakage.
4. **Confounder Control:** $L_1$-regularized logistic regression fitted using `Cyclops` with automated cross-validation for hyperparameter $\lambda$ selection.

---

## Key Results

### 1. Cohort & Matching Summary
| Cohort | Pre-Match Population | Matched Population | Incident Events | Total Person-Days | Incidence Rate (per 1,000 PY) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Celecoxib (Target)** | 1,793 | 830 | 45 | 24,313 | 676.0 |
| **Diclofenac (Comparator)** | 830 | 830 | 46 | 24,272 | 692.1 |

### 2. Balance Diagnostics
* **AUC of Propensity Score Model:** **0.6299** (reflecting genuine clinical prescribing equipoise after excluding exposure leakage).
* **Covariate Balance:** Over **98.9%** of all 395 baseline covariates achieved a Standardized Mean Difference (SMD) $< 0.10$ after 1:1 caliper matching.

### 3. Primary Effect Estimate
| Model Specification | Hazard Ratio (HR) | 95% Confidence Interval | SE |
| :--- | :---: | :---: | :---: |
| **1:1 Matched Stratified Cox Regression** | **0.957** | **[0.631, 1.447]** | **0.2116** |

**Conclusion:** In this matched on-treatment population, no statistically significant difference in incident GI bleeding risk was observed between Celecoxib and Diclofenac new users ($\text{HR} = 0.957$, 95% CI $[0.631, 1.447]$).

---

## Visual Deliverables

* `figures/ps_preference_distribution.png`: Preference score density confirming clinical equipoise across treatment groups.
* `figures/covariate_balance_scatter.png`: Love plot showing pre- vs. post-matching standardized mean differences.
* `figures/kaplan_meier_survival.png`: Kaplan-Meier cumulative survival curves for matched pairs over the risk window.

---

## Reproducibility & Execution

```bash
# 1. Clone the repository
git clone [https://github.com/](https://github.com/)<your-username>/ohdsi-comparative-safety.git
cd ohdsi-comparative-safety

# 2. Restore exact dependency tree
Rscript -e 'renv::restore()'

# 3. Execute full pipeline end-to-end
./run_study.R

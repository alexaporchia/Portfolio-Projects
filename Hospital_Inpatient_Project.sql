--	Creating table to import Hospital Inpatient Stay New York 2021 data

CREATE TABLE HospitalInpatientNY2021(
Year INTEGER,
State VARCHAR(50),
Classification VARCHAR(200),
Listed_or_Principal VARCHAR(100),
Characteristics VARCHAR(150),
Characteristic_Levels VARCHAR(150),
Diagnoses_Procedures VARCHAR(250),
Outcome VARCHAR(300),
Measure_Value NUMERIC
); 

--	Creating table to import Hospital Inpatient Stay California 2021 data

CREATE TABLE HospitalInpatientCA2021(
Year INTEGER,
State VARCHAR(50),
Classification VARCHAR(200),
Listed_or_Principal VARCHAR(100),
Characteristics VARCHAR(150),
Characteristic_Levels VARCHAR(150),
Diagnoses_Procedures VARCHAR(250),
Outcome VARCHAR(300),
Measure_Value NUMERIC
); 

-- Verifying data was successfully imported

SELECT *
FROM HospitalInpatientNY2021;

SELECT COUNT(*)
FROM HospitalInpatientNY2021;

SELECT *
FROM HospitalInpatientCA2021;

SELECT COUNT(*)
FROM HospitalInpatientCA2021;

/*Exploring the outcome characteristics in the data. Aggregate hospital charges, Average hospital charges per stay, 
Average length of stay, and number of discharges are of interest as they relate to health plan costs and benefits analysis/modeling.*/

SELECT DISTINCT(outcome)
FROM HospitalInpatientNY2021
ORDER BY outcome;

-- Select data to use

SELECT characteristic_levels AS Patient_Age_Group, diagnoses_procedures, outcome AS Measure, measure_value
FROM HospitalInpatientNY2021
ORDER BY 2;

-- Identifying highest cost NY diagnosis/procedure codes by Total Aggregate Hospital Charges

SELECT state, diagnoses_procedures, outcome AS Measure, SUM(CAST(measure_value AS MONEY)) AS Total_Agg_Hospital_Charges
FROM HospitalInpatientNY2021
WHERE outcome = 'Aggregate hospital charges' AND measure_value IS NOT NULL
GROUP BY state, diagnoses_procedures, outcome
ORDER BY SUM(measure_value) DESC; 

-- Identifying highest cost CA diagnosis/procedure codes by Total Aggregate Hospital Charges

SELECT state, diagnoses_procedures, outcome AS Measure, SUM(CAST(measure_value AS MONEY)) AS Total_Agg_Hospital_Charges
FROM HospitalInpatientCA2021
WHERE outcome = 'Aggregate hospital charges' AND measure_value IS NOT NULL
GROUP BY state, diagnoses_procedures, outcome
ORDER BY SUM(measure_value) DESC; 

-- Identifying Total Aggregate Charges for all codes in both states

SELECT ca.outcome, SUM(CAST(COALESCE(ca.measure_value, 0) AS MONEY)) AS CATotalAggCharges, SUM(CAST(COALESCE(ny.measure_value, 0) AS MONEY)) AS NYTotalAggCharges
FROM HospitalInpatientCA2021 CA
LEFT JOIN HospitalInpatientNY2021 NY
ON ca.outcome = ny.outcome AND
ca.diagnoses_procedures = ny.diagnoses_procedures AND
ca.characteristic_levels = ny.characteristic_levels
WHERE CA.outcome = 'Aggregate hospital charges'
GROUP BY ca.outcome;

-- Comparing Total Aggregate Hosp Charges per diagnosis/procedure by State

SELECT CA.diagnoses_procedures, SUM(CAST(COALESCE(CA.measure_value, 0) AS MONEY)) AS CA_TotAggCharges, SUM(CAST(COALESCE(NY.measure_value, 0) AS MONEY)) AS NY_TotAggCharges
FROM HospitalInpatientCA2021 CA
	LEFT JOIN HospitalInpatientNY2021 NY
	ON CA.diagnoses_procedures = NY.diagnoses_procedures
	AND CA.outcome = NY.outcome
	AND CA.characteristic_levels = NY.characteristic_levels
WHERE CA.outcome = 'Aggregate hospital charges'
GROUP BY CA.diagnoses_procedures
ORDER BY NY_TotAggCharges DESC;

-- Using Temp Table to identify Discharge Count and add combined Rolling Total for both states on prior query

DROP TABLE IF EXISTS CostComparison; 

CREATE TEMP TABLE CostComparison
(
Diagnoses_procedures VARCHAR(250), 
CADischargeCount NUMERIC, 
NYDischargeCount NUMERIC,
CA_TotAggCharges MONEY,
NY_TotAggCharges MONEY,
AggChargeTotal MONEY
);

INSERT INTO CostComparison
(
SELECT CA.diagnoses_procedures,
SUM(CASE
	WHEN CA.outcome = 'Number of discharges'
	THEN CA.measure_value
	ELSE NULL END) AS CADischargeCount, 
SUM(CASE
	WHEN NY.outcome = 'Number of discharges'
	THEN COALESCE(NY.measure_value, 0)
	ELSE 0 END) AS NYDischargeCount,
SUM(CASE
	WHEN CA.outcome = 'Aggregate hospital charges'
	THEN CA.measure_value
	ELSE NULL END) AS CA_TotAggCharges,
SUM(CASE
	WHEN NY.outcome = 'Aggregate hospital charges'
	THEN COALESCE(NY.measure_value, 0)
	ELSE 0 END) AS NY_TotAggCharges, 
SUM(CASE
	WHEN ca.outcome = 'Aggregate hospital charges' AND (NY.outcome = 'Aggregate hospital charges' OR NY.outcome IS NULL)
	THEN COALESCE(CA.measure_value, 0) + COALESCE(NY.measure_value, 0)
	ELSE 0 END) AS AggChargeTotal
FROM HospitalInpatientCA2021 CA
	LEFT JOIN HospitalInpatientNY2021 NY
	ON CA.diagnoses_procedures = NY.diagnoses_procedures
	AND CA.outcome = NY.outcome
	AND CA.characteristic_levels = NY.characteristic_levels
WHERE CA.outcome = 'Aggregate hospital charges' OR CA.outcome = 'Number of discharges'
GROUP BY CA.diagnoses_procedures
ORDER BY AggChargeTotal DESC
);

SELECT *,
	SUM(AggChargeTotal) OVER(ORDER BY diagnoses_procedures) AS RollingAggChargeTotal
FROM CostComparison
ORDER BY RollingAggChargeTotal;

/*Comparing Total Aggregate Hosp Charges per diagnosis/procedure by State. Rank diagnosis/procedure by combined Total Aggregate Charges
for both states*/

SELECT *,
	DENSE_RANK() OVER(ORDER BY AggChargeTotal DESC) AS RankAggChargeTotal
FROM CostComparison
ORDER BY RankAggChargeTotal;

-- Creating View to store data for later visualizations

CREATE VIEW CostComparison AS
(SELECT CA.diagnoses_procedures,
SUM(CASE
	WHEN CA.outcome = 'Number of discharges'
	THEN CA.measure_value
	ELSE NULL END) AS CADischargeCount, 
SUM(CASE
	WHEN NY.outcome = 'Number of discharges'
	THEN COALESCE(NY.measure_value, 0)
	ELSE 0 END) AS NYDischargeCount,
SUM(CASE
	WHEN CA.outcome = 'Aggregate hospital charges'
	THEN CA.measure_value
	ELSE NULL END) AS CA_TotAggCharges,
SUM(CASE
	WHEN NY.outcome = 'Aggregate hospital charges'
	THEN COALESCE(NY.measure_value, 0)
	ELSE 0 END) AS NY_TotAggCharges, 
SUM(CASE
	WHEN ca.outcome = 'Aggregate hospital charges' AND (NY.outcome = 'Aggregate hospital charges' OR NY.outcome IS NULL)
	THEN COALESCE(CA.measure_value, 0) + COALESCE(NY.measure_value, 0)
	ELSE 0 END) AS AggChargeTotal
FROM HospitalInpatientCA2021 CA
	LEFT JOIN HospitalInpatientNY2021 NY
	ON CA.diagnoses_procedures = NY.diagnoses_procedures
	AND CA.outcome = NY.outcome
	AND CA.characteristic_levels = NY.characteristic_levels
WHERE CA.outcome = 'Aggregate hospital charges' OR CA.outcome = 'Number of discharges'
GROUP BY CA.diagnoses_procedures
ORDER BY AggChargeTotal DESC
);

-- Exploring whether 'Number of discharges' can be used to calculate 'Average charges per Stay' on a diagnosis level


WITH DischargeCountCheck(measure_value, diagnoses_procedures, Characteristic_Levels, Agg_Hospital_Charges, Discharge_Count, Avg_Stay_Charges)
AS(
SELECT measure_value, diagnoses_procedures, Characteristic_Levels,
	CASE outcome WHEN 'Aggregate hospital charges' THEN COALESCE(measure_value, 0) ELSE 0 END AS Agg_Hospital_Charges, 
	CASE outcome WHEN 'Number of discharges' THEN measure_value ELSE 0 END AS Discharge_Count, 
	CASE outcome WHEN 'Average hospital charges per stay' THEN COALESCE(measure_value, 0) ELSE NULL END AS Avg_Stay_Charges
FROM HospitalInpatientCA2021
WHERE measure_value IS NOT NULL AND (outcome = 'Aggregate hospital charges' OR
 outcome = 'Number of discharges' OR outcome = 'Average hospital charges per stay') AND Characteristic_Levels = 'Age 1-17 years'
)
SELECT SUM(CAST(Agg_Hospital_Charges AS MONEY)) AS TOTAgg_Hospital_Charges, SUM(Discharge_Count) AS TOTDischarge_Count, 
SUM(CAST(Avg_Stay_Charges AS MONEY)) AS TOTAvg_Stay_Charges, CAST(COALESCE(SUM(Agg_Hospital_Charges)/NULLIF(SUM(Discharge_Count), 0), 0) AS MONEY) AS Check
FROM DischargeCountCheck
GROUP BY diagnoses_procedures
ORDER BY diagnoses_procedures DESC;

/*Comparing Average Charges per Stay per state diagnosis/procedure: 1) Comparing highest cost, 2) Identifying difference in cost
between states with percent difference*/

WITH AvgChargeDiff (diagnoses_procedures, CADischargeCount, NYDischargeCount, CA_TotAggCharges, NY_TotAggCharges, AggChargeTotal, CAStayAvg, NYStayAvg)
AS(
SELECT *, (CA_TotAggCharges/NULLIF(CADischargeCount, 0)), COALESCE((NY_TotAggCharges/NULLIF(NYDischargeCount, 0)), 0)
FROM CostComparison
)
SELECT *, ((CAStayAvg-NYStayAvg)/((CAStayAvg + NYStayAvg)/2))*100 AS PercentDifference
FROM AvgChargeDiff
ORDER BY PercentDifference DESC;

-- Identifying which age groups are most costly (by Agg Hosp Charges) NY

SELECT characteristic_levels, SUM(CAST(measure_value AS MONEY)) AS HighestChargesAgeGroup
FROM HospitalInpatientNY2021
WHERE outcome = 'Aggregate hospital charges' AND measure_value IS NOT NULL
GROUP BY characteristic_levels
ORDER BY HighestChargesAgeGroup DESC;

-- Identifying which age groups are most costly (by Agg Hosp Charges) CA

SELECT characteristic_levels, SUM(CAST(measure_value AS MONEY)) AS HighestChargesAgeGroup
FROM HospitalInpatientCA2021
WHERE outcome = 'Aggregate hospital charges' AND measure_value IS NOT NULL
GROUP BY characteristic_levels
ORDER BY HighestChargesAgeGroup DESC;


/*Identifying patient age groups contributing most to charges per NY diagnosis/procedure with 1) Rolling Total by Age Group
and 2) Age Group Rank*/

SELECT characteristic_levels AS Patient_Age_Group, diagnoses_procedures, outcome AS Measure, CAST(measure_value AS MONEY)
, SUM(CAST(measure_value AS MONEY)) OVER(PARTITION BY diagnoses_procedures ORDER BY outcome, characteristic_levels) AS RollingAgeGroupTotal
, DENSE_RANK() OVER(PARTITION BY diagnoses_procedures ORDER BY measure_value DESC) DXAgeGroupRank
FROM HospitalInpatientNY2021
WHERE outcome = 'Aggregate hospital charges' AND measure_value IS NOT NULL;


/*Identifying same groups as prior query for CA*/

SELECT characteristic_levels AS Patient_Age_Group, diagnoses_procedures, outcome AS Measure, CAST(measure_value AS MONEY)
, SUM(CAST(measure_value AS MONEY)) OVER(PARTITION BY diagnoses_procedures ORDER BY outcome, characteristic_levels) AS RollingAgeGroupTotal
, DENSE_RANK() OVER(PARTITION BY diagnoses_procedures ORDER BY measure_value DESC) DXAgeGroupRank
FROM HospitalInpatientCA2021
WHERE outcome = 'Aggregate hospital charges' AND measure_value IS NOT NULL;


-- Finding number of stays per age group- which has most & least visits?

DROP TABLE IF EXISTS AgeCostComparison; 

CREATE TEMP TABLE AgeCostComparison
(
Diagnoses_procedures VARCHAR(250),
Characteristic_levels VARCHAR(150),
CADischargeCount NUMERIC, 
NYDischargeCount NUMERIC,
CA_TotAggCharges MONEY,
NY_TotAggCharges MONEY,
AggChargeTotal MONEY
);

INSERT INTO AgeCostComparison
(SELECT CA.diagnoses_procedures, CA.characteristic_levels,
SUM(CASE
	WHEN CA.outcome = 'Number of discharges'
	THEN COALESCE(CA.measure_value, 0)
	ELSE 0 END) AS CADischargeCount,
SUM(CASE
	WHEN NY.outcome = 'Number of discharges'
	THEN COALESCE(NY.measure_value, 0)
	ELSE 0 END) AS NYDischargeCount,
SUM(CASE
	WHEN CA.outcome = 'Aggregate hospital charges'
	THEN COALESCE(CA.measure_value, 0)
	ELSE 0 END) AS CA_TotAggCharges, 
SUM(CASE
	WHEN NY.outcome = 'Aggregate hospital charges'
	THEN COALESCE(NY.measure_value, 0)
	ELSE 0 END) AS NY_TotAggCharges, 
SUM(CASE
	WHEN ca.outcome = 'Aggregate hospital charges' AND (NY.outcome = 'Aggregate hospital charges' OR NY.outcome IS NULL)
	THEN COALESCE(CA.measure_value, 0) + COALESCE(NY.measure_value, 0)
	ELSE 0 END) AS AggChargeTotal
FROM HospitalInpatientCA2021 CA
	LEFT JOIN HospitalInpatientNY2021 NY
	ON CA.diagnoses_procedures = NY.diagnoses_procedures
	AND CA.outcome = NY.outcome
	AND CA.characteristic_levels = NY.characteristic_levels
WHERE CA.outcome = 'Aggregate hospital charges' OR CA.outcome = 'Number of discharges'
GROUP BY CA.diagnoses_procedures, CA.characteristic_levels
ORDER BY AggChargeTotal DESC
);

SELECT Characteristic_levels, SUM(CADischargeCount) AS CAVisitCount, SUM(NYDischargeCount) AS NYVisitCount, SUM(CADischargeCount + NYDischargeCount) AS TotVisitCount
FROM AgeCostComparison
GROUP BY Characteristic_levels
ORDER BY TotVisitCount DESC;


-- Identifying diagnoses/procedures with highest number of visits

SELECT diagnoses_procedures, SUM(CADischargeCount) AS CAVisitCount, SUM(NYDischargeCount) AS NYVisitCount, SUM(CADischargeCount + NYDischargeCount) AS TotVisitCount
FROM AgeCostComparison
GROUP BY diagnoses_procedures
ORDER BY TotVisitCount DESC;


-- Creating view to store data for later visualizations

CREATE VIEW AgeCostComparisonV
AS
(SELECT CA.diagnoses_procedures, CA.characteristic_levels,
SUM(CASE
	WHEN CA.outcome = 'Number of discharges'
	THEN COALESCE(CA.measure_value, 0)
	ELSE 0 END) AS CADischargeCount,
SUM(CASE
	WHEN NY.outcome = 'Number of discharges'
	THEN COALESCE(NY.measure_value, 0)
	ELSE 0 END) AS NYDischargeCount,
SUM(CASE
	WHEN CA.outcome = 'Aggregate hospital charges'
	THEN COALESCE(CA.measure_value, 0)
	ELSE 0 END) AS CA_TotAggCharges, 
SUM(CASE
	WHEN NY.outcome = 'Aggregate hospital charges'
	THEN COALESCE(NY.measure_value, 0)
	ELSE 0 END) AS NY_TotAggCharges, 
SUM(CASE
	WHEN ca.outcome = 'Aggregate hospital charges' AND (NY.outcome = 'Aggregate hospital charges' OR NY.outcome IS NULL)
	THEN COALESCE(CA.measure_value, 0) + COALESCE(NY.measure_value, 0)
	ELSE 0 END) AS AggChargeTotal
FROM HospitalInpatientCA2021 CA
	LEFT JOIN HospitalInpatientNY2021 NY
	ON CA.diagnoses_procedures = NY.diagnoses_procedures
	AND CA.outcome = NY.outcome
	AND CA.characteristic_levels = NY.characteristic_levels
WHERE CA.outcome = 'Aggregate hospital charges' OR CA.outcome = 'Number of discharges'
GROUP BY CA.diagnoses_procedures, CA.characteristic_levels
ORDER BY AggChargeTotal DESC
);




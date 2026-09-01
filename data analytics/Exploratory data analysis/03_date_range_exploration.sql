/*
===============================================================================
Date Range Exploration Script
===============================================================================
Purpose:
    - Determine the temporal boundaries of transactional and demographic data.
    - Establish the overall historical timeline and lifespan of sales records.
    - Profile customer age distribution based on earliest and latest birthdates.

Highlights:
    1. Analyzes transaction date horizons:
       - First order date (earliest recorded transaction)
       - Last order date (latest recorded transaction)
       - Total order history duration (in months)
    2. Analyzes customer demographic age boundaries:
       - Oldest customer birthdate and calculated age in years
       - Youngest customer birthdate and calculated age in years

Tables Used:
    - gold.fact_sales   : Core transactional table containing order timestamps
    - gold.dim_customers : Customer dimension containing birthdates and demographics

SQL Clauses & Functions Used:
    - MIN(), MAX() : Aggregates to find boundary values (earliest/latest dates)
    - DATEDIFF()   : Computes elapsed intervals between date boundaries
    - GETDATE()    : Retrieves current system timestamp for relative age calculation
===============================================================================
*/

-- =============================================================================
-- 1) Transaction History Time Horizon
-- =============================================================================
-- Retrieves the overall order date boundaries and duration of sales data in months
SELECT 
    MIN(order_date)                                    AS first_order_date,
    MAX(order_date)                                    AS last_order_date,
    DATEDIFF(MONTH, MIN(order_date), MAX(order_date))  AS order_range_months
FROM gold.fact_sales;


-- =============================================================================
-- 2) Customer Demographics: Age Extremes
-- =============================================================================
-- Identifies the youngest and oldest customers by birthdate and calculates current age
SELECT
    MIN(birthdate)                           AS oldest_birthdate,
    DATEDIFF(YEAR, MIN(birthdate), GETDATE()) AS oldest_age,
    MAX(birthdate)                           AS youngest_birthdate,
    DATEDIFF(YEAR, MAX(birthdate), GETDATE()) AS youngest_age
FROM gold.dim_customers;

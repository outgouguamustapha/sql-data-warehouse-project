/*
===============================================================================
Change Over Time Analysis Script
===============================================================================
Purpose:
    - Track transactional performance, revenue growth, and volume trends over time.
    - Perform time-series aggregation to uncover seasonality and cyclical behavior.
    - Demonstrate different SQL date extraction, truncation, and formatting techniques.

Highlights:
    1. Granular Year & Month Extraction:
       - Uses `YEAR()` and `MONTH()` for multi-column time-grain sorting.
    2. Date Truncation:
       - Uses `DATETRUNC()` to normalize timestamps to the first day of each month.
       - Preserves native date data types for clean chronological sorting and graphing.
    3. Custom String Formatting:
       - Uses `FORMAT()` to generate readable date labels (e.g., '2023-Jan').
       - Highlights string vs. chronological sort behavior.

Tables Used:
    - gold.fact_sales : Core transactional table containing order dates, quantities, and revenue

SQL Clauses & Functions Used:
    - Date Functions      : YEAR(), MONTH(), DATETRUNC(), FORMAT()
    - Aggregate Functions : SUM(), COUNT(DISTINCT)
    - Filtering & Sorting : WHERE ... IS NOT NULL, GROUP BY, ORDER BY
===============================================================================
*/

-- =============================================================================
-- 1) Standard Year & Month Granularity (Numeric Dimensions)
-- =============================================================================
-- Aggregates monthly performance into separate numeric columns for year and month
SELECT
    YEAR(order_date)             AS order_year,
    MONTH(order_date)            AS order_month,
    SUM(sales_amount)            AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity)                AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 
    YEAR(order_date), 
    MONTH(order_date)
ORDER BY 
    order_year, 
    order_month;


-- =============================================================================
-- 2) Date Truncation (Best for Continuous Time-Series & BI Tools)
-- =============================================================================
-- Truncates order dates to the first of the month while keeping datetime data types
SELECT
    DATETRUNC(month, order_date) AS order_date,
    SUM(sales_amount)            AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity)                AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 
    DATETRUNC(month, order_date)
ORDER BY 
    order_date;


-- =============================================================================
-- 3) Formatted String Representation (Best for UI & Export Display)
-- =============================================================================
-- Formats dates as 'yyyy-MMM' strings; sorted chronologically using MIN(order_date)
SELECT
    FORMAT(order_date, 'yyyy-MMM') AS order_period,
    SUM(sales_amount)              AS total_sales,
    COUNT(DISTINCT customer_key)   AS total_customers,
    SUM(quantity)                  AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 
    FORMAT(order_date, 'yyyy-MMM')
ORDER BY 
    MIN(order_date);

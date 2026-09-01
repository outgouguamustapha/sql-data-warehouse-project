/*
===============================================================================
Cumulative Analysis Script
===============================================================================
Purpose:
    - Track cumulative performance, running totals, and moving averages over time.
    - Measure overall growth progression and long-term business trajectory.
    - Smooth out short-term fluctuations to highlight underlying macro trends.

Highlights:
    1. Time Aggregation:
       - Summarizes base metrics (total sales, average selling price) at fixed date intervals.
    2. Window Cumulative Computations:
       - Running Total Sales: Progressively sums revenue across ordered time frames.
       - Moving Average Price: Computes the cumulative baseline price average to date.

Tables Used:
    - gold.fact_sales : Fact table containing transactional order dates, sales amounts, and unit prices

SQL Clauses & Functions Used:
    - DATETRUNC()           : Truncates timestamps to standard date boundaries (year, month)
    - SUM() / AVG()         : Computes base aggregates and window metric calculations
    - OVER (ORDER BY ...)   : Defines cumulative frame ordering from the start of the series to the current row
===============================================================================
*/

-- =============================================================================
-- 1) Annual Cumulative Sales & Price Trend
-- =============================================================================
-- Aggregates annual metrics and applies window functions to compute running totals
SELECT
    order_date,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sales,
    AVG(avg_price)   OVER (ORDER BY order_date) AS moving_average_price
FROM
(
    SELECT 
        DATETRUNC(year, order_date) AS order_date,
        SUM(sales_amount)           AS total_sales,
        AVG(price)                  AS avg_price
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY 
        DATETRUNC(year, order_date)
) AS annual_sales_summary;

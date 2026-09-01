/*
===============================================================================
Performance Analysis (Year-over-Year & Benchmark Comparison)
===============================================================================
Purpose:
    - Measure entity-level (product) sales performance over multi-year periods.
    - Benchmark annual revenue against product historical averages.
    - Track Year-over-Year (YoY) growth, absolute variance, and directional trends.

Highlights:
    1. Historical Baseline Comparison:
       - Computes product overall average sales across all active years (`AVG() OVER PARTITION BY`).
       - Calculates deviation from historical average (`diff_avg`).
       - Categorizes performance relative to baseline (`Above Avg`, `Below Avg`, `Avg`).
    2. Year-over-Year (YoY) Growth Analysis:
       - Accesses previous year sales using window function `LAG()`.
       - Computes absolute annual sales variance (`diff_py`).
       - Identifies trajectory shifts (`Increase`, `Decrease`, `No Change`).

Tables Used:
    - gold.fact_sales   : Fact table containing transaction timestamps and sales amounts
    - gold.dim_products : Product dimension containing product names and metadata

SQL Clauses & Functions Used:
    - WITH (CTE)                        : Isolates initial yearly aggregations per product
    - LAG() OVER (PARTITION BY ... )    : Accesses prior row value within partition ordered by year
    - AVG() OVER (PARTITION BY ... )    : Calculates partition-wide historical baseline average
    - CASE                              : Evaluates conditional logic for growth and benchmark status
===============================================================================
*/

-- =============================================================================
-- 1) Product Yearly Performance & Trend Analysis
-- =============================================================================
WITH yearly_product_sales AS (
/*---------------------------------------------------------------------------
1) CTE: Aggregate annual gross revenue per product
---------------------------------------------------------------------------*/
    SELECT
        YEAR(f.order_date)  AS order_year,
        p.product_name,
        SUM(f.sales_amount) AS current_sales
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_products AS p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY 
        YEAR(f.order_date),
        p.product_name
)

/*---------------------------------------------------------------------------
2) Final Query: Compute baseline benchmarks, YoY shifts, and directional indicators
---------------------------------------------------------------------------*/
SELECT
    order_year,
    product_name,
    current_sales,

    -- Benchmark: Product Historical Multi-Year Average
    AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
    current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
    CASE 
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
        ELSE 'Avg'
    END AS avg_change,

    -- Year-over-Year (YoY) Comparative Analysis
    LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS py_sales,
    current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_py,
    CASE 
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
        ELSE 'No Change'
    END AS py_change
FROM yearly_product_sales
ORDER BY 
    product_name, 
    order_year;

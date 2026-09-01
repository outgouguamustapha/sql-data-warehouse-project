/*
===============================================================================
Part-to-Whole Analysis Script
===============================================================================
Purpose:
    - Compare category-level contributions against the overall business baseline.
    - Calculate proportional share and percentage distribution of total revenue.
    - Identify key revenue drivers and assess portfolio concentration.

Highlights:
    1. Category Aggregation:
       - Summarizes gross sales amount per product category.
    2. Proportional Share Calculations:
       - Uses `SUM() OVER ()` to compute entire catalog sales across all partitions.
       - Casts sales values to compute precise percentage contribution of total (`% of Total`).
    3. Output Ranking:
       - Orders categories by absolute revenue share from highest to lowest.

Tables Used:
    - gold.fact_sales   : Core transaction records containing sales revenue
    - gold.dim_products : Product dimensional catalog containing category mappings

SQL Clauses & Functions Used:
    - WITH (CTE)          : Pre-aggregates sales volume by product category
    - SUM() OVER ()       : Window aggregate to calculate grand total without collapsing rows
    - CAST() / ROUND()    : Formats numeric precision for percentage share calculations
    - LEFT JOIN           : Links transaction line items to dimensional product hierarchies
    - GROUP BY, ORDER BY  : Aggregates by category and sorts by descending contribution
===============================================================================
*/

-- =============================================================================
-- 1) Product Category Revenue Contribution (% of Total Sales)
-- =============================================================================
WITH category_sales AS (
/*---------------------------------------------------------------------------
1) CTE: Aggregate gross revenue by product category
---------------------------------------------------------------------------*/
    SELECT
        p.category,
        SUM(f.sales_amount) AS total_sales
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_products AS p
        ON p.product_key = f.product_key
    GROUP BY 
        p.category
)

/*---------------------------------------------------------------------------
2) Final Query: Calculate portfolio grand total and proportional percentage share
---------------------------------------------------------------------------*/
SELECT
    category,
    total_sales,
    SUM(total_sales) OVER () AS overall_sales,
    ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER ()) * 100, 2) AS percentage_of_total
FROM category_sales
ORDER BY 
    total_sales DESC;

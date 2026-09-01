/*
===============================================================================
Data Segmentation Analysis Script
===============================================================================
Purpose:
    - Group dimensional entities into meaningful business tiers and categories.
    - Profile product catalog distributions across baseline manufacturing cost tiers.
    - Classify customer accounts into loyalty segments based on tenure and lifetime spend.

Highlights:
    1. Product Cost Tier Segmentation:
       - Segments SKUs into granular price bands (Below 100, 100-500, 500-1000, Above 1000).
       - Evaluates catalog distribution and inventory concentration across cost ranges.
    2. Customer Value & Tenure Segmentation:
       - VIP: Long-tenured accounts (>= 12 months) with high lifetime spend (> €5,000).
       - Regular: Long-tenured accounts (>= 12 months) with moderate/low spend (<= €5,000).
       - New: Recent accounts with active lifespans under 12 months.
       - Aggregates customer counts per segment to measure retention and account health.

Tables Used:
    - gold.dim_products  : Product catalog dimension containing SKU unit costs
    - gold.fact_sales    : Transactional order lines and revenue records
    - gold.dim_customers : Registered customer directory

SQL Clauses & Functions Used:
    - WITH (CTE)         : Structures intermediate transformations and customer summaries
    - CASE               : Defines conditional business logic for tier assignment
    - DATEDIFF()         : Computes customer account lifespan in months
    - GROUP BY, ORDER BY : Groups by segment classifications and orders by descending volume
===============================================================================
*/

-- =============================================================================
-- 1) Product Cost Band Segmentation
-- =============================================================================
WITH product_segments AS (
/*---------------------------------------------------------------------------
1) CTE: Classify each product into predefined unit cost bands
---------------------------------------------------------------------------*/
    SELECT
        product_key,
        product_name,
        cost,
        CASE 
            WHEN cost < 100 THEN 'Below 100'
            WHEN cost BETWEEN 100 AND 500 THEN '100-500'
            WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
            ELSE 'Above 1000'
        END AS cost_range
    FROM gold.dim_products
)

/*---------------------------------------------------------------------------
2) Final Query: Aggregate total product counts per cost tier
---------------------------------------------------------------------------*/
SELECT 
    cost_range,
    COUNT(product_key) AS total_products
FROM product_segments
GROUP BY 
    cost_range
ORDER BY 
    total_products DESC;


-- =============================================================================
-- 2) Customer Loyalty & Value Tier Segmentation
-- =============================================================================
WITH customer_spending AS (
/*---------------------------------------------------------------------------
1) CTE: Compute lifetime spending, first/last purchase dates, and active lifespan
---------------------------------------------------------------------------*/
    SELECT
        c.customer_key,
        SUM(f.sales_amount)                               AS total_spending,
        MIN(f.order_date)                                 AS first_order,
        MAX(f.order_date)                                 AS last_order,
        DATEDIFF(month, MIN(f.order_date), MAX(f.order_date)) AS lifespan
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_customers AS c
        ON f.customer_key = c.customer_key
    WHERE f.order_date IS NOT NULL
    GROUP BY 
        c.customer_key
)

/*---------------------------------------------------------------------------
2) Final Query: Assign customer tiers and aggregate account distribution
---------------------------------------------------------------------------*/
SELECT 
    customer_segment,
    COUNT(customer_key) AS total_customers
FROM (
    SELECT 
        customer_key,
        CASE 
            WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
            WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
            ELSE 'New'
        END AS customer_segment
    FROM customer_spending
) AS segmented_customers
GROUP BY 
    customer_segment
ORDER BY 
    total_customers DESC;

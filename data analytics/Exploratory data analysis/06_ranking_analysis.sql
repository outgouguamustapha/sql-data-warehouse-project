/*
===============================================================================
Ranking Analysis Script
===============================================================================
Purpose:
    - Rank entities (products, customers) based on transactional performance.
    - Identify top revenue drivers and isolate bottom-tier laggards.
    - Demonstrate both simple limiting clauses (TOP) and scalable window functions (RANK).

Highlights:
    1. Product Performance Ranking:
       - Top 5 products by gross revenue (using TOP)
       - Top 5 products by gross revenue (using dynamic window function RANK)
       - Bottom 5 worst-performing products by gross sales
    2. Customer Value & Activity Ranking:
       - Top 10 high-value customers by total revenue contribution
       - Bottom 3 customers by distinct order frequency

Tables Used:
    - gold.fact_sales    : Transactional order lines and revenue records
    - gold.dim_products  : Product metadata and SKU names
    - gold.dim_customers : Customer demographic identifiers and profile details

SQL Clauses & Functions Used:
    - TOP                     : Limits query output to a fixed number of rows
    - RANK() OVER (...)       : Calculates non-continuous rank positions based on metric ordering
    - SUM(), COUNT(DISTINCT)  : Computes aggregated financial volume and distinct purchase count
    - GROUP BY, ORDER BY      : Groups data points and determines ranking sort direction (ASC/DESC)
===============================================================================
*/

-- =============================================================================
-- 1) Product Revenue Rankings (Top & Bottom Performers)
-- =============================================================================

-- Top 5 products generating the highest revenue (Simple TOP clause)
SELECT TOP 5
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON p.product_key = f.product_key
GROUP BY 
    p.product_name
ORDER BY 
    total_revenue DESC;


-- Top 5 products generating the highest revenue (Scalable Window Function)
SELECT 
    product_name,
    total_revenue,
    product_rank
FROM (
    SELECT
        p.product_name,
        SUM(f.sales_amount) AS total_revenue,
        RANK() OVER (ORDER BY SUM(f.sales_amount) DESC) AS product_rank
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_products AS p
        ON p.product_key = f.product_key
    GROUP BY 
        p.product_name
) AS ranked_products
WHERE product_rank <= 5;


-- Bottom 5 worst-performing products by total revenue
SELECT TOP 5
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON p.product_key = f.product_key
GROUP BY 
    p.product_name
ORDER BY 
    total_revenue ASC;


-- =============================================================================
-- 2) Customer Value & Engagement Rankings
-- =============================================================================

-- Top 10 customers generating the highest revenue
SELECT TOP 10
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON c.customer_key = f.customer_key
GROUP BY 
    c.customer_key,
    c.first_name,
    c.last_name
ORDER BY 
    total_revenue DESC;


-- Bottom 3 customers with the fewest orders placed
SELECT TOP 3
    c.customer_key,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT f.order_number) AS total_orders
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON c.customer_key = f.customer_key
GROUP BY 
    c.customer_key,
    c.first_name,
    c.last_name
ORDER BY 
    total_orders ASC;

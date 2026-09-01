/*
===============================================================================
Product Report
===============================================================================
Purpose:
    - This report consolidates key product metrics and behaviors.

Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Aggregates product-level metrics:
       - total orders
       - total sales
       - total quantity sold
       - total customers (unique)
       - lifespan (in months)
    3. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    4. Calculates valuable KPIs:
       - recency (months since last sale)
       - average order revenue (AOR)
       - average monthly revenue
===============================================================================
*/

-- =============================================================================
-- Create Report: gold.report_products
-- =============================================================================
IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
    DROP VIEW gold.report_products;
GO

CREATE VIEW gold.report_products AS

WITH base_query AS (
/*---------------------------------------------------------------------------
1) Base Query: Joins product dimensions with valid sales transactions
---------------------------------------------------------------------------*/
    SELECT 
        s.order_number,
        s.order_date,
        s.quantity,
        s.sales_amount,
        s.customer_key,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.product_line,
        p.cost
    FROM gold.dim_products AS p
    LEFT JOIN gold.fact_sales AS s
        ON p.product_key = s.product_key
    WHERE s.order_date IS NOT NULL
),

product_aggregation AS (
/*---------------------------------------------------------------------------
2) Product Aggregation: Summarizes volume, revenue, and active dates per product
---------------------------------------------------------------------------*/
    SELECT
        product_key,
        product_name,
        category,
        subcategory,
        cost,
        COUNT(order_number) AS total_orders,
        COUNT(DISTINCT customer_key) AS total_customers,
        SUM(quantity) AS total_quantity,
        SUM(sales_amount) AS total_sales,
        DATEDIFF(month, MIN(order_date), MAX(order_date)) AS life_span,
        MAX(order_date) AS last_order_date
    FROM base_query
    GROUP BY 
        product_key,
        product_name,
        category,
        subcategory,
        cost
)

/*---------------------------------------------------------------------------
3) Final Query: Formats output, computes segmentation, and calculates derived KPIs
---------------------------------------------------------------------------*/
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    total_orders,
    total_customers,
    total_quantity,
    total_sales,
    life_span,
    DATEDIFF(month, last_order_date, GETDATE()) AS recency,
    CASE
        WHEN total_sales > 50000 THEN 'High-Performer'
        WHEN total_sales >= 10000 THEN 'Mid-Range'
        ELSE 'Low-Performer'
    END AS product_segment,
    CASE 
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders
    END AS avg_order_revenue,
    CASE 
        WHEN life_span = 0 THEN total_sales
        ELSE total_sales / life_span
    END AS avg_monthly_revenue
FROM product_aggregation;
GO

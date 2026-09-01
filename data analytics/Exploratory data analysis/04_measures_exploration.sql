/*
===============================================================================
Measures Exploration (Key Business Metrics)
===============================================================================
Purpose:
    - Compute high-level aggregated metrics (totals, averages, and distinct counts).
    - Establish top-line business baseline KPIs for revenue, volume, and customer reach.
    - Provide consolidated executive summary tables for data profiling and audits.

Highlights:
    1. Financial & Volume Measures:
       - Total revenue (sales amount)
       - Total units sold (quantity)
       - Average selling price (ASP)
    2. Operational & Catalog Measures:
       - Total order line items vs. unique order counts
       - Total product catalog size
    3. Customer Base Measures:
       - Total registered customer profiles
       - Active purchasing customers
    4. Executive Summary KPI Sheet:
       - Unified single-table view of all primary metrics using UNION ALL

Tables Used:
    - gold.fact_sales    : Transactional order lines, sales revenue, and quantity
    - gold.dim_products  : Product catalog dimension
    - gold.dim_customers : Registered customer directory

SQL Clauses & Functions Used:
    - SUM()              : Aggregates total financial value and product units
    - AVG()              : Calculates arithmetic mean of price points
    - COUNT()            : Measures total rows or non-null attribute occurrences
    - COUNT(DISTINCT)    : Computes cardinality of unique orders and active entities
    - UNION ALL          : Combines independent metric queries into a single dataset
===============================================================================
*/

-- =============================================================================
-- 1) Financial & Transactional Aggregations
-- =============================================================================

-- Total gross sales revenue generated
SELECT 
    SUM(sales_amount) AS total_sales 
FROM gold.fact_sales;

-- Total number of physical units sold
SELECT 
    SUM(quantity) AS total_quantity 
FROM gold.fact_sales;

-- Average selling price across all transactional line items
SELECT 
    AVG(price) AS avg_price 
FROM gold.fact_sales;

-- Total transaction line items vs. distinct purchase orders
SELECT 
    COUNT(order_number)          AS total_order_lines,
    COUNT(DISTINCT order_number) AS total_distinct_orders 
FROM gold.fact_sales;


-- =============================================================================
-- 2) Dimensional Catalog & Customer Metrics
-- =============================================================================

-- Total product catalog count (SKUs)
SELECT 
    COUNT(product_key)          AS total_products,
    COUNT(DISTINCT product_name) AS total_distinct_product_names 
FROM gold.dim_products;

-- Total registered customer accounts in database
SELECT 
    COUNT(customer_key) AS total_registered_customers 
FROM gold.dim_customers;

-- Total unique customers who have completed at least one order
SELECT 
    COUNT(DISTINCT customer_key) AS total_active_customers 
FROM gold.fact_sales;


-- =============================================================================
-- 3) Consolidated Key Business Measures Report
-- =============================================================================
-- Consolidates all core KPIs into a key-value metric summary table
SELECT 
    'Total Sales' AS measure_name, 
    CAST(SUM(sales_amount) AS DECIMAL(18,2)) AS measure_value 
FROM gold.fact_sales

UNION ALL

SELECT 
    'Total Quantity', 
    CAST(SUM(quantity) AS DECIMAL(18,2)) 
FROM gold.fact_sales

UNION ALL

SELECT 
    'Average Price', 
    CAST(AVG(price) AS DECIMAL(18,2)) 
FROM gold.fact_sales

UNION ALL

SELECT 
    'Total Orders', 
    CAST(COUNT(DISTINCT order_number) AS DECIMAL(18,2)) 
FROM gold.fact_sales

UNION ALL

SELECT 
    'Total Products', 
    CAST(COUNT(DISTINCT product_name) AS DECIMAL(18,2)) 
FROM gold.dim_products

UNION ALL

SELECT 
    'Total Registered Customers', 
    CAST(COUNT(customer_key) AS DECIMAL(18,2)) 
FROM gold.dim_customers

UNION ALL

SELECT 
    'Total Active Customers', 
    CAST(COUNT(DISTINCT customer_key) AS DECIMAL(18,2)) 
FROM gold.fact_sales;

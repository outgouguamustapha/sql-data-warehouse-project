/*
===============================================================================
DDL Script: Create Gold Views (Dimensional Model)
===============================================================================
Script Purpose:
    This script defines and materializes the analytical Gold layer views.
    The Gold layer represents the final presentation tier structured as a 
    Star Schema, consisting of conformed dimensions and transactional facts.

Highlights:
    1. Dimension gold.dim_customers:
       - Consolidates customer profiles from CRM and ERP sources.
       - Generates deterministic surrogate keys using ROW_NUMBER().
       - Resolves primary and fallback attributes (e.g., CRM gender with ERP fallback).
    2. Dimension gold.dim_products:
       - Enriches product master data with categories and maintenance metadata.
       - Generates deterministic surrogate keys.
       - Filters out inactive historical records (prd_end_dt IS NULL) to serve current catalog.
    3. Fact Table gold.fact_sales:
       - Connects transactional sales order lines to Gold dimension surrogate keys.
       - Serves core measures (sales amount, quantity, price) and order dates.

Source Tables:
    - silver.crm_cust_info     : Core customer attributes from CRM
    - silver.erp_cust_az12     : Additional demographic details from ERP
    - silver.erp_loc_a101      : Customer location and country data from ERP
    - silver.crm_prd_info      : Product details from CRM
    - silver.erp_px_cat_g1v2   : Product categorization from ERP
    - silver.crm_sales_details : Sales order line items from CRM

Usage:
    - Query directly for downstream business intelligence, KPI reporting, and analytics.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS
/*---------------------------------------------------------------------------
1) gold.dim_customers: Joins CRM customer data with ERP demographics & locations
---------------------------------------------------------------------------*/
SELECT
    ROW_NUMBER() OVER (ORDER BY ci.cst_id) AS customer_key, -- Surrogate key for dimensional modeling
    ci.cst_id                              AS customer_id,  -- Natural business identifier
    ci.cst_key                             AS customer_number,
    ci.cst_firstname                       AS first_name,
    ci.cst_lastname                        AS last_name,
    la.cntry                               AS country,
    ci.cst_marital_status                  AS marital_status,
    -- Gender resolution: Prioritize CRM value, fallback to ERP demographic data
    CASE 
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr
        ELSE COALESCE(ca.gen, 'n/a')
    END                                    AS gender,
    ca.bdate                               AS birthdate,
    ci.cst_create_date                     AS create_date
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 AS ca
    ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 AS la
    ON ci.cst_key = la.cid;
GO

-- =============================================================================
-- Create Dimension: gold.dim_products
-- =============================================================================
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS
/*---------------------------------------------------------------------------
2) gold.dim_products: Combines product master with category hierarchies
---------------------------------------------------------------------------*/
SELECT
    ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key, -- Surrogate key
    pn.prd_id        AS product_id,
    pn.prd_key       AS product_number,
    pn.prd_nm        AS product_name,
    pn.cat_id        AS category_id,
    pc.cat           AS category,
    pc.subcat        AS subcategory,
    pc.maintenance   AS maintenance,
    pn.prd_cost      AS cost,
    pn.prd_line      AS product_line,
    pn.prd_start_dt  AS start_date
FROM silver.crm_prd_info AS pn
LEFT JOIN silver.erp_px_cat_g1v2 AS pc
    ON pn.cat_id = pc.id
-- Filter out inactive / expired records to represent the active product catalog
WHERE pn.prd_end_dt IS NULL;
GO

-- =============================================================================
-- Create Fact Table: gold.fact_sales
-- =============================================================================
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS
/*---------------------------------------------------------------------------
3) gold.fact_sales: Connects transactional order facts to dimension surrogate keys
---------------------------------------------------------------------------*/
SELECT
    sd.sls_ord_num  AS order_number,
    pr.product_key  AS product_key,  -- Foreign key referencing gold.dim_products
    cu.customer_key AS customer_key, -- Foreign key referencing gold.dim_customers
    sd.sls_order_dt AS order_date,
    sd.sls_ship_dt  AS shipping_date,
    sd.sls_due_dt   AS due_date,
    sd.sls_sales    AS sales_amount,
    sd.sls_quantity AS quantity,
    sd.sls_price    AS price
FROM silver.crm_sales_details AS sd
LEFT JOIN gold.dim_products AS pr
    ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers AS cu
    ON sd.sls_cust_id = cu.customer_id;
GO

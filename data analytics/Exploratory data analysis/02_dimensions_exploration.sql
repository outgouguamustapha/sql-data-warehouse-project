/*
===============================================================================
Dimensions Exploration Script
===============================================================================
Purpose:
    - Explore and profile categorical values across core dimensional entities.
    - Validate geographical distribution and product hierarchy levels.

Highlights:
    1. Extracts unique countries to understand market and customer reach.
    2. Maps the complete product hierarchy across:
       - Category (L1)
       - Subcategory (L2)
       - Product Name (L3 / SKU description)
    3. Sorts outputs alphabetically for straightforward data validation and audit.

Tables Used:
    - gold.dim_customers : Customer dimension containing demographic and location data
    - gold.dim_products  : Product dimension containing categorization and SKU metadata

SQL Clauses & Functions Used:
    - DISTINCT : Eliminates duplicate values across specified attributes
    - ORDER BY : Sorts output columns in ascending sequence
===============================================================================
*/

-- =============================================================================
-- 1) Customer Geographic Distribution
-- =============================================================================
-- Retrieves a deduplicated, alphabetical list of all customer origin countries
SELECT DISTINCT 
    country 
FROM gold.dim_customers
ORDER BY 
    country;


-- =============================================================================
-- 2) Product Categorization Hierarchy
-- =============================================================================
-- Retrieves distinct category and subcategory relationships down to the individual product level
SELECT DISTINCT 
    category, 
    subcategory, 
    product_name 
FROM gold.dim_products
ORDER BY 
    category, 
    subcategory, 
    product_name;

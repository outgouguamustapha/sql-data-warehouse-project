/*
===============================================================================
Database & Schema Exploration Script
===============================================================================
Purpose:
    - Explore the logical and physical structure of the database.
    - List all existing schemas, base tables, and views.
    - Inspect column-level metadata, data types, nullability, and constraints.

Highlights:
    1. Catalogs all user tables and views across different schemas.
    2. Identifies table architectures (Base Table vs. View).
    3. Details column definitions (data types, null constraints, character limits).
    4. Filters and inspects specific dimensional and fact tables (e.g., dim_customers).

Tables Used:
    - INFORMATION_SCHEMA.TABLES  : System catalog for table and view definitions
    - INFORMATION_SCHEMA.COLUMNS : System catalog for column-level attributes
===============================================================================
*/

-- =============================================================================
-- 1) Database Table & View Catalog
-- =============================================================================
-- Retrieves all tables and views available in the current database catalog,
-- ordered by schema and name for clear structural navigation.
SELECT 
    TABLE_CATALOG AS database_name,
    TABLE_SCHEMA  AS schema_name,
    TABLE_NAME    AS table_name,
    TABLE_TYPE    AS table_type
FROM INFORMATION_SCHEMA.TABLES
ORDER BY 
    TABLE_SCHEMA,
    TABLE_NAME;


-- =============================================================================
-- 2) Detailed Column Metadata Inspection
-- =============================================================================
-- Retrieves full column definitions, data types, character limits, and ordinal 
-- positions for a targeted entity (e.g., dim_customers).
SELECT 
    TABLE_SCHEMA             AS schema_name,
    TABLE_NAME               AS table_name,
    COLUMN_NAME              AS column_name,
    ORDINAL_POSITION         AS column_order,
    DATA_TYPE                AS data_type,
    CHARACTER_MAXIMUM_LENGTH AS max_length,
    IS_NULLABLE              AS is_nullable,
    COLUMN_DEFAULT           AS default_value
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_customers'
ORDER BY 
    ORDINAL_POSITION;

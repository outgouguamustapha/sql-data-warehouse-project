/*
===============================================================================
Stored Procedure: silver.load_silver
===============================================================================
Description:
    Performs the full ETL (Extract, Transform, Load) orchestration from the 
    Bronze raw staging layer to the Silver cleaned/conformed layer.
    
Actions Performed:
    - Truncates destination Silver tables.
    - Applies standardization, deduplication, and data quality transformations:
        1. crm_cust_info: Deduplicates by customer ID; normalizes gender and marital status.
        2. crm_prd_info: Splits compound product keys into cat_id and prd_key; 
           computes effective date ranges using LEAD() partitioned by the substringed key.
        3. crm_sales_details: Validates and parses 8-digit date keys; recalculates inconsistent sales/prices.
        4. erp_cust_az12: Cleans ERP customer IDs; filters future birth dates; standardizes gender.
        5. erp_loc_a101: Cleans formatted ID characters; normalizes country codes.
        6. erp_px_cat_g1v2: Conforms product category mappings.
    - Measures table-level and batch-level execution times.
    - Captures and logs runtime errors in a TRY...CATCH block.

Parameters:
    None

Usage Example:
    EXEC silver.load_silver;
===============================================================================
*/

EXEC silver.load_silver;

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    SET NOCOUNT ON;

    -- Track execution metrics
    DECLARE @start_time DATETIME, 
            @end_time DATETIME, 
            @batch_start_time DATETIME, 
            @batch_end_time DATETIME; 

    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Starting Silver Layer Ingestion';
        PRINT '================================================';

        /* --------------------------------------------------------------------
           CRM Pipeline
        -------------------------------------------------------------------- */
        PRINT '------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '------------------------------------------------';

        -- 1. silver.crm_cust_info
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;

        PRINT '>> Inserting Data Into: silver.crm_cust_info';
        INSERT INTO silver.crm_cust_info (
            cst_id, 
            cst_key, 
            cst_firstname, 
            cst_lastname, 
            cst_marital_status, 
            cst_gndr,
            cst_create_date
        )
        SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname)  AS cst_lastname,
            -- Standardize marital status codes
            CASE 
                WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
                WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
                ELSE 'n/a'
            END AS cst_marital_status,
            -- Standardize gender values
            CASE 
                WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
                WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
                ELSE 'n/a'
            END AS cst_gndr,
            cst_create_date
        FROM (
            -- Retain only the most recent customer record if duplicates exist
            SELECT
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY cst_id 
                    ORDER BY cst_create_date DESC
                ) AS flag_last
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL
        ) t
        WHERE flag_last = 1;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(10)) + ' seconds';
        PRINT '>> -------------';

        -- 2. silver.crm_prd_info
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.crm_prd_info';
        TRUNCATE TABLE silver.crm_prd_info;

        PRINT '>> Inserting Data Into: silver.crm_prd_info';
        INSERT INTO silver.crm_prd_info (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )
        SELECT
            prd_id,
            -- Extract category ID prefix (e.g., 'CO-RD' -> 'CO_RD')
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
            -- Extract clean product key matching table DDL
            SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
            prd_nm,
            ISNULL(prd_cost, 0) AS prd_cost,
            -- Map line codes to business names
            CASE 
                WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
                WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
                WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
                WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
                ELSE 'n/a'
            END AS prd_line,
            CAST(prd_start_dt AS DATE) AS prd_start_dt,
            -- Calculate valid end date as one day prior to the next start date in sequence
            CAST(
                DATEADD(
                    DAY, 
                    -1, 
                    LEAD(prd_start_dt) OVER (
                        PARTITION BY SUBSTRING(prd_key, 7, LEN(prd_key)) 
                        ORDER BY prd_start_dt
                    )
                ) AS DATE
            ) AS prd_end_dt
        FROM bronze.crm_prd_info;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(10)) + ' seconds';
        PRINT '>> -------------';

        -- 3. silver.crm_sales_details
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.crm_sales_details';
        TRUNCATE TABLE silver.crm_sales_details;

        PRINT '>> Inserting Data Into: silver.crm_sales_details';
        INSERT INTO silver.crm_sales_details (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT 
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            -- Parse YYYYMMDD integers into DATE, returning NULL for invalid formats
            TRY_CONVERT(DATE, NULLIF(CAST(sls_order_dt AS VARCHAR(8)), '0'), 112) AS sls_order_dt,
            TRY_CONVERT(DATE, NULLIF(CAST(sls_ship_dt  AS VARCHAR(8)), '0'), 112) AS sls_ship_dt,
            TRY_CONVERT(DATE, NULLIF(CAST(sls_due_dt   AS VARCHAR(8)), '0'), 112) AS sls_due_dt,
            -- Recalculate sales if value is missing, negative, or inconsistent with quantity * price
            CASE 
                WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) 
                    THEN sls_quantity * ABS(sls_price)
                ELSE sls_sales
            END AS sls_sales,
            sls_quantity,
            -- Derive unit price if missing or non-positive
            CASE 
                WHEN sls_price IS NULL OR sls_price <= 0 
                    THEN sls_sales / NULLIF(sls_quantity, 0)
                ELSE sls_price
            END AS sls_price
        FROM bronze.crm_sales_details;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(10)) + ' seconds';
        PRINT '>> -------------';

        /* --------------------------------------------------------------------
           ERP Pipeline
        -------------------------------------------------------------------- */
        PRINT '------------------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '------------------------------------------------';

        -- 4. silver.erp_cust_az12
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_cust_az12';
        TRUNCATE TABLE silver.erp_cust_az12;

        PRINT '>> Inserting Data Into: silver.erp_cust_az12';
        INSERT INTO silver.erp_cust_az12 (
            cid,
            bdate,
            gen
        )
        SELECT
            -- Strip 'NAS' prefix from customer ID when present
            CASE
                WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
                ELSE cid
            END AS cid, 
            -- Invalidate impossible future birth dates
            CASE
                WHEN bdate > GETDATE() THEN NULL
                ELSE bdate
            END AS bdate,
            -- Normalize gender descriptions
            CASE
                WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
                WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
                ELSE 'n/a'
            END AS gen
        FROM bronze.erp_cust_az12;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(10)) + ' seconds';
        PRINT '>> -------------';

        -- 5. silver.erp_loc_a101
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_loc_a101';
        TRUNCATE TABLE silver.erp_loc_a101;

        PRINT '>> Inserting Data Into: silver.erp_loc_a101';
        INSERT INTO silver.erp_loc_a101 (
            cid,
            cntry
        )
        SELECT
            REPLACE(cid, '-', '') AS cid, 
            -- Standardize country codes and handle blanks
            CASE
                WHEN TRIM(cntry) = 'DE'               THEN 'Germany'
                WHEN TRIM(cntry) IN ('US', 'USA')      THEN 'United States'
                WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
                ELSE TRIM(cntry)
            END AS cntry
        FROM bronze.erp_loc_a101;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(10)) + ' seconds';
        PRINT '>> -------------';
        
        -- 6. silver.erp_px_cat_g1v2
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';
        INSERT INTO silver.erp_px_cat_g1v2 (
            id,
            cat,
            subcat,
            maintenance
        )
        SELECT
            id,
            cat,
            subcat,
            maintenance
        FROM bronze.erp_px_cat_g1v2;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(10)) + ' seconds';
        PRINT '>> -------------';

        /* --------------------------------------------------------------------
           Batch Completion Summary
        -------------------------------------------------------------------- */
        SET @batch_end_time = GETDATE();
        PRINT '================================================';
        PRINT 'Silver Layer Load Completed Successfully';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR(10)) + ' seconds';
        PRINT '================================================';
        
    END TRY
    BEGIN CATCH
        /* --------------------------------------------------------------------
           Error Handling Block
        -------------------------------------------------------------------- */
        PRINT '================================================';
        PRINT 'ERROR OCCURRED DURING SILVER LAYER LOAD';
        PRINT '   - Error Message: ' + ERROR_MESSAGE();
        PRINT '   - Error Number:  ' + CAST(ERROR_NUMBER() AS NVARCHAR(10));
        PRINT '   - Error State:   ' + CAST(ERROR_STATE() AS NVARCHAR(10));
        PRINT '   - Error Line:    ' + CAST(ERROR_LINE() AS NVARCHAR(10));
        PRINT '================================================';
        
        -- Propagate error to caller
        THROW;
    END CATCH
END;

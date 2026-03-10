-- ============================================================
-- FILE: 02_data_cleaning.sql
-- PROJECT: SaaS Revenue Analytics
-- DESCRIPTION: Clean, validate, and prepare data for analysis
-- ============================================================

-- ============================================================
-- SECTION 1: CHECK FOR NULL VALUES
-- Before analysis, we need to know if any critical fields
-- have missing data. NULL in revenue or customer_id breaks
-- every downstream calculation.
-- ============================================================

SELECT
    SUM(CASE WHEN order_id    IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN order_date  IS NULL THEN 1 ELSE 0 END) AS null_order_date,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN customer    IS NULL THEN 1 ELSE 0 END) AS null_customer,
    SUM(CASE WHEN sales       IS NULL THEN 1 ELSE 0 END) AS null_sales,
    SUM(CASE WHEN product     IS NULL THEN 1 ELSE 0 END) AS null_product,
    SUM(CASE WHEN region      IS NULL THEN 1 ELSE 0 END) AS null_region
FROM saas_sales;

-- ============================================================
-- SECTION 2: CHECK FOR DUPLICATE ROWS
-- Duplicate order_ids would inflate revenue figures.
-- We identify them before any analysis.
-- ============================================================

-- Find duplicated order_ids
SELECT
    order_id,
    COUNT(*) AS occurrences
FROM saas_sales
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- Count total duplicate rows
SELECT COUNT(*) AS total_duplicate_rows
FROM (
    SELECT order_id
    FROM saas_sales
    GROUP BY order_id
    HAVING COUNT(*) > 1
) duplicates;

-- ============================================================
-- SECTION 3: VALIDATE DATE RANGES
-- Confirm order dates are within a sensible range.
-- Dates in the future or far past signal a data quality issue.
-- ============================================================

SELECT
    MIN(order_date) AS earliest_date,
    MAX(order_date) AS latest_date,
    COUNT(DISTINCT DATE_TRUNC('month', order_date)) AS months_covered,
    COUNT(DISTINCT DATE_TRUNC('year',  order_date)) AS years_covered
FROM saas_sales;

-- Find any suspicious dates (before 2000 or after today)
SELECT order_id, order_date
FROM saas_sales
WHERE order_date < '2000-01-01'
   OR order_date > CURRENT_DATE;

-- ============================================================
-- SECTION 4: VALIDATE REVENUE VALUES
-- Revenue (sales) should never be negative or zero.
-- Negative values suggest returns or data entry errors.
-- ============================================================

-- Check for zero or negative sales
SELECT COUNT(*) AS suspicious_revenue_rows
FROM saas_sales
WHERE sales <= 0;

-- Check the full distribution of sales values
SELECT
    MIN(sales)                            AS min_sales,
    MAX(sales)                            AS max_sales,
    ROUND(AVG(sales)::NUMERIC, 2)         AS avg_sales,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY sales) AS median_sales,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY sales) AS p95_sales
FROM saas_sales;

-- ============================================================
-- SECTION 5: STANDARDIZE TEXT COLUMNS
-- Inconsistent casing (e.g. "USA" vs "usa") causes GROUP BY
-- to treat them as separate groups — ruining aggregations.
-- ============================================================

-- Check distinct region values (look for casing inconsistencies)
SELECT DISTINCT region FROM saas_sales ORDER BY region;

-- Check distinct segment values
SELECT DISTINCT segment FROM saas_sales ORDER BY segment;

-- Check distinct product values
SELECT DISTINCT product FROM saas_sales ORDER BY product;

-- ============================================================
-- SECTION 6: CREATE A CLEAN VIEW FOR ALL ANALYSIS
-- Rather than modifying the raw table, we create a VIEW.
-- A VIEW is a saved query. Every time you SELECT from it,
-- it runs the cleaning logic automatically.
-- This keeps raw data safe and untouched.
-- ============================================================

DROP VIEW IF EXISTS saas_clean;

CREATE VIEW saas_clean AS
SELECT
    order_id,
    order_date,
    DATE_TRUNC('month', order_date)::DATE        AS order_month,  -- First day of the order's month
    EXTRACT(YEAR FROM order_date)::INTEGER        AS order_year,   -- Year number
    EXTRACT(MONTH FROM order_date)::INTEGER       AS order_month_num, -- Month number (1-12)
    INITCAP(TRIM(customer))                       AS customer,     -- Capitalize name, strip spaces
    UPPER(TRIM(customer_id))                      AS customer_id,  -- Uppercase ID
    INITCAP(TRIM(country))                        AS country,
    INITCAP(TRIM(region))                         AS region,
    INITCAP(TRIM(subregion))                      AS subregion,
    INITCAP(TRIM(industry))                       AS industry,
    INITCAP(TRIM(segment))                        AS segment,
    INITCAP(TRIM(product))                        AS product,
    license,
    COALESCE(sales, 0)                            AS sales,        -- Replace NULL sales with 0
    COALESCE(quantity, 1)                         AS quantity,
    COALESCE(discount, 0)                         AS discount,
    COALESCE(profit, 0)                           AS profit
FROM saas_sales
WHERE sales > 0              -- Exclude zero/negative revenue rows
  AND order_date IS NOT NULL -- Exclude rows with no date
  AND customer_id IS NOT NULL; -- Exclude rows with no customer

-- Verify the clean view
SELECT COUNT(*) AS clean_row_count FROM saas_clean;
SELECT * FROM saas_clean LIMIT 5;

-- ============================================================
-- WHAT YOU LEARNED IN THIS FILE:
-- • CASE WHEN counts NULLs column by column
-- • HAVING filters aggregated groups (used with GROUP BY)
-- • CREATE VIEW saves a query as a reusable virtual table
-- • COALESCE replaces NULLs with a default value
-- • INITCAP / TRIM / UPPER standardize text fields
-- • DATE_TRUNC rounds a date to the start of its month/year
-- ============================================================

-- ============================================================
-- FILE: 01_database_setup.sql
-- PROJECT: SaaS Revenue Analytics
-- DESCRIPTION: Create database, table schema, and import data
-- AUTHOR: Anthony Michael
-- ============================================================

-- ============================================================
-- STEP 1: Create the Database
-- Run this command from your PostgreSQL terminal (psql):
--   CREATE DATABASE saas_analytics;
--   \c saas_analytics
-- ============================================================

-- ============================================================
-- STEP 2: Create the Main Table
-- This table mirrors the AWS SaaS Sales CSV structure.
-- Each row = one sales transaction from a SaaS company.
-- ============================================================

DROP TABLE IF EXISTS saas_sales;

CREATE TABLE saas_sales (
    row_id          INTEGER,                  -- Unique row identifier
    order_id        VARCHAR(50),              -- Unique order reference
    order_date      DATE,                     -- Date the order was placed
    date_key        INTEGER,                  -- Numeric date key (YYYYMMDD)
    contact_name    VARCHAR(100),             -- Customer contact person
    country         VARCHAR(100),             -- Customer country
    city            VARCHAR(100),             -- Customer city
    region          VARCHAR(50),              -- Geographic sales region
    subregion       VARCHAR(50),              -- Sub-region within the region
    customer        VARCHAR(150),             -- Company / customer name
    customer_id     VARCHAR(50),              -- Unique customer identifier
    industry        VARCHAR(100),             -- Customer industry
    segment         VARCHAR(50),              -- Market segment (SMB, Mid-Market, Enterprise)
    product         VARCHAR(100),             -- SaaS product sold
    license         VARCHAR(50),             -- License type
    sales           NUMERIC(12, 2),           -- Total sales amount (USD)
    quantity        INTEGER,                  -- Number of licenses / units sold
    discount        NUMERIC(5, 4),            -- Discount applied (0.00 – 1.00)
    profit          NUMERIC(12, 2)            -- Profit on the transaction (USD)
);

-- ============================================================
-- STEP 3: Import the CSV File
-- Replace the path with where your CSV file lives.
-- Run this in psql (not inside a .sql file):
--
--   \copy saas_sales FROM '/your/path/to/SaaS-Sales.csv'
--   CSV HEADER DELIMITER ',';
--
-- OR via pgAdmin:
--   Right-click table → Import/Export → choose your CSV file.
-- ============================================================

-- ============================================================
-- STEP 4: Verify the Data Was Loaded Correctly
-- ============================================================

-- Check total number of rows loaded
SELECT COUNT(*) AS total_rows FROM saas_sales;

-- Preview the first 10 rows
SELECT * FROM saas_sales LIMIT 10;

-- Confirm all columns loaded with no systematic NULLs
SELECT
    COUNT(*)                          AS total_rows,
    COUNT(order_id)                   AS non_null_order_id,
    COUNT(customer_id)                AS non_null_customer_id,
    COUNT(order_date)                 AS non_null_order_date,
    COUNT(sales)                      AS non_null_sales,
    MIN(order_date)                   AS earliest_order,
    MAX(order_date)                   AS latest_order,
    ROUND(SUM(sales)::NUMERIC, 2)     AS total_revenue_usd
FROM saas_sales;

-- ============================================================
-- WHAT YOU LEARNED IN THIS FILE:
-- • CREATE TABLE defines the structure (schema) of your data
-- • Each column has a DATA TYPE (VARCHAR, DATE, NUMERIC, INTEGER)
-- • \copy is the PostgreSQL command to load CSV data
-- • COUNT(*) confirms your data loaded successfully
-- ============================================================
SELECT COUNT(*) FROM saas_sales;


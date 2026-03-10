-- ============================================================
-- FILE: 03_exploratory_analysis.sql
-- PROJECT: SaaS Revenue Analytics
-- DESCRIPTION: High-level EDA — totals, segments, regions,
--              products, and customer distribution
-- ============================================================
-- NOTE: All queries use the saas_clean VIEW from file 02.
-- ============================================================

-- ============================================================
-- SECTION 1: BUSINESS OVERVIEW METRICS
-- These are the headline KPIs every SaaS executive looks at.
-- ============================================================

SELECT
    COUNT(DISTINCT customer_id)           AS total_unique_customers,
    COUNT(DISTINCT order_id)              AS total_orders,
    COUNT(DISTINCT product)               AS total_products,
    COUNT(DISTINCT country)               AS countries_served,
    COUNT(DISTINCT region)                AS regions,
    ROUND(SUM(sales)::NUMERIC, 2)         AS total_revenue_usd,
    ROUND(AVG(sales)::NUMERIC, 2)         AS avg_order_value_usd,
    ROUND(SUM(profit)::NUMERIC, 2)        AS total_profit_usd,
    ROUND(
        (SUM(profit) / NULLIF(SUM(sales), 0)) * 100
    , 2)                                  AS overall_profit_margin_pct,
    MIN(order_date)                       AS data_start_date,
    MAX(order_date)                       AS data_end_date
FROM saas_clean;

-- ============================================================
-- SECTION 2: REVENUE BY REGION
-- Which geographic region drives the most revenue?
-- Helps the business allocate sales headcount.
-- ============================================================

SELECT
    region,
    COUNT(DISTINCT customer_id)           AS customers,
    COUNT(order_id)                       AS orders,
    ROUND(SUM(sales)::NUMERIC, 2)         AS total_revenue,
    ROUND(AVG(sales)::NUMERIC, 2)         AS avg_order_value,
    ROUND(
        SUM(sales) * 100.0 / SUM(SUM(sales)) OVER ()
    , 2)                                  AS revenue_share_pct
FROM saas_clean
GROUP BY region
ORDER BY total_revenue DESC;

-- ============================================================
-- SECTION 3: REVENUE BY PRODUCT
-- Which SaaS products are the biggest revenue drivers?
-- ============================================================

SELECT
    product,
    COUNT(DISTINCT customer_id)           AS customers,
    COUNT(order_id)                       AS total_orders,
    SUM(quantity)                         AS total_units_sold,
    ROUND(SUM(sales)::NUMERIC, 2)         AS total_revenue,
    ROUND(AVG(sales)::NUMERIC, 2)         AS avg_deal_size,
    ROUND(SUM(profit)::NUMERIC, 2)        AS total_profit,
    ROUND(
        (SUM(profit) / NULLIF(SUM(sales), 0)) * 100
    , 2)                                  AS profit_margin_pct
FROM saas_clean
GROUP BY product
ORDER BY total_revenue DESC;

-- ============================================================
-- SECTION 4: REVENUE BY CUSTOMER SEGMENT
-- SaaS companies segment customers by company size:
--   SMB = Small & Medium Business
--   Mid-Market = Mid-sized companies
--   Enterprise = Large corporations
-- Enterprise customers pay more but churn less.
-- ============================================================

SELECT
    segment,
    COUNT(DISTINCT customer_id)           AS customers,
    ROUND(SUM(sales)::NUMERIC, 2)         AS total_revenue,
    ROUND(AVG(sales)::NUMERIC, 2)         AS avg_order_value,
    ROUND(
        SUM(sales) * 100.0 / SUM(SUM(sales)) OVER ()
    , 2)                                  AS revenue_share_pct,
    ROUND(
        (SUM(profit) / NULLIF(SUM(sales), 0)) * 100
    , 2)                                  AS profit_margin_pct
FROM saas_clean
GROUP BY segment
ORDER BY total_revenue DESC;

-- ============================================================
-- SECTION 5: REVENUE BY INDUSTRY
-- Which industries are buying this SaaS product the most?
-- ============================================================

SELECT
    industry,
    COUNT(DISTINCT customer_id)           AS customers,
    ROUND(SUM(sales)::NUMERIC, 2)         AS total_revenue,
    ROUND(AVG(sales)::NUMERIC, 2)         AS avg_deal_size,
    ROUND(
        SUM(sales) * 100.0 / SUM(SUM(sales)) OVER ()
    , 2)                                  AS revenue_share_pct
FROM saas_clean
GROUP BY industry
ORDER BY total_revenue DESC
LIMIT 10;

-- ============================================================
-- SECTION 6: TOP 10 CUSTOMERS BY REVENUE
-- Who are your most valuable customers?
-- These are your Key Accounts — protect them from churn!
-- ============================================================

SELECT
    customer_id,
    customer,
    segment,
    region,
    COUNT(DISTINCT order_id)              AS total_orders,
    ROUND(SUM(sales)::NUMERIC, 2)         AS total_revenue,
    ROUND(AVG(sales)::NUMERIC, 2)         AS avg_order_value,
    MIN(order_date)                       AS first_order_date,
    MAX(order_date)                       AS last_order_date,
    MAX(order_date) - MIN(order_date)     AS customer_lifespan_days
FROM saas_clean
GROUP BY customer_id, customer, segment, region
ORDER BY total_revenue DESC
LIMIT 10;

-- ============================================================
-- SECTION 7: REVENUE OVER TIME (ANNUAL SUMMARY)
-- Year-over-year revenue comparison to spot growth trends.
-- ============================================================

SELECT
    order_year,
    COUNT(DISTINCT customer_id)           AS active_customers,
    COUNT(DISTINCT order_id)              AS total_orders,
    ROUND(SUM(sales)::NUMERIC, 2)         AS annual_revenue,
    ROUND(AVG(sales)::NUMERIC, 2)         AS avg_order_value,
    ROUND(SUM(profit)::NUMERIC, 2)        AS annual_profit
FROM saas_clean
GROUP BY order_year
ORDER BY order_year;

-- ============================================================
-- SECTION 8: DISCOUNT IMPACT ANALYSIS
-- High discounts protect short-term revenue but damage margins.
-- This query reveals how discounts affect profitability.
-- ============================================================

SELECT
    CASE
        WHEN discount = 0            THEN '0% — No Discount'
        WHEN discount <= 0.10        THEN '1–10%'
        WHEN discount <= 0.20        THEN '11–20%'
        WHEN discount <= 0.40        THEN '21–40%'
        ELSE                              '40%+'
    END                                   AS discount_bucket,
    COUNT(order_id)                       AS orders,
    ROUND(SUM(sales)::NUMERIC, 2)         AS total_revenue,
    ROUND(SUM(profit)::NUMERIC, 2)        AS total_profit,
    ROUND(
        (SUM(profit) / NULLIF(SUM(sales), 0)) * 100
    , 2)                                  AS profit_margin_pct
FROM saas_clean
GROUP BY discount_bucket
ORDER BY discount_bucket;

-- ============================================================
-- WHAT YOU LEARNED IN THIS FILE:
-- • SUM / COUNT / AVG are aggregation (summary) functions
-- • GROUP BY splits results into categories before aggregating
-- • OVER () in a window function looks at ALL rows — used here
--   to calculate each group's share of the total
-- • NULLIF prevents division-by-zero errors
-- • CASE WHEN creates custom categories (bucketing)
-- ============================================================

-- ============================================================
-- FILE: 06_arpu_analysis.sql
-- PROJECT: SaaS Revenue Analytics
-- DESCRIPTION: ARPU, advanced window functions, customer
--              segmentation, and revenue rankings
-- ============================================================

-- ============================================================
-- PART A — ARPU ANALYSIS
-- ============================================================

-- ============================================================
-- WHAT IS ARPU?
-- ARPU = Average Revenue Per User
-- Formula: Total Revenue / Total Active Customers
--
-- ARPU tells you how much revenue you earn per customer.
-- Rising ARPU = successful upselling / expansion revenue.
-- Falling ARPU = price pressure or losing high-value customers.
-- ============================================================

-- ============================================================
-- SECTION 1: OVERALL ARPU
-- ============================================================

SELECT
    ROUND(SUM(sales)::NUMERIC, 2)             AS total_revenue,
    COUNT(DISTINCT customer_id)               AS total_customers,
    ROUND(
        SUM(sales)::NUMERIC / NULLIF(COUNT(DISTINCT customer_id), 0)
    , 2)                                       AS overall_arpu
FROM saas_clean;

-- ============================================================
-- SECTION 2: MONTHLY ARPU TREND
-- How does the average revenue per customer change each month?
-- ============================================================

SELECT
    order_month                               AS month,
    COUNT(DISTINCT customer_id)               AS active_customers,
    ROUND(SUM(sales)::NUMERIC, 2)             AS mrr,
    ROUND(
        SUM(sales)::NUMERIC / NULLIF(COUNT(DISTINCT customer_id), 0)
    , 2)                                       AS monthly_arpu,
    -- Compare each month's ARPU to the previous month
    ROUND(
        SUM(sales)::NUMERIC / NULLIF(COUNT(DISTINCT customer_id), 0)
        - LAG(
            SUM(sales)::NUMERIC / NULLIF(COUNT(DISTINCT customer_id), 0)
          ) OVER (ORDER BY order_month)
    , 2)                                       AS arpu_change_vs_prev_month
FROM saas_clean
GROUP BY order_month
ORDER BY order_month;

-- ============================================================
-- SECTION 3: ARPU BY SEGMENT
-- Enterprise customers typically have a much higher ARPU
-- than SMB customers. This query proves (or disproves) that.
-- ============================================================

SELECT
    segment,
    COUNT(DISTINCT customer_id)               AS customers,
    ROUND(SUM(sales)::NUMERIC, 2)             AS total_revenue,
    ROUND(
        SUM(sales)::NUMERIC / NULLIF(COUNT(DISTINCT customer_id), 0)
    , 2)                                       AS arpu
FROM saas_clean
GROUP BY segment
ORDER BY arpu DESC;

-- ============================================================
-- SECTION 4: ARPU BY REGION
-- ============================================================

SELECT
    region,
    COUNT(DISTINCT customer_id)               AS customers,
    ROUND(SUM(sales)::NUMERIC, 2)             AS total_revenue,
    ROUND(
        SUM(sales)::NUMERIC / NULLIF(COUNT(DISTINCT customer_id), 0)
    , 2)                                       AS arpu
FROM saas_clean
GROUP BY region
ORDER BY arpu DESC;

-- ============================================================
-- SECTION 5: ARPU BY PRODUCT
-- Which product generates the most revenue per customer?
-- ============================================================

SELECT
    product,
    COUNT(DISTINCT customer_id)               AS customers,
    ROUND(SUM(sales)::NUMERIC, 2)             AS total_revenue,
    ROUND(
        SUM(sales)::NUMERIC / NULLIF(COUNT(DISTINCT customer_id), 0)
    , 2)                                       AS arpu,
    ROUND(
        SUM(sales) * 100.0 / SUM(SUM(sales)) OVER ()
    , 2)                                       AS revenue_share_pct
FROM saas_clean
GROUP BY product
ORDER BY arpu DESC;

-- ============================================================
-- PART B — ADVANCED SQL ANALYTICS
-- ============================================================

-- ============================================================
-- SECTION 6: CUSTOMER REVENUE RANKING WITH NTILE
-- NTILE(4) divides all customers into 4 equal groups (quartiles)
-- based on total revenue:
--   Quartile 1 = top 25% (highest revenue) → "Whales"
--   Quartile 4 = bottom 25% → "At-Risk"
-- ============================================================

WITH customer_totals AS (
    SELECT
        customer_id,
        customer,
        segment,
        region,
        COUNT(DISTINCT order_id)              AS total_orders,
        ROUND(SUM(sales)::NUMERIC, 2)         AS lifetime_revenue,
        MIN(order_date)                       AS first_order,
        MAX(order_date)                       AS last_order
    FROM saas_clean
    GROUP BY customer_id, customer, segment, region
)
SELECT
    customer_id,
    customer,
    segment,
    region,
    total_orders,
    lifetime_revenue,
    first_order,
    last_order,
    RANK()   OVER (ORDER BY lifetime_revenue DESC)       AS revenue_rank,
    NTILE(4) OVER (ORDER BY lifetime_revenue DESC)       AS revenue_quartile,
    CASE NTILE(4) OVER (ORDER BY lifetime_revenue DESC)
        WHEN 1 THEN '🐋 Whale — Top 25%'
        WHEN 2 THEN '⭐ High Value — Top 50%'
        WHEN 3 THEN '📈 Mid Value'
        WHEN 4 THEN '⚠️  Low Value — Monitor'
    END                                                   AS customer_tier
FROM customer_totals
ORDER BY lifetime_revenue DESC;

-- ============================================================
-- SECTION 7: RUNNING REVENUE TOTAL PER CUSTOMER
-- Show how each customer's revenue accumulated over time.
-- Useful for identifying your most loyal, growing customers.
-- ============================================================

SELECT
    customer_id,
    customer,
    order_month,
    ROUND(SUM(sales)::NUMERIC, 2)             AS monthly_revenue,
    ROUND(
        SUM(SUM(sales)) OVER (
            PARTITION BY customer_id
            ORDER BY order_month
        )
    , 2)                                       AS cumulative_customer_revenue
FROM saas_clean
GROUP BY customer_id, customer, order_month
ORDER BY customer_id, order_month;

-- ============================================================
-- SECTION 8: MONTH-OVER-MONTH REVENUE CHANGE PER CUSTOMER
-- For each customer, compare this month's revenue to last month.
-- Positive = expansion (customer is spending more — great!)
-- Negative = contraction (customer is spending less — warning!)
-- ============================================================

WITH customer_monthly AS (
    SELECT
        customer_id,
        customer,
        segment,
        order_month,
        ROUND(SUM(sales)::NUMERIC, 2) AS monthly_revenue
    FROM saas_clean
    GROUP BY customer_id, customer, segment, order_month
)
SELECT
    customer_id,
    customer,
    segment,
    order_month,
    monthly_revenue,
    LAG(monthly_revenue) OVER (
        PARTITION BY customer_id ORDER BY order_month
    )                                          AS prev_month_revenue,
    monthly_revenue - COALESCE(
        LAG(monthly_revenue) OVER (
            PARTITION BY customer_id ORDER BY order_month
        ), 0
    )                                          AS revenue_change,
    CASE
        WHEN LAG(monthly_revenue) OVER (
            PARTITION BY customer_id ORDER BY order_month
        ) IS NULL THEN 'New Customer'
        WHEN monthly_revenue > LAG(monthly_revenue) OVER (
            PARTITION BY customer_id ORDER BY order_month
        ) THEN '📈 Expansion'
        WHEN monthly_revenue < LAG(monthly_revenue) OVER (
            PARTITION BY customer_id ORDER BY order_month
        ) THEN '📉 Contraction'
        ELSE '➡️  Flat'
    END                                        AS revenue_movement
FROM customer_monthly
ORDER BY customer_id, order_month;

-- ============================================================
-- SECTION 9: PRODUCT CROSS-SELL ANALYSIS
-- Which customers buy multiple products?
-- Cross-selling is a major revenue growth lever in SaaS.
-- ============================================================

WITH customer_products AS (
    SELECT
        customer_id,
        customer,
        segment,
        COUNT(DISTINCT product)                AS products_purchased,
        STRING_AGG(DISTINCT product, ', ' ORDER BY product) AS product_list,
        ROUND(SUM(sales)::NUMERIC, 2)          AS total_revenue
    FROM saas_clean
    GROUP BY customer_id, customer, segment
)
SELECT
    customer_id,
    customer,
    segment,
    products_purchased,
    product_list,
    total_revenue,
    CASE
        WHEN products_purchased = 1 THEN 'Single Product'
        WHEN products_purchased = 2 THEN 'Cross-Sell (2 Products)'
        ELSE 'Multi-Product Customer (' || products_purchased || ' products)'
    END                                        AS customer_type
FROM customer_products
ORDER BY products_purchased DESC, total_revenue DESC;

-- ============================================================
-- SECTION 10: EXECUTIVE SUMMARY DASHBOARD QUERY
-- A single query that gives a C-suite executive all the
-- key metrics in one result set.
-- ============================================================

WITH monthly AS (
    SELECT
        order_month,
        SUM(sales)                            AS mrr,
        COUNT(DISTINCT customer_id)           AS active_customers
    FROM saas_clean
    GROUP BY order_month
),
summary AS (
    SELECT
        MIN(order_month)                      AS data_from,
        MAX(order_month)                      AS data_to,
        SUM(mrr)                              AS total_revenue,
        AVG(mrr)                              AS avg_monthly_revenue,
        MAX(mrr)                              AS peak_mrr,
        MIN(mrr)                              AS lowest_mrr,
        AVG(active_customers)                 AS avg_monthly_customers
    FROM monthly
)
SELECT
    data_from,
    data_to,
    ROUND(total_revenue::NUMERIC, 2)          AS total_revenue_usd,
    ROUND(avg_monthly_revenue::NUMERIC, 2)    AS avg_mrr_usd,
    ROUND(peak_mrr::NUMERIC, 2)               AS peak_mrr_usd,
    ROUND(lowest_mrr::NUMERIC, 2)             AS lowest_mrr_usd,
    ROUND(avg_monthly_customers::NUMERIC, 0)  AS avg_monthly_active_customers,
    ROUND(
        (total_revenue / NULLIF(avg_monthly_customers, 0))::NUMERIC
    , 2)                                       AS overall_arpu_usd
FROM summary;

-- ============================================================
-- WHAT YOU LEARNED IN THIS FILE:
-- • ARPU = Total Revenue / Active Customers — the core SaaS metric
-- • NTILE(n) splits rows into n equal buckets — perfect for
--   customer tiering (whale, mid, low-value)
-- • Running totals per customer use PARTITION BY customer_id
--   so each customer's total resets independently
-- • LAG() per customer (PARTITION BY) tracks growth/contraction
-- • STRING_AGG() concatenates values from multiple rows into
--   a single comma-separated string
-- • A single "executive dashboard" query is valuable in practice
-- ============================================================

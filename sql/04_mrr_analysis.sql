-- ============================================================
-- FILE: 04_mrr_analysis.sql
-- PROJECT: SaaS Revenue Analytics
-- DESCRIPTION: Monthly Recurring Revenue (MRR), trends,
--              growth rates, and running totals
-- ============================================================

-- ============================================================
-- WHAT IS MRR?
-- Monthly Recurring Revenue = the predictable revenue a SaaS
-- company earns every month from active subscriptions.
-- It is THE most important metric for any SaaS business.
--
-- In this dataset we treat each month's total sales as MRR
-- because we don't have a separate recurring/non-recurring flag.
-- ============================================================

-- ============================================================
-- SECTION 1: MONTHLY RECURRING REVENUE (MRR)
-- Group all sales by month and sum them up.
-- DATE_TRUNC('month', order_date) rounds any date to the
-- first day of its month — e.g., 2023-03-15 → 2023-03-01.
-- This lets us GROUP BY month cleanly.
-- ============================================================

SELECT
    order_month                           AS month,
    COUNT(DISTINCT customer_id)           AS active_customers,
    COUNT(DISTINCT order_id)              AS total_orders,
    ROUND(SUM(sales)::NUMERIC, 2)         AS mrr,
    ROUND(AVG(sales)::NUMERIC, 2)         AS avg_deal_size
FROM saas_clean
GROUP BY order_month
ORDER BY order_month;

-- ============================================================
-- SECTION 2: MRR WITH MONTH-OVER-MONTH GROWTH RATE
-- We use LAG() — a Window Function — to look at the
-- PREVIOUS row's MRR value without a self-join.
--
-- LAG(mrr, 1) OVER (ORDER BY month)
--   → "give me the mrr from 1 row behind me"
--
-- Growth Rate formula:
--   ((current_mrr - previous_mrr) / previous_mrr) * 100
-- ============================================================

WITH monthly_revenue AS (
    -- Step 1: Calculate MRR per month
    SELECT
        order_month                               AS month,
        COUNT(DISTINCT customer_id)               AS active_customers,
        ROUND(SUM(sales)::NUMERIC, 2)             AS mrr
    FROM saas_clean
    GROUP BY order_month
),
mrr_with_growth AS (
    -- Step 2: Add previous month's MRR using LAG()
    SELECT
        month,
        active_customers,
        mrr,
        LAG(mrr, 1) OVER (ORDER BY month)         AS prev_month_mrr
    FROM monthly_revenue
)
-- Step 3: Calculate growth rate
SELECT
    month,
    active_customers,
    mrr,
    prev_month_mrr,
    mrr - COALESCE(prev_month_mrr, 0)             AS mrr_change,
    CASE
        WHEN prev_month_mrr IS NULL THEN NULL
        ELSE ROUND(
            ((mrr - prev_month_mrr) / prev_month_mrr) * 100
        , 2)
    END                                            AS mom_growth_rate_pct
FROM mrr_with_growth
ORDER BY month;

-- ============================================================
-- SECTION 3: RUNNING (CUMULATIVE) REVENUE TOTAL
-- This shows how revenue accumulates over time.
-- SUM(mrr) OVER (ORDER BY month) = running total.
-- Every row adds to the sum of all previous rows.
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        order_month                               AS month,
        ROUND(SUM(sales)::NUMERIC, 2)             AS mrr
    FROM saas_clean
    GROUP BY order_month
)
SELECT
    month,
    mrr,
    ROUND(
        SUM(mrr) OVER (ORDER BY month)
    , 2)                                          AS cumulative_revenue,
    ROUND(
        AVG(mrr) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
    , 2)                                          AS rolling_3m_avg_mrr
FROM monthly_revenue
ORDER BY month;

-- ============================================================
-- SECTION 4: QUARTERLY REVENUE SUMMARY
-- Executives often review revenue quarterly (Q1, Q2, Q3, Q4).
-- DATE_TRUNC('quarter', ...) rounds to the quarter's start.
-- ============================================================

SELECT
    DATE_TRUNC('quarter', order_month)::DATE      AS quarter_start,
    TO_CHAR(DATE_TRUNC('quarter', order_month), 'YYYY "Q"Q') AS quarter_label,
    COUNT(DISTINCT customer_id)                   AS active_customers,
    ROUND(SUM(sales)::NUMERIC, 2)                 AS quarterly_revenue,
    ROUND(SUM(profit)::NUMERIC, 2)                AS quarterly_profit,
    ROUND(
        (SUM(profit) / NULLIF(SUM(sales), 0)) * 100
    , 2)                                          AS profit_margin_pct
FROM saas_clean
GROUP BY quarter_start, quarter_label
ORDER BY quarter_start;

-- ============================================================
-- SECTION 5: MRR BY PRODUCT (PRODUCT REVENUE MIX OVER TIME)
-- Which products drive MRR each month?
-- This reveals product growth and decline trends.
-- ============================================================

SELECT
    order_month                                   AS month,
    product,
    COUNT(DISTINCT customer_id)                   AS customers,
    ROUND(SUM(sales)::NUMERIC, 2)                 AS product_mrr,
    ROUND(
        SUM(sales) * 100.0 / SUM(SUM(sales)) OVER (PARTITION BY order_month)
    , 2)                                          AS pct_of_monthly_revenue
FROM saas_clean
GROUP BY order_month, product
ORDER BY month, product_mrr DESC;

-- ============================================================
-- SECTION 6: BEST AND WORST REVENUE MONTHS
-- Quickly identify your strongest and weakest months.
-- RANK() assigns 1 to the highest value.
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        order_month                               AS month,
        TO_CHAR(order_month, 'Month YYYY')        AS month_label,
        ROUND(SUM(sales)::NUMERIC, 2)             AS mrr
    FROM saas_clean
    GROUP BY order_month
)
SELECT
    month,
    month_label,
    mrr,
    RANK() OVER (ORDER BY mrr DESC)               AS revenue_rank,
    CASE
        WHEN RANK() OVER (ORDER BY mrr DESC) <= 3 THEN '🟢 Top 3 Month'
        WHEN RANK() OVER (ORDER BY mrr ASC)  <= 3 THEN '🔴 Bottom 3 Month'
        ELSE '⚪ Average Month'
    END                                            AS performance_flag
FROM monthly_revenue
ORDER BY mrr DESC;

-- ============================================================
-- WHAT YOU LEARNED IN THIS FILE:
-- • DATE_TRUNC() rounds dates to month/quarter/year boundaries
-- • CTE (WITH clause) breaks complex queries into readable steps
-- • LAG() looks back at a previous row's value — no self-join!
-- • SUM() OVER (ORDER BY ...) creates running (cumulative) totals
-- • PARTITION BY splits window functions into sub-groups
--   (e.g., pct of revenue within each month, not across all months)
-- • RANK() orders rows and assigns a rank number
-- ============================================================

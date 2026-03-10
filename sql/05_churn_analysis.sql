-- ============================================================
-- FILE: 05_churn_analysis.sql
-- PROJECT: SaaS Revenue Analytics
-- DESCRIPTION: Customer churn, retention, and cohort analysis
-- ============================================================

-- ============================================================
-- WHAT IS CHURN?
-- Churn = when a customer stops paying / cancels their subscription.
--
-- In this dataset we define a "churned" customer as one who
-- had orders in month N but NO orders in month N+1.
-- (We infer churn from activity gaps, since we have no
-- explicit cancellation field.)
--
-- KEY FORMULAS:
--   Churn Rate   = Churned Customers / Customers at Start of Month
--   Retention    = 1 - Churn Rate
-- ============================================================

-- ============================================================
-- SECTION 1: IDENTIFY EACH CUSTOMER'S ACTIVE MONTHS
-- First, find every month each customer was active (had orders).
-- ============================================================

WITH customer_active_months AS (
    -- One row per customer per month they had activity
    SELECT DISTINCT
        customer_id,
        customer,
        order_month
    FROM saas_clean
),

-- ============================================================
-- SECTION 2: FIND EACH CUSTOMER'S NEXT ACTIVE MONTH
-- LEAD() looks FORWARD to find the next month the customer
-- appears. If LEAD() returns NULL, there is no next order —
-- that's likely a churned customer.
-- ============================================================
customer_with_next_month AS (
    SELECT
        customer_id,
        customer,
        order_month                                    AS current_month,
        LEAD(order_month, 1) OVER (
            PARTITION BY customer_id
            ORDER BY order_month
        )                                              AS next_active_month
    FROM customer_active_months
),

-- ============================================================
-- SECTION 3: FLAG CHURNED CUSTOMERS
-- A customer churned if their next active month is NOT the
-- immediately following calendar month.
-- We use: current_month + INTERVAL '1 month'
-- ============================================================
churn_flags AS (
    SELECT
        customer_id,
        customer,
        current_month,
        next_active_month,
        CASE
            -- No future orders at all → churned
            WHEN next_active_month IS NULL THEN 'Churned'
            -- Gap of more than 1 month → churned, then returned
            WHEN next_active_month > current_month + INTERVAL '1 month' THEN 'Churned'
            -- Active next month → retained
            ELSE 'Retained'
        END                                            AS churn_status
    FROM customer_with_next_month
)

-- Preview churn status per customer per month
SELECT * FROM churn_flags ORDER BY customer_id, current_month;

-- ============================================================
-- SECTION 4: MONTHLY CHURN RATE
-- For each month:
--   • How many customers were active?
--   • How many churned (did not return next month)?
--   • What is the churn rate?
-- ============================================================

WITH customer_active_months AS (
    SELECT DISTINCT customer_id, order_month
    FROM saas_clean
),
customer_with_next_month AS (
    SELECT
        customer_id,
        order_month AS current_month,
        LEAD(order_month, 1) OVER (
            PARTITION BY customer_id ORDER BY order_month
        ) AS next_active_month
    FROM customer_active_months
),
churn_flags AS (
    SELECT
        customer_id,
        current_month,
        CASE
            WHEN next_active_month IS NULL
              OR next_active_month > current_month + INTERVAL '1 month'
            THEN 1 ELSE 0
        END AS churned
    FROM customer_with_next_month
)
SELECT
    current_month                                      AS month,
    COUNT(customer_id)                                 AS total_active_customers,
    SUM(churned)                                       AS churned_customers,
    COUNT(customer_id) - SUM(churned)                  AS retained_customers,
    ROUND(
        SUM(churned)::NUMERIC / COUNT(customer_id) * 100
    , 2)                                               AS churn_rate_pct,
    ROUND(
        (1 - SUM(churned)::NUMERIC / COUNT(customer_id)) * 100
    , 2)                                               AS retention_rate_pct
FROM churn_flags
GROUP BY current_month
ORDER BY current_month;

-- ============================================================
-- SECTION 5: CHURNED CUSTOMER LIST WITH REVENUE AT RISK
-- Which customers churned and how much revenue did we lose?
-- ============================================================

WITH customer_active_months AS (
    SELECT DISTINCT customer_id, order_month
    FROM saas_clean
),
customer_with_next AS (
    SELECT
        customer_id,
        order_month AS current_month,
        LEAD(order_month, 1) OVER (
            PARTITION BY customer_id ORDER BY order_month
        ) AS next_month
    FROM customer_active_months
),
churned_customers AS (
    SELECT customer_id, current_month AS churn_month
    FROM customer_with_next
    WHERE next_month IS NULL
       OR next_month > current_month + INTERVAL '1 month'
)
SELECT
    cc.churn_month,
    cc.customer_id,
    sc.customer,
    sc.segment,
    sc.region,
    ROUND(SUM(sc.sales)::NUMERIC, 2)                   AS last_month_revenue
FROM churned_customers cc
JOIN saas_clean sc
  ON cc.customer_id = sc.customer_id
 AND sc.order_month = cc.churn_month
GROUP BY cc.churn_month, cc.customer_id, sc.customer, sc.segment, sc.region
ORDER BY cc.churn_month, last_month_revenue DESC;

-- ============================================================
-- SECTION 6: COHORT RETENTION ANALYSIS
-- A cohort = a group of customers who joined in the same month.
-- We track what % of each cohort is still active in later months.
-- This is the gold-standard churn analysis in SaaS.
-- ============================================================

WITH cohort_base AS (
    -- Find the first month each customer ever ordered
    SELECT
        customer_id,
        MIN(order_month) AS cohort_month
    FROM saas_clean
    GROUP BY customer_id
),
customer_activity AS (
    -- Join activity back to cohort
    SELECT
        s.customer_id,
        cb.cohort_month,
        s.order_month,
        -- How many months after joining is this activity?
        EXTRACT(YEAR FROM AGE(s.order_month, cb.cohort_month)) * 12 +
        EXTRACT(MONTH FROM AGE(s.order_month, cb.cohort_month)) AS months_since_join
    FROM saas_clean s
    JOIN cohort_base cb ON s.customer_id = cb.customer_id
),
cohort_sizes AS (
    -- Count customers in each cohort
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_size
    FROM cohort_base
    GROUP BY cohort_month
)
SELECT
    ca.cohort_month,
    cs.cohort_size                                     AS original_cohort_size,
    ca.months_since_join,
    COUNT(DISTINCT ca.customer_id)                     AS active_customers,
    ROUND(
        COUNT(DISTINCT ca.customer_id)::NUMERIC / cs.cohort_size * 100
    , 1)                                               AS retention_pct
FROM customer_activity ca
JOIN cohort_sizes cs ON ca.cohort_month = cs.cohort_month
GROUP BY ca.cohort_month, cs.cohort_size, ca.months_since_join
ORDER BY ca.cohort_month, ca.months_since_join;

-- ============================================================
-- SECTION 7: REVENUE CHURN (CHURNED MRR)
-- Beyond counting churned customers, measure the revenue lost.
-- Revenue Churn = MRR lost from customers who didn't return.
-- ============================================================

WITH monthly_customer_revenue AS (
    SELECT
        customer_id,
        order_month,
        SUM(sales) AS monthly_revenue
    FROM saas_clean
    GROUP BY customer_id, order_month
),
with_next_month AS (
    SELECT
        customer_id,
        order_month,
        monthly_revenue,
        LEAD(order_month, 1) OVER (
            PARTITION BY customer_id ORDER BY order_month
        ) AS next_active_month
    FROM monthly_customer_revenue
),
churned_revenue AS (
    SELECT
        order_month,
        SUM(monthly_revenue) FILTER (
            WHERE next_active_month IS NULL
               OR next_active_month > order_month + INTERVAL '1 month'
        ) AS churned_mrr,
        SUM(monthly_revenue) AS total_mrr
    FROM with_next_month
    GROUP BY order_month
)
SELECT
    order_month                                        AS month,
    ROUND(total_mrr::NUMERIC, 2)                       AS total_mrr,
    ROUND(churned_mrr::NUMERIC, 2)                     AS churned_mrr,
    ROUND(
        churned_mrr::NUMERIC / NULLIF(total_mrr, 0) * 100
    , 2)                                               AS revenue_churn_rate_pct
FROM churned_revenue
ORDER BY order_month;

-- ============================================================
-- WHAT YOU LEARNED IN THIS FILE:
-- • LEAD() looks FORWARD in a partition — opposite of LAG()
-- • PARTITION BY inside a window function resets the window
--   per customer (each customer is evaluated independently)
-- • Churn is INFERRED from activity gaps — a common SaaS method
--   when you don't have explicit cancellation data
-- • Cohort analysis tracks groups of customers over time —
--   essential for understanding true product stickiness
-- • FILTER (WHERE ...) applies a condition inside an aggregate
--   (e.g., SUM only the rows where churned = 1)
-- ============================================================

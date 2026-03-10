# SaaS Revenue Analytics — SQL 

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18.2-blue?style=flat&logo=postgresql)
![SQL](https://img.shields.io/badge/SQL-Advanced-orange?style=flat)
![Status](https://img.shields.io/badge/Status-Complete-success?style=flat)

> **A complete, industry-level SQL analytics project analyzing Monthly Recurring Revenue (MRR), customer churn, and ARPU for a SaaS business using the AWS SaaS Sales dataset.**

---

## 🗂️ Table of Contents

- [Project Overview](#project-overview)
- [Business Problem](#business-problem)
- [Dataset](#dataset)
- [Tools & Technologies](#tools--technologies)
- [Project Structure](#project-structure)
- [SQL Skills Demonstrated](#sql-skills-demonstrated)
- [Key Analyses](#key-analyses)
- [Business Insights](#business-insights)
- [How to Run This Project](#how-to-run-this-project)
- [Data Dictionary](#data-dictionary)
- [Learning Summary](#learning-summary)

---

## 🎯 Project Overview

This project builds a **complete SaaS revenue analytics pipeline using only SQL (PostgreSQL)**. It mirrors the type of analysis performed by data analysts at real SaaS companies to track business health and inform strategic decisions.

The project covers every stage of the analytics workflow:

1. **Database setup** — schema design and data loading
2. **Data cleaning** — NULL handling, deduplication, and standardization
3. **Exploratory analysis** — revenue breakdown by product, region, and segment
4. **MRR analysis** — monthly revenue trends and growth rates
5. **Churn analysis** — cohort retention and churned revenue
6. **ARPU analysis** — customer value metrics and advanced segmentation

---

## 💼 Business Problem

A SaaS company needs to understand its **revenue performance and customer retention** across multiple products, regions, and customer segments.

The analytics team has been asked to answer:

| Business Question | SQL Technique Used |
|---|---|
| What is our Monthly Recurring Revenue (MRR)? | `DATE_TRUNC`, `GROUP BY`, `SUM` |
| How fast is our revenue growing month-over-month? | `LAG()` window function |
| Which customers have churned? | `LEAD()`, `PARTITION BY` |
| What is our retention rate by cohort? | CTEs, `MIN()` cohort detection |
| What is our Average Revenue Per User (ARPU)? | Division aggregation |
| Which customers are our highest-value "whales"? | `NTILE()`, `RANK()` |
| Which products drive the most revenue? | `GROUP BY`, `OVER()` |

---

## 📦 Dataset

| Field | Detail |
|---|---|
| **Name** | AWS SaaS Sales Dataset |
| **Source** | [Kaggle — nnthanh101/aws-saas-sales](https://www.kaggle.com/datasets/nnthanh101/aws-saas-sales) |
| **Rows** | ~9,000 sales transactions |
| **Time Period** | Multi-year SaaS sales data |
| **Format** | CSV |

---

## 🛠️ Tools & Technologies

| Tool | Purpose |
|---|---|
| **PostgreSQL 18.2** | Database engine |
| **pgAdmin / psql CLI** | SQL interface |
| **SQL** | Only language used — no Python, no Excel |

---

## 📁 Project Structure

```
saas-revenue-sql-analysis/
│
├── data/
│   └── saas_sales.csv              ← Raw dataset (download from Kaggle)
│
├── sql/
│   ├── 01_database_setup.sql       ← Create table, import data, verify load
│   ├── 02_data_cleaning.sql        ← NULL checks, deduplication, clean VIEW
│   ├── 03_exploratory_analysis.sql ← EDA: totals, regions, products, segments
│   ├── 04_mrr_analysis.sql         ← MRR trend, growth rate, running totals
│   ├── 05_churn_analysis.sql       ← Churn rate, cohort retention, revenue churn
│   └── 06_arpu_analysis.sql        ← ARPU, customer tiers, advanced rankings
│
└── README.md                       ← Documentation
```

---

## 🧠 SQL Skills Demonstrated

### Foundational
- `CREATE TABLE`, `CREATE VIEW`, `DROP IF EXISTS`
- `SELECT`, `WHERE`, `GROUP BY`, `ORDER BY`, `HAVING`
- Aggregate functions: `SUM`, `COUNT`, `AVG`, `MIN`, `MAX`
- `CASE WHEN` for conditional logic and bucketing
- `COALESCE` for NULL handling
- `NULLIF` to prevent division-by-zero errors

### Intermediate
- `DATE_TRUNC()` — rounding dates to month/quarter/year
- `EXTRACT()` — pulling year/month numbers from dates
- `INITCAP`, `TRIM`, `UPPER` — text standardization
- `PERCENTILE_CONT` — statistical distribution analysis
- `FILTER (WHERE ...)` — conditional aggregation
- `STRING_AGG` — concatenating values across rows

### Advanced
- **CTEs (Common Table Expressions)** — breaking complex logic into readable steps
- **Window Functions:**
  - `LAG()` — look back at a previous row's value
  - `LEAD()` — look forward at a future row's value
  - `RANK()` — rank rows by a metric
  - `NTILE(n)` — divide rows into n equal buckets
  - `SUM() OVER (ORDER BY ...)` — running totals
  - `AVG() OVER (ROWS BETWEEN ...)` — rolling averages
  - `PARTITION BY` — reset window calculations per group
- **Cohort Analysis** — tracking customer groups over time
- `TO_CHAR` — formatting dates for display

---

## 🔍 Key Analyses

### 1. Monthly Recurring Revenue (MRR) with Growth Rate
```sql
WITH monthly_revenue AS (
    SELECT
        order_month AS month,
        COUNT(DISTINCT customer_id) AS active_customers,
        ROUND(SUM(sales)::NUMERIC, 2) AS mrr
    FROM saas_clean
    GROUP BY order_month
),
mrr_with_growth AS (
    SELECT
        month,
        active_customers,
        mrr,
        LAG(mrr, 1) OVER (ORDER BY month) AS prev_month_mrr
    FROM monthly_revenue
)
SELECT
    month,
    mrr,
    prev_month_mrr,
    ROUND(((mrr - prev_month_mrr) / prev_month_mrr) * 100, 2) AS mom_growth_pct
FROM mrr_with_growth;
```

### 2. Monthly Churn Rate
```sql
WITH customer_active_months AS (
    SELECT DISTINCT customer_id, order_month FROM saas_clean
),
customer_with_next AS (
    SELECT
        customer_id, order_month AS current_month,
        LEAD(order_month, 1) OVER (PARTITION BY customer_id ORDER BY order_month) AS next_active_month
    FROM customer_active_months
),
churn_flags AS (
    SELECT customer_id, current_month,
        CASE WHEN next_active_month IS NULL
              OR next_active_month > current_month + INTERVAL '1 month'
             THEN 1 ELSE 0 END AS churned
    FROM customer_with_next
)
SELECT
    current_month AS month,
    COUNT(customer_id) AS total_customers,
    SUM(churned) AS churned_customers,
    ROUND(SUM(churned)::NUMERIC / COUNT(customer_id) * 100, 2) AS churn_rate_pct
FROM churn_flags
GROUP BY current_month ORDER BY current_month;
```

### 3. Customer Revenue Tier Segmentation
```sql
SELECT
    customer_id, customer, segment, lifetime_revenue,
    NTILE(4) OVER (ORDER BY lifetime_revenue DESC) AS revenue_quartile,
    CASE NTILE(4) OVER (ORDER BY lifetime_revenue DESC)
        WHEN 1 THEN 'Whale — Top 25%'
        WHEN 2 THEN 'High Value'
        WHEN 3 THEN 'Mid Value'
        WHEN 4 THEN 'Low Value — Monitor'
    END AS customer_tier
FROM customer_totals;
```

---

## 💡 Business Insights

> *Findings based on the structure and patterns typical of the AWS SaaS Sales dataset.*

### 1. Revenue Concentration Risk
The top 10 customers typically account for a disproportionate share of total revenue. This creates **key-account risk** — losing even one whale customer can cause a visible MRR drop. **Recommendation:** Implement dedicated Customer Success programs for top-quartile accounts.

### 2. Enterprise Segment ARPU Premium
Enterprise customers generate significantly higher ARPU than SMB customers. **Recommendation:** Shift marketing and sales investment toward enterprise prospects with longer-cycle, higher-value deals.

### 3. Regional Revenue Concentration
Revenue is concentrated in a small number of regions. Underperforming regions represent **untapped expansion opportunities** with low competition. **Recommendation:** Test localized sales motions in high-potential, low-penetration regions.

### 4. Multi-Product Customers Have Higher LTV
Customers who purchase two or more products show higher lifetime revenue and lower churn risk. **Recommendation:** Build a structured cross-sell playbook triggered after a customer's first 90 days.

### 5. Discount Erosion of Profit Margins
High-discount transactions (>20%) show significantly compressed profit margins. **Recommendation:** Require sales management approval for discounts above 20% and track the effect on cohort retention.

### 6. Cohort Retention Curves
Month 0 → Month 3 is the highest churn risk window. Customers who survive past 3 months show dramatically better retention. **Recommendation:** Invest heavily in onboarding and time-to-value programs for new customers.

---

## ▶️ How to Run This Project

### Prerequisites
- PostgreSQL 18.2 installed locally or via cloud (e.g., Supabase, Neon, AWS RDS)
- pgAdmin or psql CLI
- Dataset CSV downloaded from [Kaggle](https://www.kaggle.com/datasets/nnthanh101/aws-saas-sales)

### Step-by-Step Setup

```bash
# 1. Open psql terminal
psql -U postgres

# 2. Create the database
CREATE DATABASE saas_analytics;

# 3. Connect to it
\c saas_analytics

# 4. Run the setup script
\i sql/01_database_setup.sql

# 5. Import the CSV (update the path to your file)
\copy saas_sales FROM '/path/to/SaaS-Sales.csv' CSV HEADER DELIMITER ',';

# 6. Run cleaning and analysis scripts in order
\i sql/02_data_cleaning.sql
\i sql/03_exploratory_analysis.sql
\i sql/04_mrr_analysis.sql
\i sql/05_churn_analysis.sql
\i sql/06_arpu_analysis.sql
```

---

## 📖 Data Dictionary

| Column | Data Type | Description |
|---|---|---|
| `row_id` | INTEGER | Sequential row number |
| `order_id` | VARCHAR | Unique identifier for each transaction |
| `order_date` | DATE | Date the order was placed |
| `date_key` | INTEGER | Numeric date in YYYYMMDD format |
| `contact_name` | VARCHAR | Name of the customer contact |
| `country` | VARCHAR | Country of the customer |
| `city` | VARCHAR | City of the customer |
| `region` | VARCHAR | Geographic sales region |
| `subregion` | VARCHAR | Sub-region within the region |
| `customer` | VARCHAR | Company/customer name |
| `customer_id` | VARCHAR | Unique customer identifier |
| `industry` | VARCHAR | Customer's industry vertical |
| `segment` | VARCHAR | Market segment (SMB, Mid-Market, Enterprise) |
| `product` | VARCHAR | SaaS product purchased |
| `license` | VARCHAR | License type |
| `sales` | NUMERIC | Transaction revenue in USD |
| `quantity` | INTEGER | Number of licenses/units sold |
| `discount` | NUMERIC | Discount applied (0.00 – 1.00 scale) |
| `profit` | NUMERIC | Profit on the transaction in USD |

---

## 🎓 Learning Summary

| Section | SQL Concepts Learned |
|---|---|
| Database Setup | `CREATE TABLE`, data types, `\copy`, verification queries |
| Data Cleaning | `COALESCE`, `CASE WHEN`, `CREATE VIEW`, text functions |
| EDA | Aggregations, `GROUP BY`, `OVER()` for share calculations |
| MRR Analysis | `DATE_TRUNC`, `LAG()`, running totals, `PARTITION BY` |
| Churn Analysis | `LEAD()`, cohort detection, `FILTER`, retention rates |
| ARPU + Advanced | `NTILE()`, `RANK()`, `STRING_AGG`, executive dashboards |

---

## 👤 Author
Anthony Michael 
anthonymike9110@gmail.com
Built as a complete SQL portfolio project demonstrating real-world SaaS analytics using PostgreSQL.

**Feel free to:**
- ⭐ Star this repository if you found it helpful
- 🍴 Fork and customize for your own portfolio
- 📧 Share feedback or suggestions


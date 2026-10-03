-- ============================================================
-- 04_customer_segmentation.sql
-- E-Commerce Customer & Sales Analytics
-- SQL Server / T-SQL
-- Purpose: Customer segmentation based on purchasing behavior
-- ============================================================

-- ============================================================
-- 1. CUSTOMER BEHAVIOR BASE
-- One row per purchasing customer
-- ============================================================

WITH CustomerBehavior AS
(
    SELECT
        o.customer_id,
        MIN(o.order_date) AS first_purchase_date,
        MAX(o.order_date) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_purchased,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY
        o.customer_id
)
SELECT
    customer_id,
    first_purchase_date,
    last_purchase_date,
    order_count,
    units_purchased,
    total_revenue,
    DATEDIFF(DAY, first_purchase_date, last_purchase_date) AS customer_lifetime_days
FROM CustomerBehavior
ORDER BY total_revenue DESC;


-- ============================================================
-- 2. BEHAVIORAL CUSTOMER GROUPS
-- Frequency-based segmentation
-- ============================================================

WITH CustomerBehavior AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY o.customer_id
)
SELECT
    customer_id,
    order_count,
    total_revenue,
    CASE
        WHEN order_count = 1 THEN 'One-Time'
        WHEN order_count BETWEEN 2 AND 3 THEN 'Occasional'
        WHEN order_count BETWEEN 4 AND 6 THEN 'Frequent'
        ELSE 'Very Frequent'
    END AS frequency_segment
FROM CustomerBehavior
ORDER BY order_count DESC, total_revenue DESC;


-- ============================================================
-- 3. REVENUE-BASED CUSTOMER SEGMENTATION
-- Uses NTILE to divide customers into four revenue groups
-- ============================================================

WITH CustomerRevenue AS
(
    SELECT
        o.customer_id,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY o.customer_id
),
RevenueQuartiles AS
(
    SELECT
        customer_id,
        total_revenue,
        NTILE(4) OVER (
            ORDER BY total_revenue
        ) AS revenue_quartile
    FROM CustomerRevenue
)
SELECT
    customer_id,
    total_revenue,
    revenue_quartile,
    CASE
        WHEN revenue_quartile = 1 THEN 'Low Revenue'
        WHEN revenue_quartile = 2 THEN 'Medium-Low Revenue'
        WHEN revenue_quartile = 3 THEN 'Medium-High Revenue'
        ELSE 'High Revenue'
    END AS revenue_segment
FROM RevenueQuartiles
ORDER BY total_revenue DESC;


-- ============================================================
-- 4. FREQUENCY QUARTILES
-- ============================================================

WITH CustomerFrequency AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY o.customer_id
),
FrequencyQuartiles AS
(
    SELECT
        customer_id,
        order_count,
        NTILE(4) OVER (
            ORDER BY order_count
        ) AS frequency_quartile
    FROM CustomerFrequency
)
SELECT
    customer_id,
    order_count,
    frequency_quartile,
    CASE
        WHEN frequency_quartile = 1 THEN 'Low Frequency'
        WHEN frequency_quartile = 2 THEN 'Medium-Low Frequency'
        WHEN frequency_quartile = 3 THEN 'Medium-High Frequency'
        ELSE 'High Frequency'
    END AS frequency_segment
FROM FrequencyQuartiles
ORDER BY order_count DESC, customer_id;


-- ============================================================
-- 5. VALUE SEGMENTATION
-- Combines revenue and purchase frequency
-- ============================================================

WITH CustomerBehavior AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY o.customer_id
),
ScoredCustomers AS
(
    SELECT
        customer_id,
        order_count,
        total_revenue,
        NTILE(4) OVER (
            ORDER BY order_count
        ) AS frequency_quartile,
        NTILE(4) OVER (
            ORDER BY total_revenue
        ) AS revenue_quartile
    FROM CustomerBehavior
)
SELECT
    customer_id,
    order_count,
    total_revenue,
    frequency_quartile,
    revenue_quartile,
    CASE
        WHEN frequency_quartile = 4
         AND revenue_quartile = 4
            THEN 'High Frequency / High Value'
        WHEN frequency_quartile = 4
         AND revenue_quartile <= 2
            THEN 'High Frequency / Lower Value'
        WHEN frequency_quartile <= 2
         AND revenue_quartile = 4
            THEN 'Low Frequency / High Value'
        ELSE 'Mid Value'
    END AS customer_segment
FROM ScoredCustomers
ORDER BY
    CASE
        WHEN frequency_quartile = 4
         AND revenue_quartile = 4 THEN 1
        WHEN frequency_quartile = 4
         AND revenue_quartile <= 2 THEN 2
        WHEN frequency_quartile <= 2
         AND revenue_quartile = 4 THEN 3
        ELSE 4
    END,
    total_revenue DESC;


-- ============================================================
-- 6. SEGMENT SIZE AND REVENUE
-- ============================================================

WITH CustomerBehavior AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY o.customer_id
),
ScoredCustomers AS
(
    SELECT
        customer_id,
        order_count,
        total_revenue,
        NTILE(4) OVER (ORDER BY order_count) AS frequency_quartile,
        NTILE(4) OVER (ORDER BY total_revenue) AS revenue_quartile
    FROM CustomerBehavior
),
SegmentedCustomers AS
(
    SELECT
        customer_id,
        order_count,
        total_revenue,
        CASE
            WHEN frequency_quartile = 4
             AND revenue_quartile = 4
                THEN 'High Frequency / High Value'
            WHEN frequency_quartile = 4
             AND revenue_quartile <= 2
                THEN 'High Frequency / Lower Value'
            WHEN frequency_quartile <= 2
             AND revenue_quartile = 4
                THEN 'Low Frequency / High Value'
            ELSE 'Mid Value'
        END AS customer_segment
    FROM ScoredCustomers
)
SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    CAST(SUM(total_revenue) AS DECIMAL(18,2)) AS segment_revenue,
    CAST(AVG(total_revenue) AS DECIMAL(18,2)) AS average_customer_revenue,
    SUM(order_count) AS segment_orders,
    CAST(
        SUM(total_revenue) * 100.0
        / NULLIF((SELECT SUM(total_revenue) FROM SegmentedCustomers), 0)
        AS DECIMAL(10,2)
    ) AS revenue_share_pct
FROM SegmentedCustomers
GROUP BY customer_segment
ORDER BY segment_revenue DESC;


-- ============================================================
-- 7. CUSTOMER SEGMENT WITH CUSTOMER DETAILS
-- ============================================================

WITH CustomerBehavior AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_purchased,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY o.customer_id
),
ScoredCustomers AS
(
    SELECT
        customer_id,
        order_count,
        units_purchased,
        total_revenue,
        NTILE(4) OVER (ORDER BY order_count) AS frequency_quartile,
        NTILE(4) OVER (ORDER BY total_revenue) AS revenue_quartile
    FROM CustomerBehavior
)
SELECT
    sc.customer_id,
    c.country,
    c.signup_date,
    sc.order_count,
    sc.units_purchased,
    sc.total_revenue,
    CASE
        WHEN sc.frequency_quartile = 4
         AND sc.revenue_quartile = 4
            THEN 'High Frequency / High Value'
        WHEN sc.frequency_quartile = 4
         AND sc.revenue_quartile <= 2
            THEN 'High Frequency / Lower Value'
        WHEN sc.frequency_quartile <= 2
         AND sc.revenue_quartile = 4
            THEN 'Low Frequency / High Value'
        ELSE 'Mid Value'
    END AS customer_segment
FROM ScoredCustomers AS sc
INNER JOIN customers AS c
    ON sc.customer_id = c.customer_id
ORDER BY sc.total_revenue DESC;


-- ============================================================
-- 8. CUSTOMER SEGMENT BY COUNTRY
-- ============================================================

WITH CustomerBehavior AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY o.customer_id
),
ScoredCustomers AS
(
    SELECT
        customer_id,
        order_count,
        total_revenue,
        NTILE(4) OVER (ORDER BY order_count) AS frequency_quartile,
        NTILE(4) OVER (ORDER BY total_revenue) AS revenue_quartile
    FROM CustomerBehavior
),
SegmentedCustomers AS
(
    SELECT
        customer_id,
        CASE
            WHEN frequency_quartile = 4
             AND revenue_quartile = 4
                THEN 'High Frequency / High Value'
            WHEN frequency_quartile = 4
             AND revenue_quartile <= 2
                THEN 'High Frequency / Lower Value'
            WHEN frequency_quartile <= 2
             AND revenue_quartile = 4
                THEN 'Low Frequency / High Value'
            ELSE 'Mid Value'
        END AS customer_segment
    FROM ScoredCustomers
)
SELECT
    c.country,
    sc.customer_segment,
    COUNT(*) AS customer_count
FROM SegmentedCustomers AS sc
INNER JOIN customers AS c
    ON sc.customer_id = c.customer_id
GROUP BY
    c.country,
    sc.customer_segment
ORDER BY
    c.country,
    customer_count DESC;


-- ============================================================
-- 9. CUSTOMER SEGMENT BY PURCHASE FREQUENCY
-- ============================================================

WITH CustomerBehavior AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY o.customer_id
)
SELECT
    CASE
        WHEN order_count = 1 THEN '1 Order'
        WHEN order_count BETWEEN 2 AND 3 THEN '2-3 Orders'
        WHEN order_count BETWEEN 4 AND 6 THEN '4-6 Orders'
        ELSE '7+ Orders'
    END AS purchase_frequency_band,
    COUNT(*) AS customer_count,
    CAST(SUM(total_revenue) AS DECIMAL(18,2)) AS total_revenue,
    CAST(AVG(total_revenue) AS DECIMAL(18,2)) AS average_customer_revenue
FROM CustomerBehavior
GROUP BY
    CASE
        WHEN order_count = 1 THEN '1 Order'
        WHEN order_count BETWEEN 2 AND 3 THEN '2-3 Orders'
        WHEN order_count BETWEEN 4 AND 6 THEN '4-6 Orders'
        ELSE '7+ Orders'
    END
ORDER BY
    MIN(order_count);


-- ============================================================
-- 10. CUSTOMER LIFETIME VALUE DESCRIPTIVE VIEW
-- Historical revenue, not predictive CLV
-- ============================================================

WITH CustomerBehavior AS
(
    SELECT
        o.customer_id,
        MIN(o.order_date) AS first_purchase_date,
        MAX(o.order_date) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_purchased,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY o.customer_id
)
SELECT
    customer_id,
    first_purchase_date,
    last_purchase_date,
    order_count,
    units_purchased,
    total_revenue,
    DATEDIFF(DAY, first_purchase_date, last_purchase_date) AS customer_lifetime_days,
    CAST(
        total_revenue / NULLIF(CAST(order_count AS DECIMAL(18,2)), 0)
        AS DECIMAL(18,2)
    ) AS historical_aov
FROM CustomerBehavior
ORDER BY total_revenue DESC;


-- ============================================================
-- 11. SEGMENT REVENUE CONCENTRATION
-- ============================================================

WITH CustomerBehavior AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY o.customer_id
),
ScoredCustomers AS
(
    SELECT
        customer_id,
        order_count,
        total_revenue,
        NTILE(4) OVER (ORDER BY total_revenue) AS revenue_quartile
    FROM CustomerBehavior
)
SELECT
    revenue_quartile,
    COUNT(*) AS customer_count,
    CAST(SUM(total_revenue) AS DECIMAL(18,2)) AS total_revenue,
    CAST(
        SUM(total_revenue) * 100.0
        / NULLIF(SUM(SUM(total_revenue)) OVER (), 0)
        AS DECIMAL(10,2)
    ) AS revenue_share_pct
FROM ScoredCustomers
GROUP BY revenue_quartile
ORDER BY revenue_quartile DESC;


-- ============================================================
-- 12. TOP VALUE CUSTOMERS
-- Customers in the highest revenue quartile
-- ============================================================

WITH CustomerRevenue AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_purchased,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY o.customer_id
),
RevenueQuartiles AS
(
    SELECT
        customer_id,
        order_count,
        units_purchased,
        total_revenue,
        NTILE(4) OVER (
            ORDER BY total_revenue
        ) AS revenue_quartile
    FROM CustomerRevenue
)
SELECT
    customer_id,
    order_count,
    units_purchased,
    total_revenue
FROM RevenueQuartiles
WHERE revenue_quartile = 4
ORDER BY total_revenue DESC;


-- ============================================================
-- 13. SEGMENT SUMMARY WITH AVERAGE ORDER VALUE
-- ============================================================

WITH CustomerBehavior AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY o.customer_id
),
ScoredCustomers AS
(
    SELECT
        customer_id,
        order_count,
        total_revenue,
        NTILE(4) OVER (ORDER BY order_count) AS frequency_quartile,
        NTILE(4) OVER (ORDER BY total_revenue) AS revenue_quartile
    FROM CustomerBehavior
),
SegmentedCustomers AS
(
    SELECT
        customer_id,
        order_count,
        total_revenue,
        CASE
            WHEN frequency_quartile = 4
             AND revenue_quartile = 4
                THEN 'High Frequency / High Value'
            WHEN frequency_quartile = 4
             AND revenue_quartile <= 2
                THEN 'High Frequency / Lower Value'
            WHEN frequency_quartile <= 2
             AND revenue_quartile = 4
                THEN 'Low Frequency / High Value'
            ELSE 'Mid Value'
        END AS customer_segment
    FROM ScoredCustomers
)
SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    SUM(order_count) AS order_count,
    CAST(SUM(total_revenue) AS DECIMAL(18,2)) AS total_revenue,
    CAST(
        SUM(total_revenue)
        / NULLIF(SUM(CAST(order_count AS DECIMAL(18,2))), 0)
        AS DECIMAL(18,2)
    ) AS segment_aov
FROM SegmentedCustomers
GROUP BY customer_segment
ORDER BY total_revenue DESC;


-- ============================================================
-- 14. SEGMENTATION BASELINE RECONCILIATION
-- All purchasing customers must belong to exactly one segment
-- Expected purchasing customers = 262
-- Expected revenue = 291331.00
-- ============================================================

WITH CustomerBehavior AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY o.customer_id
),
ScoredCustomers AS
(
    SELECT
        customer_id,
        order_count,
        total_revenue,
        NTILE(4) OVER (ORDER BY order_count) AS frequency_quartile,
        NTILE(4) OVER (ORDER BY total_revenue) AS revenue_quartile
    FROM CustomerBehavior
),
SegmentedCustomers AS
(
    SELECT
        customer_id,
        total_revenue,
        CASE
            WHEN frequency_quartile = 4
             AND revenue_quartile = 4
                THEN 'High Frequency / High Value'
            WHEN frequency_quartile = 4
             AND revenue_quartile <= 2
                THEN 'High Frequency / Lower Value'
            WHEN frequency_quartile <= 2
             AND revenue_quartile = 4
                THEN 'Low Frequency / High Value'
            ELSE 'Mid Value'
        END AS customer_segment
    FROM ScoredCustomers
)
SELECT
    COUNT(*) AS segmented_customers,
    COUNT(DISTINCT customer_segment) AS segment_count,
    CAST(SUM(total_revenue) AS DECIMAL(18,2)) AS segmented_revenue,
    CASE
        WHEN COUNT(*) = 262
         AND CAST(SUM(total_revenue) AS DECIMAL(18,2)) = 291331.00
         AND COUNT(DISTINCT customer_segment) = 4
        THEN 'PASS'
        ELSE 'CHECK'
    END AS validation_status
FROM SegmentedCustomers;


-- ============================================================
-- 02_customer_analysis.sql
-- E-Commerce Customer & Sales Analytics
-- SQL Server / T-SQL
-- Customer-level sales and purchasing behavior analysis
-- ============================================================

-- ============================================================
-- 1. CUSTOMER SALES SUMMARY
-- One row per customer with at least one valid completed order
-- ============================================================
WITH CustomerSales AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_purchased,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2)) *
            CAST(oi.price AS DECIMAL(18,2))
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
    units_purchased,
    total_revenue,
    CAST(
        total_revenue / NULLIF(CAST(order_count AS DECIMAL(18,2)), 0)
        AS DECIMAL(18,2)
    ) AS average_order_value
FROM CustomerSales
ORDER BY total_revenue DESC;


-- ============================================================
-- 2. PURCHASING VS NON-PURCHASING CUSTOMERS
-- ============================================================
WITH PurchasingCustomers AS
(
    SELECT DISTINCT o.customer_id
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
)
SELECT
    CASE
        WHEN pc.customer_id IS NOT NULL THEN 'Purchasing'
        ELSE 'Non-Purchasing'
    END AS customer_type,
    COUNT(*) AS customer_count
FROM customers AS c
LEFT JOIN PurchasingCustomers AS pc
    ON c.customer_id = pc.customer_id
GROUP BY
    CASE
        WHEN pc.customer_id IS NOT NULL THEN 'Purchasing'
        ELSE 'Non-Purchasing'
    END
ORDER BY customer_type;


-- ============================================================
-- 3. PURCHASING CUSTOMER RATE
-- ============================================================
WITH PurchasingCustomers AS
(
    SELECT DISTINCT o.customer_id
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
)
SELECT
    COUNT(*) AS total_customers,
    COUNT(pc.customer_id) AS purchasing_customers,
    COUNT(*) - COUNT(pc.customer_id) AS non_purchasing_customers,
    CAST(
        COUNT(pc.customer_id) * 100.0 / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS purchasing_customer_rate_pct
FROM customers AS c
LEFT JOIN PurchasingCustomers AS pc
    ON c.customer_id = pc.customer_id;


-- ============================================================
-- 4. CUSTOMER PURCHASE FREQUENCY
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
)
SELECT
    order_count,
    COUNT(*) AS customer_count
FROM CustomerFrequency
GROUP BY order_count
ORDER BY order_count;


-- ============================================================
-- 5. ONE-TIME VS REPEAT CUSTOMERS
-- Repeat customer = at least 2 valid completed orders
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
)
SELECT
    CASE
        WHEN order_count >= 2 THEN 'Repeat Customer'
        ELSE 'One-Time Customer'
    END AS customer_type,
    COUNT(*) AS customer_count
FROM CustomerFrequency
GROUP BY
    CASE
        WHEN order_count >= 2 THEN 'Repeat Customer'
        ELSE 'One-Time Customer'
    END
ORDER BY customer_type;


-- ============================================================
-- 6. REPEAT PURCHASE RATE
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
)
SELECT
    COUNT(*) AS valid_customers,
    SUM(CASE WHEN order_count >= 2 THEN 1 ELSE 0 END) AS repeat_customers,
    SUM(CASE WHEN order_count = 1 THEN 1 ELSE 0 END) AS one_time_customers,
    CAST(
        SUM(CASE WHEN order_count >= 2 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(10,2)
    ) AS repeat_purchase_rate_pct
FROM CustomerFrequency;


-- ============================================================
-- 7. CUSTOMER REVENUE AND REVENUE SHARE
-- ============================================================
WITH CustomerSales AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_purchased,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2)) *
            CAST(oi.price AS DECIMAL(18,2))
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
    units_purchased,
    CAST(total_revenue AS DECIMAL(18,2)) AS total_revenue,
    CAST(
        total_revenue * 100.0 /
        NULLIF(SUM(total_revenue) OVER (), 0)
        AS DECIMAL(10,2)
    ) AS revenue_share_pct
FROM CustomerSales
ORDER BY total_revenue DESC;


-- ============================================================
-- 8. CUSTOMER REVENUE RANKING
-- Demonstrates RANK and DENSE_RANK
-- ============================================================
WITH CustomerSales AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_purchased,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2)) *
            CAST(oi.price AS DECIMAL(18,2))
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
    units_purchased,
    CAST(total_revenue AS DECIMAL(18,2)) AS total_revenue,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
    DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS dense_revenue_rank
FROM CustomerSales
ORDER BY revenue_rank, customer_id;


-- ============================================================
-- 9. TOP 10 CUSTOMERS BY REVENUE
-- ============================================================
WITH CustomerSales AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_purchased,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2)) *
            CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY o.customer_id
), RankedCustomers AS
(
    SELECT
        customer_id,
        order_count,
        units_purchased,
        total_revenue,
        ROW_NUMBER() OVER (
            ORDER BY total_revenue DESC, customer_id
        ) AS row_num
    FROM CustomerSales
)
SELECT
    customer_id,
    order_count,
    units_purchased,
    CAST(total_revenue AS DECIMAL(18,2)) AS total_revenue
FROM RankedCustomers
WHERE row_num <= 10
ORDER BY row_num;


-- ============================================================
-- 10. CUSTOMER AVERAGE ORDER VALUE
-- ============================================================
WITH CustomerSales AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2)) *
            CAST(oi.price AS DECIMAL(18,2))
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
    CAST(total_revenue AS DECIMAL(18,2)) AS total_revenue,
    CAST(
        total_revenue / NULLIF(CAST(order_count AS DECIMAL(18,2)), 0)
        AS DECIMAL(18,2)
    ) AS average_order_value
FROM CustomerSales
ORDER BY average_order_value DESC;


-- ============================================================
-- 11. CUSTOMER REVENUE DISTRIBUTION
-- ============================================================
WITH CustomerSales AS
(
    SELECT
        o.customer_id,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2)) *
            CAST(oi.price AS DECIMAL(18,2))
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
        WHEN total_revenue < 500 THEN 'Under 500'
        WHEN total_revenue < 1000 THEN '500 - 999'
        WHEN total_revenue < 2000 THEN '1000 - 1999'
        WHEN total_revenue < 5000 THEN '2000 - 4999'
        ELSE '5000+'
    END AS revenue_band,
    COUNT(*) AS customer_count,
    CAST(SUM(total_revenue) AS DECIMAL(18,2)) AS band_revenue
FROM CustomerSales
GROUP BY
    CASE
        WHEN total_revenue < 500 THEN 'Under 500'
        WHEN total_revenue < 1000 THEN '500 - 999'
        WHEN total_revenue < 2000 THEN '1000 - 1999'
        WHEN total_revenue < 5000 THEN '2000 - 4999'
        ELSE '5000+'
    END
ORDER BY MIN(total_revenue);


-- ============================================================
-- 12. VALID ORDER VALUE DISTRIBUTION
-- ============================================================
WITH ValidOrders AS
(
    SELECT
        o.order_id,
        o.customer_id,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2)) *
            CAST(oi.price AS DECIMAL(18,2))
        ) AS order_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY o.order_id, o.customer_id
)
SELECT
    CASE
        WHEN order_revenue < 250 THEN 'Under 250'
        WHEN order_revenue < 500 THEN '250 - 499'
        WHEN order_revenue < 1000 THEN '500 - 999'
        WHEN order_revenue < 2000 THEN '1000 - 1999'
        ELSE '2000+'
    END AS order_value_band,
    COUNT(*) AS order_count,
    CAST(SUM(order_revenue) AS DECIMAL(18,2)) AS band_revenue
FROM ValidOrders
GROUP BY
    CASE
        WHEN order_revenue < 250 THEN 'Under 250'
        WHEN order_revenue < 500 THEN '250 - 499'
        WHEN order_revenue < 1000 THEN '500 - 999'
        WHEN order_revenue < 2000 THEN '1000 - 1999'
        ELSE '2000+'
    END
ORDER BY MIN(order_revenue);


-- ============================================================
-- 13. CUSTOMER DETAILS + REVENUE RANK
-- ============================================================
WITH CustomerSales AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_purchased,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2)) *
            CAST(oi.price AS DECIMAL(18,2))
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
    cs.customer_id,
    c.country,
    c.signup_date,
    cs.order_count,
    cs.units_purchased,
    CAST(cs.total_revenue AS DECIMAL(18,2)) AS total_revenue,
    RANK() OVER (ORDER BY cs.total_revenue DESC) AS revenue_rank
FROM CustomerSales AS cs
INNER JOIN customers AS c
    ON cs.customer_id = c.customer_id
ORDER BY revenue_rank, cs.customer_id;


-- ============================================================
-- 14. REPEAT CUSTOMER REVENUE SHARE
-- ============================================================
WITH CustomerSales AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2)) *
            CAST(oi.price AS DECIMAL(18,2))
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
    CAST(
        SUM(CASE WHEN order_count >= 2 THEN total_revenue ELSE 0 END)
        AS DECIMAL(18,2)
    ) AS repeat_customer_revenue,
    CAST(
        SUM(CASE WHEN order_count = 1 THEN total_revenue ELSE 0 END)
        AS DECIMAL(18,2)
    ) AS one_time_customer_revenue,
    CAST(
        SUM(CASE WHEN order_count >= 2 THEN total_revenue ELSE 0 END) * 100.0
        / NULLIF(SUM(total_revenue), 0)
        AS DECIMAL(10,2)
    ) AS repeat_customer_revenue_share_pct
FROM CustomerSales;


-- ============================================================
-- 15. CUSTOMER ORDER SHARE
-- ============================================================
WITH CustomerOrders AS
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
)
SELECT
    customer_id,
    order_count,
    CAST(
        order_count * 100.0 /
        NULLIF(SUM(order_count) OVER (), 0)
        AS DECIMAL(10,2)
    ) AS order_share_pct
FROM CustomerOrders
ORDER BY order_count DESC, customer_id;


-- ============================================================
-- 16. CUSTOMER REVENUE CONTRIBUTION + CUMULATIVE SHARE
-- ============================================================
WITH CustomerSales AS
(
    SELECT
        o.customer_id,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2)) *
            CAST(oi.price AS DECIMAL(18,2))
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
    CAST(total_revenue AS DECIMAL(18,2)) AS total_revenue,
    CAST(
        total_revenue * 100.0 /
        NULLIF(SUM(total_revenue) OVER (), 0)
        AS DECIMAL(10,2)
    ) AS revenue_share_pct,
    CAST(
        SUM(total_revenue) OVER
        (
            ORDER BY total_revenue DESC, customer_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) * 100.0 /
        NULLIF(SUM(total_revenue) OVER (), 0)
        AS DECIMAL(10,2)
    ) AS cumulative_revenue_share_pct
FROM CustomerSales
ORDER BY total_revenue DESC, customer_id;


-- ============================================================
-- 17. FINAL CUSTOMER ANALYSIS BASELINE RECONCILIATION
-- Expected:
-- Valid Customers = 262
-- Valid Sales Orders = 656
-- Valid Revenue = 291331.00
-- Valid Units = 4536
-- ============================================================
WITH CustomerSales AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_purchased,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2)) *
            CAST(oi.price AS DECIMAL(18,2))
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
    COUNT(*) AS valid_customers,
    SUM(order_count) AS valid_sales_orders,
    CAST(SUM(total_revenue) AS DECIMAL(18,2)) AS valid_revenue,
    CAST(SUM(units_purchased) AS DECIMAL(18,2)) AS valid_units,
    CASE
        WHEN COUNT(*) = 262
         AND SUM(order_count) = 656
         AND CAST(SUM(total_revenue) AS DECIMAL(18,2)) = 291331.00
         AND CAST(SUM(units_purchased) AS DECIMAL(18,2)) = 4536.00
        THEN 'PASS'
        ELSE 'CHECK'
    END AS validation_status
FROM CustomerSales;


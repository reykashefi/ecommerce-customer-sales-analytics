-- 
-- ===============================================================================
-- E-COMMERCE CUSTOMER & SALES ANALYTICS
-- File: 01_sales_analysis.sql
-- Purpose: Sales performance analysis
-- Platform: Microsoft SQL Server / T-SQL
-- 
-- Analytical rule for Valid Sales:
-- 1. Order status = Completed
-- 2. Order date >= Customer signup date
-- 3. Order has at least one order item
-- 
-- Revenue = Quantity * Price
-- 
-- Official baseline:
-- - Valid Sales Orders: 656
-- - Valid Customers: 262
-- - Valid Revenue: 291331.00
-- - Valid Units: 4536
-- 
-- Source tables:
-- - customers
-- - orders
-- - order_items
-- - products
-- ===============================================================================

--  ============================================================================
-- 1. VALID SALES BASELINE
-- ============================================================================ 

SELECT
    COUNT(DISTINCT o.order_id) AS valid_sales_orders,
    COUNT(DISTINCT o.customer_id) AS valid_customers,
    SUM(CAST(oi.quantity AS DECIMAL(18,2)) * CAST(oi.price AS DECIMAL(18,2))) AS valid_revenue,
    SUM(CAST(oi.quantity AS INT)) AS valid_units
FROM orders AS o
INNER JOIN customers AS c
    ON o.customer_id = c.customer_id
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.status = 'Completed'
  AND o.order_date >= c.signup_date;


--  ============================================================================
-- 2. CORE SALES KPIs
-- ============================================================================ 

WITH ValidOrderValues AS
(
    SELECT
        o.order_id,
        o.customer_id,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS order_revenue,
        SUM(CAST(oi.quantity AS INT)) AS order_units
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY
        o.order_id,
        o.customer_id
)
SELECT
    COUNT(*) AS valid_sales_orders,
    COUNT(DISTINCT customer_id) AS valid_customers,
    SUM(order_revenue) AS total_revenue,
    SUM(order_units) AS total_units,
    CAST(SUM(order_revenue) / NULLIF(COUNT(*), 0) AS DECIMAL(18,2)) AS average_order_value,
    CAST(SUM(order_revenue) / NULLIF(COUNT(DISTINCT customer_id), 0) AS DECIMAL(18,2)) AS average_revenue_per_customer
FROM ValidOrderValues;


--  ============================================================================
-- 3. REVENUE, ORDERS AND UNITS BY YEAR
-- ============================================================================ 

SELECT
    YEAR(o.order_date) AS sales_year,
    COUNT(DISTINCT o.order_id) AS valid_sales_orders,
    COUNT(DISTINCT o.customer_id) AS purchasing_customers,
    SUM(CAST(oi.quantity AS INT)) AS units_sold,
    SUM(
        CAST(oi.quantity AS DECIMAL(18,2))
        * CAST(oi.price AS DECIMAL(18,2))
    ) AS revenue
FROM orders AS o
INNER JOIN customers AS c
    ON o.customer_id = c.customer_id
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.status = 'Completed'
  AND o.order_date >= c.signup_date
GROUP BY YEAR(o.order_date)
ORDER BY sales_year;


--  ============================================================================
-- 4. MONTHLY SALES PERFORMANCE
-- ============================================================================ 

SELECT
    YEAR(o.order_date) AS sales_year,
    MONTH(o.order_date) AS sales_month,
    COUNT(DISTINCT o.order_id) AS valid_sales_orders,
    COUNT(DISTINCT o.customer_id) AS purchasing_customers,
    SUM(CAST(oi.quantity AS INT)) AS units_sold,
    SUM(
        CAST(oi.quantity AS DECIMAL(18,2))
        * CAST(oi.price AS DECIMAL(18,2))
    ) AS revenue
FROM orders AS o
INNER JOIN customers AS c
    ON o.customer_id = c.customer_id
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.status = 'Completed'
  AND o.order_date >= c.signup_date
GROUP BY
    YEAR(o.order_date),
    MONTH(o.order_date)
ORDER BY
    sales_year,
    sales_month;


--  ============================================================================
-- 5. MONTHLY REVENUE SHARE
-- ============================================================================ 

WITH MonthlySales AS
(
    SELECT
        YEAR(o.order_date) AS sales_year,
        MONTH(o.order_date) AS sales_month,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY
        YEAR(o.order_date),
        MONTH(o.order_date)
)
SELECT
    sales_year,
    sales_month,
    revenue,
    CAST(
        revenue / NULLIF(SUM(revenue) OVER (), 0) * 100
        AS DECIMAL(10,2)
    ) AS revenue_share_pct
FROM MonthlySales
ORDER BY
    sales_year,
    sales_month;


--  ============================================================================
-- 6. MONTHLY REVENUE WITH MOM GROWTH
-- ============================================================================ 

WITH MonthlySales AS
(
    SELECT
        DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1) AS sales_month,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1)
),
RevenueWithPreviousMonth AS
(
    SELECT
        sales_month,
        revenue,
        LAG(revenue) OVER (ORDER BY sales_month) AS previous_month_revenue
    FROM MonthlySales
)
SELECT
    sales_month,
    revenue,
    previous_month_revenue,
    CAST(
        (revenue - previous_month_revenue)
        / NULLIF(previous_month_revenue, 0) * 100
        AS DECIMAL(10,2)
    ) AS mom_revenue_growth_pct
FROM RevenueWithPreviousMonth
ORDER BY sales_month;


--  ============================================================================
-- 7. TOP 10 MONTHS BY REVENUE
-- ============================================================================ 

SELECT TOP (10)
    DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1) AS sales_month,
    SUM(
        CAST(oi.quantity AS DECIMAL(18,2))
        * CAST(oi.price AS DECIMAL(18,2))
    ) AS revenue,
    COUNT(DISTINCT o.order_id) AS valid_sales_orders,
    SUM(CAST(oi.quantity AS INT)) AS units_sold
FROM orders AS o
INNER JOIN customers AS c
    ON o.customer_id = c.customer_id
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.status = 'Completed'
  AND o.order_date >= c.signup_date
GROUP BY DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1)
ORDER BY revenue DESC;


--  ============================================================================
-- 8. CATEGORY SALES PERFORMANCE
-- ============================================================================ 

SELECT
    p.category,
    COUNT(DISTINCT o.order_id) AS valid_sales_orders,
    COUNT(DISTINCT o.customer_id) AS purchasing_customers,
    SUM(CAST(oi.quantity AS INT)) AS units_sold,
    SUM(
        CAST(oi.quantity AS DECIMAL(18,2))
        * CAST(oi.price AS DECIMAL(18,2))
    ) AS revenue
FROM orders AS o
INNER JOIN customers AS c
    ON o.customer_id = c.customer_id
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
INNER JOIN products AS p
    ON oi.product_id = p.product_id
WHERE o.status = 'Completed'
  AND o.order_date >= c.signup_date
GROUP BY p.category
ORDER BY revenue DESC;


--  ============================================================================
-- 9. CATEGORY REVENUE SHARE
-- ============================================================================ 

WITH CategorySales AS
(
    SELECT
        p.category,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS revenue,
        SUM(CAST(oi.quantity AS INT)) AS units_sold
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    INNER JOIN products AS p
        ON oi.product_id = p.product_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY p.category
)
SELECT
    category,
    revenue,
    units_sold,
    CAST(
        revenue / NULLIF(SUM(revenue) OVER (), 0) * 100
        AS DECIMAL(10,2)
    ) AS revenue_share_pct
FROM CategorySales
ORDER BY revenue DESC;


--  ============================================================================
-- 10. PRODUCT SALES PERFORMANCE
-- ============================================================================ 

SELECT
    p.product_id,
    p.product_name,
    p.category,
    COUNT(DISTINCT o.order_id) AS valid_sales_orders,
    COUNT(DISTINCT o.customer_id) AS purchasing_customers,
    SUM(CAST(oi.quantity AS INT)) AS units_sold,
    SUM(
        CAST(oi.quantity AS DECIMAL(18,2))
        * CAST(oi.price AS DECIMAL(18,2))
    ) AS revenue
FROM orders AS o
INNER JOIN customers AS c
    ON o.customer_id = c.customer_id
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
INNER JOIN products AS p
    ON oi.product_id = p.product_id
WHERE o.status = 'Completed'
  AND o.order_date >= c.signup_date
GROUP BY
    p.product_id,
    p.product_name,
    p.category
ORDER BY revenue DESC;


--  ============================================================================
-- 11. TOP 10 PRODUCTS BY REVENUE
-- ============================================================================ 

SELECT TOP (10)
    p.product_id,
    p.product_name,
    p.category,
    SUM(CAST(oi.quantity AS INT)) AS units_sold,
    SUM(
        CAST(oi.quantity AS DECIMAL(18,2))
        * CAST(oi.price AS DECIMAL(18,2))
    ) AS revenue
FROM orders AS o
INNER JOIN customers AS c
    ON o.customer_id = c.customer_id
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
INNER JOIN products AS p
    ON oi.product_id = p.product_id
WHERE o.status = 'Completed'
  AND o.order_date >= c.signup_date
GROUP BY
    p.product_id,
    p.product_name,
    p.category
ORDER BY revenue DESC;


--  ============================================================================
-- 12. PRODUCT REVENUE SHARE AND RANK
-- ============================================================================ 

WITH ProductSales AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(CAST(oi.quantity AS INT)) AS units_sold,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    INNER JOIN products AS p
        ON oi.product_id = p.product_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY
        p.product_id,
        p.product_name,
        p.category
)
SELECT
    product_id,
    product_name,
    category,
    units_sold,
    revenue,
    CAST(
        revenue / NULLIF(SUM(revenue) OVER (), 0) * 100
        AS DECIMAL(10,2)
    ) AS revenue_share_pct,
    RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM ProductSales
ORDER BY revenue_rank, product_id;


--  ============================================================================
-- 13. HIGH-VOLUME / LOW-REVENUE PRODUCTS
-- ============================================================================ 

WITH ProductSales AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(CAST(oi.quantity AS INT)) AS units_sold,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    INNER JOIN products AS p
        ON oi.product_id = p.product_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY
        p.product_id,
        p.product_name,
        p.category
),
ProductThresholds AS
(
    SELECT
        AVG(CAST(units_sold AS DECIMAL(18,2))) AS avg_units_sold,
        AVG(revenue) AS avg_revenue
    FROM ProductSales
)
SELECT
    ps.product_id,
    ps.product_name,
    ps.category,
    ps.units_sold,
    ps.revenue,
    CAST(ps.units_sold / NULLIF(pt.avg_units_sold, 0) AS DECIMAL(10,2)) AS units_vs_avg,
    CAST(ps.revenue / NULLIF(pt.avg_revenue, 0) AS DECIMAL(10,2)) AS revenue_vs_avg
FROM ProductSales AS ps
CROSS JOIN ProductThresholds AS pt
WHERE ps.units_sold > pt.avg_units_sold
  AND ps.revenue < pt.avg_revenue
ORDER BY ps.units_sold DESC;


--  ============================================================================
-- 14. HIGH-REVENUE / LOW-VOLUME PRODUCTS
-- ============================================================================ 

WITH ProductSales AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(CAST(oi.quantity AS INT)) AS units_sold,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    INNER JOIN products AS p
        ON oi.product_id = p.product_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY
        p.product_id,
        p.product_name,
        p.category
),
ProductThresholds AS
(
    SELECT
        AVG(CAST(units_sold AS DECIMAL(18,2))) AS avg_units_sold,
        AVG(revenue) AS avg_revenue
    FROM ProductSales
)
SELECT
    ps.product_id,
    ps.product_name,
    ps.category,
    ps.units_sold,
    ps.revenue,
    CAST(ps.units_sold / NULLIF(pt.avg_units_sold, 0) AS DECIMAL(10,2)) AS units_vs_avg,
    CAST(ps.revenue / NULLIF(pt.avg_revenue, 0) AS DECIMAL(10,2)) AS revenue_vs_avg
FROM ProductSales AS ps
CROSS JOIN ProductThresholds AS pt
WHERE ps.units_sold < pt.avg_units_sold
  AND ps.revenue > pt.avg_revenue
ORDER BY ps.revenue DESC;


--  ============================================================================
-- 15. CUSTOMER SALES SUMMARY
-- ============================================================================ 

WITH CustomerSales AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS valid_sales_orders,
        SUM(CAST(oi.quantity AS INT)) AS units_purchased,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS revenue
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
    cs.valid_sales_orders,
    cs.units_purchased,
    cs.revenue,
    CAST(
        cs.revenue / NULLIF(cs.valid_sales_orders, 0)
        AS DECIMAL(18,2)
    ) AS customer_aov
FROM CustomerSales AS cs
INNER JOIN customers AS c
    ON cs.customer_id = c.customer_id
ORDER BY cs.revenue DESC;


--  ============================================================================
-- 16. TOP 10 CUSTOMERS BY REVENUE
-- ============================================================================ 

WITH CustomerSales AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS valid_sales_orders,
        SUM(CAST(oi.quantity AS INT)) AS units_purchased,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY o.customer_id
)
SELECT TOP (10)
    cs.customer_id,
    c.country,
    cs.valid_sales_orders,
    cs.units_purchased,
    cs.revenue
FROM CustomerSales AS cs
INNER JOIN customers AS c
    ON cs.customer_id = c.customer_id
ORDER BY cs.revenue DESC;


--  ============================================================================
-- 17. CUSTOMER REVENUE DISTRIBUTION
-- ============================================================================ 

WITH CustomerSales AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS valid_sales_orders,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS revenue
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
        WHEN revenue < 500 THEN 'Under 500'
        WHEN revenue < 1000 THEN '500 - 999'
        WHEN revenue < 1500 THEN '1000 - 1499'
        WHEN revenue < 2000 THEN '1500 - 1999'
        ELSE '2000+'
    END AS revenue_bucket,
    COUNT(*) AS customer_count,
    SUM(revenue) AS total_revenue
FROM CustomerSales
GROUP BY
    CASE
        WHEN revenue < 500 THEN 'Under 500'
        WHEN revenue < 1000 THEN '500 - 999'
        WHEN revenue < 1500 THEN '1000 - 1499'
        WHEN revenue < 2000 THEN '1500 - 1999'
        ELSE '2000+'
    END
ORDER BY
    MIN(revenue);


--  ============================================================================
-- 18. REPEAT CUSTOMER REVENUE SHARE
-- ============================================================================ 

WITH CustomerSales AS
(
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS valid_sales_orders,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS revenue
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
    COUNT(*) AS purchasing_customers,
    SUM(CASE WHEN valid_sales_orders >= 2 THEN 1 ELSE 0 END) AS repeat_customers,
    SUM(revenue) AS total_revenue,
    SUM(CASE WHEN valid_sales_orders >= 2 THEN revenue ELSE 0 END) AS repeat_customer_revenue,
    CAST(
        SUM(CASE WHEN valid_sales_orders >= 2 THEN revenue ELSE 0 END)
        / NULLIF(SUM(revenue), 0) * 100
        AS DECIMAL(10,2)
    ) AS repeat_customer_revenue_share_pct
FROM CustomerSales;


--  ============================================================================
-- 19. AOV BY YEAR
-- ============================================================================ 

WITH ValidOrderValues AS
(
    SELECT
        YEAR(o.order_date) AS sales_year,
        o.order_id,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS order_revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY
        YEAR(o.order_date),
        o.order_id
)
SELECT
    sales_year,
    COUNT(*) AS valid_sales_orders,
    SUM(order_revenue) AS revenue,
    CAST(AVG(order_revenue) AS DECIMAL(18,2)) AS average_order_value
FROM ValidOrderValues
GROUP BY sales_year
ORDER BY sales_year;


--  ============================================================================
-- 20. SALES CONTRIBUTION BY YEAR
-- ============================================================================ 

WITH YearlySales AS
(
    SELECT
        YEAR(o.order_date) AS sales_year,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS revenue
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY YEAR(o.order_date)
)
SELECT
    sales_year,
    revenue,
    CAST(
        revenue / NULLIF(SUM(revenue) OVER (), 0) * 100
        AS DECIMAL(10,2)
    ) AS revenue_share_pct
FROM YearlySales
ORDER BY sales_year;


--  ============================================================================
-- 21. SALES ANALYSIS RECONCILIATION CHECK
-- ============================================================================ 

SELECT
    COUNT(DISTINCT o.order_id) AS valid_sales_orders,
    COUNT(DISTINCT o.customer_id) AS valid_customers,
    SUM(
        CAST(oi.quantity AS DECIMAL(18,2))
        * CAST(oi.price AS DECIMAL(18,2))
    ) AS valid_revenue,
    SUM(CAST(oi.quantity AS INT)) AS valid_units,
    CASE
        WHEN COUNT(DISTINCT o.order_id) = 656
         AND COUNT(DISTINCT o.customer_id) = 262
         AND SUM(
                CAST(oi.quantity AS DECIMAL(18,2))
                * CAST(oi.price AS DECIMAL(18,2))
             ) = 291331.00
         AND SUM(CAST(oi.quantity AS INT)) = 4536
        THEN 'PASS'
        ELSE 'CHECK'
    END AS baseline_status
FROM orders AS o
INNER JOIN customers AS c
    ON o.customer_id = c.customer_id
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.status = 'Completed'
  AND o.order_date >= c.signup_date;


--  ============================================================================
-- END OF FILE
-- ============================================================================ 


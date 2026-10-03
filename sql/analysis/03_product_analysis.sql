-- ============================================================
-- 03_product_analysis.sql
-- E-Commerce Customer & Sales Analytics
-- SQL Server / T-SQL
-- Purpose: Product and category sales performance analysis
-- ============================================================

-- ============================================================
-- 1. PRODUCT SALES SUMMARY
-- One row per product with valid completed sales
-- ============================================================

WITH ProductSales AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_sold,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM products AS p
    INNER JOIN order_items AS oi
        ON p.product_id = oi.product_id
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
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
    order_count,
    units_sold,
    total_revenue,
    CAST(
        total_revenue / NULLIF(CAST(order_count AS DECIMAL(18,2)), 0)
        AS DECIMAL(18,2)
    ) AS average_order_value
FROM ProductSales
ORDER BY total_revenue DESC;


-- ============================================================
-- 2. TOP 10 PRODUCTS BY REVENUE
-- ============================================================

WITH ProductSales AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM products AS p
    INNER JOIN order_items AS oi
        ON p.product_id = oi.product_id
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY
        p.product_id,
        p.product_name,
        p.category
),
RankedProducts AS
(
    SELECT
        product_id,
        product_name,
        category,
        total_revenue,
        ROW_NUMBER() OVER (
            ORDER BY total_revenue DESC, product_id
        ) AS row_num
    FROM ProductSales
)
SELECT
    product_id,
    product_name,
    category,
    total_revenue
FROM RankedProducts
WHERE row_num <= 10
ORDER BY row_num;


-- ============================================================
-- 3. TOP 10 PRODUCTS BY UNITS SOLD
-- ============================================================

WITH ProductSales AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_sold
    FROM products AS p
    INNER JOIN order_items AS oi
        ON p.product_id = oi.product_id
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY
        p.product_id,
        p.product_name,
        p.category
)
SELECT TOP (10)
    product_id,
    product_name,
    category,
    units_sold
FROM ProductSales
ORDER BY units_sold DESC, product_id;


-- ============================================================
-- 4. PRODUCT REVENUE SHARE
-- ============================================================

WITH ProductSales AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM products AS p
    INNER JOIN order_items AS oi
        ON p.product_id = oi.product_id
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
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
    CAST(total_revenue AS DECIMAL(18,2)) AS total_revenue,
    CAST(
        total_revenue * 100.0
        / NULLIF(SUM(total_revenue) OVER (), 0)
        AS DECIMAL(10,2)
    ) AS revenue_share_pct
FROM ProductSales
ORDER BY total_revenue DESC, product_id;


-- ============================================================
-- 5. PRODUCT REVENUE RANKING
-- Demonstrates RANK and DENSE_RANK
-- ============================================================

WITH ProductSales AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM products AS p
    INNER JOIN order_items AS oi
        ON p.product_id = oi.product_id
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
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
    total_revenue,
    RANK() OVER (
        ORDER BY total_revenue DESC
    ) AS revenue_rank,
    DENSE_RANK() OVER (
        ORDER BY total_revenue DESC
    ) AS dense_revenue_rank
FROM ProductSales
ORDER BY revenue_rank, product_id;


-- ============================================================
-- 6. CATEGORY PERFORMANCE
-- ============================================================

WITH CategorySales AS
(
    SELECT
        p.category,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_sold,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM products AS p
    INNER JOIN order_items AS oi
        ON p.product_id = oi.product_id
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY
        p.category
)
SELECT
    category,
    order_count,
    units_sold,
    total_revenue,
    CAST(
        total_revenue / NULLIF(CAST(order_count AS DECIMAL(18,2)), 0)
        AS DECIMAL(18,2)
    ) AS average_order_value
FROM CategorySales
ORDER BY total_revenue DESC;


-- ============================================================
-- 7. CATEGORY REVENUE SHARE
-- ============================================================

WITH CategorySales AS
(
    SELECT
        p.category,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM products AS p
    INNER JOIN order_items AS oi
        ON p.product_id = oi.product_id
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY
        p.category
)
SELECT
    category,
    CAST(total_revenue AS DECIMAL(18,2)) AS total_revenue,
    CAST(
        total_revenue * 100.0
        / NULLIF(SUM(total_revenue) OVER (), 0)
        AS DECIMAL(10,2)
    ) AS revenue_share_pct
FROM CategorySales
ORDER BY total_revenue DESC;


-- ============================================================
-- 8. CATEGORY RANKING
-- ============================================================

WITH CategorySales AS
(
    SELECT
        p.category,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_sold
    FROM products AS p
    INNER JOIN order_items AS oi
        ON p.product_id = oi.product_id
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY
        p.category
)
SELECT
    category,
    units_sold,
    total_revenue,
    RANK() OVER (
        ORDER BY total_revenue DESC
    ) AS revenue_rank
FROM CategorySales
ORDER BY revenue_rank, category;


-- ============================================================
-- 9. HIGH-VOLUME / LOW-REVENUE PRODUCTS
-- Products with above-average units but below-average revenue
-- ============================================================

WITH ProductSales AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_sold,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM products AS p
    INNER JOIN order_items AS oi
        ON p.product_id = oi.product_id
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY
        p.product_id,
        p.product_name,
        p.category
),
ProductAverages AS
(
    SELECT
        AVG(units_sold) AS avg_units,
        AVG(total_revenue) AS avg_revenue
    FROM ProductSales
)
SELECT
    ps.product_id,
    ps.product_name,
    ps.category,
    ps.units_sold,
    ps.total_revenue
FROM ProductSales AS ps
CROSS JOIN ProductAverages AS pa
WHERE ps.units_sold > pa.avg_units
  AND ps.total_revenue < pa.avg_revenue
ORDER BY ps.units_sold DESC, ps.total_revenue ASC;


-- ============================================================
-- 10. HIGH-REVENUE / LOW-VOLUME PRODUCTS
-- Products with above-average revenue but below-average units
-- ============================================================

WITH ProductSales AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_sold,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM products AS p
    INNER JOIN order_items AS oi
        ON p.product_id = oi.product_id
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY
        p.product_id,
        p.product_name,
        p.category
),
ProductAverages AS
(
    SELECT
        AVG(units_sold) AS avg_units,
        AVG(total_revenue) AS avg_revenue
    FROM ProductSales
)
SELECT
    ps.product_id,
    ps.product_name,
    ps.category,
    ps.units_sold,
    ps.total_revenue
FROM ProductSales AS ps
CROSS JOIN ProductAverages AS pa
WHERE ps.units_sold < pa.avg_units
  AND ps.total_revenue > pa.avg_revenue
ORDER BY ps.total_revenue DESC, ps.units_sold ASC;


-- ============================================================
-- 11. PRODUCT PERFORMANCE QUADRANTS
-- Classifies products using average units and average revenue
-- ============================================================

WITH ProductSales AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_sold,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM products AS p
    INNER JOIN order_items AS oi
        ON p.product_id = oi.product_id
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY
        p.product_id,
        p.product_name,
        p.category
),
ProductAverages AS
(
    SELECT
        AVG(units_sold) AS avg_units,
        AVG(total_revenue) AS avg_revenue
    FROM ProductSales
)
SELECT
    ps.product_id,
    ps.product_name,
    ps.category,
    ps.units_sold,
    ps.total_revenue,
    CASE
        WHEN ps.units_sold >= pa.avg_units
         AND ps.total_revenue >= pa.avg_revenue
            THEN 'High Volume / High Revenue'
        WHEN ps.units_sold >= pa.avg_units
         AND ps.total_revenue < pa.avg_revenue
            THEN 'High Volume / Low Revenue'
        WHEN ps.units_sold < pa.avg_units
         AND ps.total_revenue >= pa.avg_revenue
            THEN 'Low Volume / High Revenue'
        ELSE 'Low Volume / Low Revenue'
    END AS performance_quadrant
FROM ProductSales AS ps
CROSS JOIN ProductAverages AS pa
ORDER BY
    CASE
        WHEN ps.units_sold >= pa.avg_units
         AND ps.total_revenue >= pa.avg_revenue THEN 1
        WHEN ps.units_sold >= pa.avg_units
         AND ps.total_revenue < pa.avg_revenue THEN 2
        WHEN ps.units_sold < pa.avg_units
         AND ps.total_revenue >= pa.avg_revenue THEN 3
        ELSE 4
    END,
    ps.total_revenue DESC;


-- ============================================================
-- 12. PRODUCT CUMULATIVE REVENUE CONTRIBUTION
-- Useful for Pareto analysis
-- ============================================================

WITH ProductSales AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM products AS p
    INNER JOIN order_items AS oi
        ON p.product_id = oi.product_id
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
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
    CAST(total_revenue AS DECIMAL(18,2)) AS total_revenue,
    CAST(
        total_revenue * 100.0
        / NULLIF(SUM(total_revenue) OVER (), 0)
        AS DECIMAL(10,2)
    ) AS revenue_share_pct,
    CAST(
        SUM(total_revenue) OVER (
            ORDER BY total_revenue DESC, product_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) * 100.0
        / NULLIF(SUM(total_revenue) OVER (), 0)
        AS DECIMAL(10,2)
    ) AS cumulative_revenue_share_pct
FROM ProductSales
ORDER BY total_revenue DESC, product_id;


-- ============================================================
-- 13. PRODUCTS WITH NO VALID SALES
-- Useful for identifying inactive products
-- ============================================================

WITH ValidProductSales AS
(
    SELECT DISTINCT
        oi.product_id
    FROM order_items AS oi
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
)
SELECT
    p.product_id,
    p.product_name,
    p.category
FROM products AS p
LEFT JOIN ValidProductSales AS vps
    ON p.product_id = vps.product_id
WHERE vps.product_id IS NULL
ORDER BY p.product_id;


-- ============================================================
-- 14. CATEGORY PRODUCT COUNT
-- ============================================================

SELECT
    category,
    COUNT(*) AS product_count
FROM products
GROUP BY category
ORDER BY product_count DESC, category;


-- ============================================================
-- 15. PRODUCT PERFORMANCE WITH CATEGORY RANK
-- Rank products within their own category
-- ============================================================

WITH ProductSales AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_sold
    FROM products AS p
    INNER JOIN order_items AS oi
        ON p.product_id = oi.product_id
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
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
    total_revenue,
    RANK() OVER (
        PARTITION BY category
        ORDER BY total_revenue DESC
    ) AS category_revenue_rank
FROM ProductSales
ORDER BY category, category_revenue_rank, product_id;


-- ============================================================
-- 16. TOP PRODUCT IN EACH CATEGORY
-- ============================================================

WITH ProductSales AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM products AS p
    INNER JOIN order_items AS oi
        ON p.product_id = oi.product_id
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
    GROUP BY
        p.product_id,
        p.product_name,
        p.category
),
RankedProducts AS
(
    SELECT
        product_id,
        product_name,
        category,
        total_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY category
            ORDER BY total_revenue DESC, product_id
        ) AS category_row_num
    FROM ProductSales
)
SELECT
    product_id,
    product_name,
    category,
    total_revenue
FROM RankedProducts
WHERE category_row_num = 1
ORDER BY category;


-- ============================================================
-- 17. PRODUCT AVERAGE SELLING PRICE
-- Revenue divided by units sold
-- ============================================================

WITH ProductSales AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(CAST(oi.quantity AS DECIMAL(18,2))) AS units_sold,
        SUM(
            CAST(oi.quantity AS DECIMAL(18,2))
            * CAST(oi.price AS DECIMAL(18,2))
        ) AS total_revenue
    FROM products AS p
    INNER JOIN order_items AS oi
        ON p.product_id = oi.product_id
    INNER JOIN orders AS o
        ON oi.order_id = o.order_id
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
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
    total_revenue,
    CAST(
        total_revenue / NULLIF(units_sold, 0)
        AS DECIMAL(18,2)
    ) AS average_selling_price
FROM ProductSales
ORDER BY average_selling_price DESC, product_id;


-- ============================================================
-- 18. PRODUCT ANALYSIS BASELINE RECONCILIATION
-- Expected:
-- Valid Sales Orders = 656
-- Valid Revenue = 291331.00
-- Valid Units = 4536
-- ============================================================

WITH ValidSales AS
(
    SELECT
        o.order_id,
        oi.product_id,
        oi.quantity,
        oi.price
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'Completed'
      AND o.order_date >= c.signup_date
),
OrderTotals AS
(
    SELECT DISTINCT
        order_id
    FROM ValidSales
)
SELECT
    (SELECT COUNT(*) FROM OrderTotals) AS valid_sales_orders,
    CAST(
        SUM(
            CAST(quantity AS DECIMAL(18,2))
            * CAST(price AS DECIMAL(18,2))
        ) AS DECIMAL(18,2)
    ) AS valid_revenue,
    SUM(CAST(quantity AS INT)) AS valid_units,
    CASE
        WHEN (SELECT COUNT(*) FROM OrderTotals) = 656
         AND CAST(
                SUM(
                    CAST(quantity AS DECIMAL(18,2))
                    * CAST(price AS DECIMAL(18,2))
                ) AS DECIMAL(18,2)
             ) = 291331.00
         AND SUM(CAST(quantity AS INT)) = 4536
        THEN 'PASS'
        ELSE 'CHECK'
    END AS validation_status
FROM ValidSales;


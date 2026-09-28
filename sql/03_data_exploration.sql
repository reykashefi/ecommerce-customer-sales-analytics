SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items;

SELECT MIN(order_date) AS first_order_date, MAX(order_date) AS last_order_date, COUNT(DISTINCT order_date) AS distinct_order_dates FROM orders;
SELECT MIN(signup_date) AS first_signup_date, MAX(signup_date) AS last_signup_date, COUNT(DISTINCT signup_date) AS distinct_signup_dates FROM customers;

SELECT country, COUNT(*) AS customer_count,
CAST(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM customers),0) AS DECIMAL(10,2)) AS customer_percentage
FROM customers GROUP BY country ORDER BY customer_count DESC;

SELECT YEAR(signup_date) AS signup_year, COUNT(*) AS customer_count FROM customers GROUP BY YEAR(signup_date) ORDER BY signup_year;

SELECT category, COUNT(*) AS product_count,
CAST(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM products),0) AS DECIMAL(10,2)) AS product_percentage
FROM products GROUP BY category ORDER BY product_count DESC;

SELECT status, COUNT(*) AS order_count,
CAST(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM orders),0) AS DECIMAL(10,2)) AS order_percentage
FROM orders GROUP BY status ORDER BY order_count DESC;

SELECT YEAR(order_date) AS order_year, COUNT(*) AS order_count FROM orders GROUP BY YEAR(order_date) ORDER BY order_year;

SELECT YEAR(order_date) AS order_year, MONTH(order_date) AS order_month, COUNT(*) AS order_count
FROM orders GROUP BY YEAR(order_date), MONTH(order_date) ORDER BY order_year, order_month;

SELECT COUNT(DISTINCT o.order_id) AS valid_sales_orders, COUNT(DISTINCT o.customer_id) AS valid_customers,
SUM(CAST(oi.quantity AS DECIMAL(18,2)) * CAST(oi.price AS DECIMAL(18,2))) AS valid_revenue,
SUM(CAST(oi.quantity AS INT)) AS valid_units
FROM orders o JOIN customers c ON o.customer_id=c.customer_id JOIN order_items oi ON o.order_id=oi.order_id
WHERE o.status='Completed' AND o.order_date>=c.signup_date;

SELECT COUNT(DISTINCT o.order_id) AS total_valid_orders, COUNT(DISTINCT o.customer_id) AS total_valid_customers,
SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2))) AS total_revenue,
SUM(CAST(oi.quantity AS INT)) AS total_units,
CAST(SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2)))/NULLIF(COUNT(DISTINCT o.order_id),0) AS DECIMAL(18,2)) AS average_order_value,
CAST(SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2)))/NULLIF(COUNT(DISTINCT o.customer_id),0) AS DECIMAL(18,2)) AS average_revenue_per_customer,
CAST(SUM(CAST(oi.quantity AS DECIMAL(18,2)))/NULLIF(COUNT(DISTINCT o.order_id),0) AS DECIMAL(18,2)) AS average_units_per_order
FROM orders o JOIN customers c ON o.customer_id=c.customer_id JOIN order_items oi ON o.order_id=oi.order_id
WHERE o.status='Completed' AND o.order_date>=c.signup_date;

SELECT YEAR(o.order_date) AS order_year, MONTH(o.order_date) AS order_month, COUNT(DISTINCT o.order_id) AS valid_orders,
SUM(CAST(oi.quantity AS INT)) AS units_sold,
SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2))) AS revenue
FROM orders o JOIN customers c ON o.customer_id=c.customer_id JOIN order_items oi ON o.order_id=oi.order_id
WHERE o.status='Completed' AND o.order_date>=c.signup_date
GROUP BY YEAR(o.order_date), MONTH(o.order_date) ORDER BY order_year, order_month;

SELECT YEAR(o.order_date) AS order_year, COUNT(DISTINCT o.order_id) AS valid_orders,
SUM(CAST(oi.quantity AS INT)) AS units_sold,
SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2))) AS revenue
FROM orders o JOIN customers c ON o.customer_id=c.customer_id JOIN order_items oi ON o.order_id=oi.order_id
WHERE o.status='Completed' AND o.order_date>=c.signup_date
GROUP BY YEAR(o.order_date) ORDER BY order_year;

SELECT p.category, COUNT(DISTINCT o.order_id) AS valid_orders, SUM(CAST(oi.quantity AS INT)) AS units_sold,
SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2))) AS revenue
FROM orders o JOIN customers c ON o.customer_id=c.customer_id JOIN order_items oi ON o.order_id=oi.order_id JOIN products p ON oi.product_id=p.product_id
WHERE o.status='Completed' AND o.order_date>=c.signup_date
GROUP BY p.category ORDER BY revenue DESC;

SELECT p.product_id,p.product_name,p.category,COUNT(DISTINCT o.order_id) AS order_count,SUM(CAST(oi.quantity AS INT)) AS units_sold,
SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2))) AS revenue
FROM orders o JOIN customers c ON o.customer_id=c.customer_id JOIN order_items oi ON o.order_id=oi.order_id JOIN products p ON oi.product_id=p.product_id
WHERE o.status='Completed' AND o.order_date>=c.signup_date
GROUP BY p.product_id,p.product_name,p.category ORDER BY revenue DESC;

SELECT o.customer_id,COUNT(DISTINCT o.order_id) AS order_count,SUM(CAST(oi.quantity AS INT)) AS units_purchased,
SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2))) AS total_revenue,
CAST(SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2)))/NULLIF(COUNT(DISTINCT o.order_id),0) AS DECIMAL(18,2)) AS average_order_value
FROM orders o JOIN customers c ON o.customer_id=c.customer_id JOIN order_items oi ON o.order_id=oi.order_id
WHERE o.status='Completed' AND o.order_date>=c.signup_date
GROUP BY o.customer_id ORDER BY total_revenue DESC;

SELECT x.order_count,COUNT(*) AS customer_count FROM (
SELECT o.customer_id,COUNT(DISTINCT o.order_id) AS order_count
FROM orders o JOIN customers c ON o.customer_id=c.customer_id JOIN order_items oi ON o.order_id=oi.order_id
WHERE o.status='Completed' AND o.order_date>=c.signup_date GROUP BY o.customer_id
) x GROUP BY x.order_count ORDER BY x.order_count;

SELECT x.spend_band,COUNT(*) AS customer_count,SUM(x.total_revenue) AS total_revenue FROM (
SELECT o.customer_id,SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2))) AS total_revenue,
CASE WHEN SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2)))<250 THEN 'Under 250'
WHEN SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2)))<500 THEN '250 - 499'
WHEN SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2)))<1000 THEN '500 - 999'
WHEN SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2)))<2000 THEN '1000 - 1999' ELSE '2000+' END AS spend_band
FROM orders o JOIN customers c ON o.customer_id=c.customer_id JOIN order_items oi ON o.order_id=oi.order_id
WHERE o.status='Completed' AND o.order_date>=c.signup_date GROUP BY o.customer_id
) x GROUP BY x.spend_band
ORDER BY CASE x.spend_band WHEN 'Under 250' THEN 1 WHEN '250 - 499' THEN 2 WHEN '500 - 999' THEN 3 WHEN '1000 - 1999' THEN 4 ELSE 5 END;

SELECT CASE WHEN p.customer_id IS NULL THEN 'Non-Purchasing' ELSE 'Purchasing' END AS customer_type,COUNT(*) AS customer_count
FROM customers c LEFT JOIN (
SELECT DISTINCT o.customer_id FROM orders o JOIN customers c2 ON o.customer_id=c2.customer_id JOIN order_items oi ON o.order_id=oi.order_id
WHERE o.status='Completed' AND o.order_date>=c2.signup_date
) p ON c.customer_id=p.customer_id
GROUP BY CASE WHEN p.customer_id IS NULL THEN 'Non-Purchasing' ELSE 'Purchasing' END;

SELECT x.order_value_band,COUNT(*) AS order_count,CAST(AVG(x.order_revenue) AS DECIMAL(18,2)) AS average_order_value FROM (
SELECT o.order_id,SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2))) AS order_revenue,
CASE WHEN SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2)))<250 THEN 'Under 250'
WHEN SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2)))<500 THEN '250 - 499'
WHEN SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2)))<1000 THEN '500 - 999'
WHEN SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2)))<2000 THEN '1000 - 1999' ELSE '2000+' END AS order_value_band
FROM orders o JOIN customers c ON o.customer_id=c.customer_id JOIN order_items oi ON o.order_id=oi.order_id
WHERE o.status='Completed' AND o.order_date>=c.signup_date GROUP BY o.order_id
) x GROUP BY x.order_value_band
ORDER BY CASE x.order_value_band WHEN 'Under 250' THEN 1 WHEN '250 - 499' THEN 2 WHEN '500 - 999' THEN 3 WHEN '1000 - 1999' THEN 4 ELSE 5 END;

SELECT COUNT(DISTINCT o.order_id) AS valid_sales_orders,COUNT(DISTINCT o.customer_id) AS valid_customers,
SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2))) AS valid_revenue,
SUM(CAST(oi.quantity AS INT)) AS valid_units,
CAST(SUM(CAST(oi.quantity AS DECIMAL(18,2))*CAST(oi.price AS DECIMAL(18,2)))/NULLIF(COUNT(DISTINCT o.order_id),0) AS DECIMAL(18,2)) AS average_order_value
FROM orders o JOIN customers c ON o.customer_id=c.customer_id JOIN order_items oi ON o.order_id=oi.order_id
WHERE o.status='Completed' AND o.order_date>=c.signup_date;


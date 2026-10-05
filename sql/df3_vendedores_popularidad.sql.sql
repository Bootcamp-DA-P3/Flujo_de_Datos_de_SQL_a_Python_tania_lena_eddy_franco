USE olist;

-- DF3: una fila = un par vendedor-producto, con las unidades vendidas
-- Decisiones de limpieza:
-- 1) seller_city y seller_state en minúsculas y sin espacios (LOWER(TRIM())).
-- 2) Productos sin categoría (NULL) se conservan como 'sin_categoria' para no perder ventas.
-- 3) Solo hay productos que se han vendido (partimos de order_items).
SELECT v.seller_id,
       LOWER(TRIM(s.seller_city))  AS seller_city,
       LOWER(TRIM(s.seller_state)) AS seller_state,
       v.product_id,
       COALESCE(p.product_category_name, 'sin_categoria') AS product_category_name,
       v.unidades_vendidas
FROM (
  SELECT seller_id, product_id, COUNT(*) AS unidades_vendidas
  FROM order_items
  GROUP BY seller_id, product_id
) AS v
JOIN sellers  AS s ON v.seller_id  = s.seller_id
JOIN products AS p ON v.product_id = p.product_id;
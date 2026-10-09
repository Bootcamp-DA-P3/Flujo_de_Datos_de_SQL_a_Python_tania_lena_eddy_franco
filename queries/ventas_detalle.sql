-- GRANO: una fila = una linea de pedido entregado (linea_id)
-- PAPEL: TABLA DE HECHOS central del modelo
SELECT
    CONCAT(i.order_id, '-', i.order_item_id) AS linea_id,
    i.order_id,
    c.customer_unique_id,
    i.product_id,
    i.seller_id,
    DATE(o.order_purchase_timestamp) AS fecha_compra,
    i.price                   AS precio,
    i.freight_value           AS flete,
    ROUND(i.price + i.freight_value, 2) AS importe_linea
FROM order_items i
JOIN orders o
    ON o.order_id = i.order_id
JOIN customers c
    ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
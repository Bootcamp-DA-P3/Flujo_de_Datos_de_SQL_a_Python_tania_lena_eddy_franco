-- GRANO DECLARADO: Grano: 1 fila = 1 pedido/customer_id 
use olist;
WITH 
-- 1. trampa de geolocation. Limpieza y agregación de geolocalización (Corregida con ciudad en GROUP BY)
-- Evita que las filas se multipliquen al hacer el JOIN.
geo_clean AS (
    SELECT 
        geolocation_zip_code_prefix AS zip_code,
 --       LOWER(TRIM(geolocation_city)) AS geo_city,
 --       geolocation_state AS geo_state,
        AVG(geolocation_lat) AS customer_lat,
        AVG(geolocation_lng) AS customer_lng
    FROM geolocation
    GROUP BY 
        geolocation_zip_code_prefix
 --      LOWER(TRIM(geolocation_city)), 
 --      geolocation_state
),

-- 2. Agregación de pagos por pedido. Limpia y consolida pagos.
payments_agg AS (
    SELECT 
        order_id,
        SUM(payment_value) AS total_payment_value,
        COUNT(payment_sequential) AS payment_installments_count,
        GROUP_CONCAT(DISTINCT payment_type SEPARATOR ', ') AS payment_types_used
    FROM order_payments
    WHERE payment_value > 0 
      AND payment_type != 'not_defined'
    GROUP BY order_id
),

-- 3. Agregación de reseñas por pedido
reviews_agg AS (
    SELECT 
        order_id,
        AVG(review_score) AS avg_review_score,
        MAX(review_creation_date) AS latest_review_date
    FROM order_reviews
    GROUP BY order_id
)

-- 4. Consulta Principal (Grano: 1 fila = 1 pedido / customer_id)
SELECT 
    o.order_id,
    c.customer_id,
    c.customer_unique_id,
    LOWER(TRIM(c.customer_city)) AS customer_city,
    UPPER(TRIM(c.customer_state)) AS customer_state,
    c.customer_zip_code_prefix,
    g.customer_lat,
    g.customer_lng,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    
    -- Métricas de pagos limpios
    p.total_payment_value,
    p.payment_installments_count,
    p.payment_types_used,
    
    -- Métricas de satisfacción
    r.avg_review_score,
    
    -- Columnas derivadas
    DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) AS delivery_days,
    CASE 
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 
        ELSE 0 
    END AS is_late

FROM orders o
INNER JOIN customers c 
    ON o.customer_id = c.customer_id
LEFT JOIN geo_clean g 
    ON c.customer_zip_code_prefix = g.zip_code
LEFT JOIN payments_agg p 
    ON o.order_id = p.order_id
LEFT JOIN reviews_agg r 
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp < o.order_delivered_customer_date;
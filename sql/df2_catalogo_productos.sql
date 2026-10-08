-- =============================================================================
-- GRANO: una fila = un producto con dimensiones validas (product_id)
-- =============================================================================

WITH 
-- 1. Métricas comerciales agregadas por producto desde order_items
metricas_ventas AS (
    SELECT 
        oi.product_id,
        COUNT(oi.order_item_id) AS total_unidades_vendidas,
        COUNT(DISTINCT oi.seller_id) AS total_vendedores_distintos,
        ROUND(AVG(oi.price), 2) AS precio_promedio,
        ROUND(MIN(oi.price), 2) AS precio_min,
        ROUND(MAX(oi.price), 2) AS precio_max,
        ROUND(AVG(oi.freight_value), 2) AS coste_envio_promedio
    FROM order_items oi
    GROUP BY oi.product_id
),

-- 2. Limpieza preliminar y filtros físicos sobre la tabla products
productos_filtrados AS (
    SELECT 
        p.product_id,
        LOWER(TRIM(p.product_category_name)) AS categoria_pt_limpia,
        p.product_name_lenght,
        p.product_description_lenght,
        p.product_photos_qty,
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm
    FROM products p
    WHERE p.product_weight_g IS NOT NULL AND p.product_weight_g > 0
      AND p.product_length_cm IS NOT NULL AND p.product_length_cm > 0
      AND p.product_height_cm IS NOT NULL AND p.product_height_cm > 0
      AND p.product_width_cm  IS NOT NULL AND p.product_width_cm  > 0
)

-- 3. Unión consolidada y columnas calculadas
SELECT 
    pf.product_id,
    
    -- Categoría original limpia (gestión de los 610 nulos)
    COALESCE(NULLIF(pf.categoria_pt_limpia, ''), 'unknown') AS categoria_pt,
    
    -- Categoría traducida (resolución de las 2 huérfanas + LEFT JOIN)
    CASE 
        WHEN pf.categoria_pt_limpia = 'pc_gamer' 
            THEN 'pc_gamer'
        WHEN pf.categoria_pt_limpia = 'portateis_cozinha_e_preparadores_de_alimentos' 
            THEN 'small_appliances_and_food_preparers'
        WHEN t.product_category_name_english IS NOT NULL 
            THEN LOWER(TRIM(t.product_category_name_english))
        ELSE 'unknown'
    END AS categoria_en,
    
    -- Atributos dimensionales
    pf.product_name_lenght,
    pf.product_description_lenght,
    pf.product_photos_qty,
    pf.product_weight_g,
    pf.product_length_cm,
    pf.product_height_cm,
    pf.product_width_cm,
    
    -- Columna derivada: Producto pesado (>= 5 kg)
    CASE 
        WHEN pf.product_weight_g >= 5000 THEN 1 
        ELSE 0 
    END AS is_heavy,
    
    -- Métricas comerciales asociadas
    COALESCE(mv.total_unidades_vendidas, 0) AS total_unidades_vendidas,
    COALESCE(mv.total_vendedores_distintos, 0) AS total_vendedores_distintos,
    mv.precio_promedio,
    mv.precio_min,
    mv.precio_max,
    mv.coste_envio_promedio,
    
    -- Columna derivada: freight_ratio (evitando división por cero o nulos)
    ROUND(mv.coste_envio_promedio / NULLIF(mv.precio_promedio, 0), 4) AS freight_ratio

FROM productos_filtrados pf
LEFT JOIN categoria_traduccion t 
    ON pf.categoria_pt_limpia = LOWER(TRIM(t.product_category_name))
LEFT JOIN metricas_ventas mv 
    ON pf.product_id = mv.product_id;
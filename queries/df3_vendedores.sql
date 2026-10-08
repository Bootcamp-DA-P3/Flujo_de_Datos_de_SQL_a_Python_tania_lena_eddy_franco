 -- GRANO: una fila = un vendedor (seller_id)
-- Se agrega order_items por vendedor ANTES de unir con sellers.
 WITH venta_por_vendedor AS (
 -- tu CTE tal cual
		SELECT
			oi.seller_id,
			COUNT(*) AS unidades_vendidas,
			COUNT(DISTINCT oi.product_id) AS catalogo_productos,
			COUNT(DISTINCT COALESCE(p.product_category_name, 'sin_categoria')) AS categorias,
			COUNT(DISTINCT oi.order_id) AS pedidos,
			ROUND(SUM(oi.price), 2) AS ingresos,
			ROUND(SUM(oi.freight_value), 2) AS flete
		FROM order_items oi
		LEFT JOIN products p ON p.product_id = oi.product_id
		GROUP BY oi.seller_id
	)
	SELECT
		s.seller_id,
		LOWER(TRIM(s.seller_city)) AS seller_city,
		UPPER(TRIM(s.seller_state)) AS seller_state,
		v.unidades_vendidas,
		v.catalogo_productos,
		v.categorias,
		v.pedidos,
		v.ingresos,
		v.flete
	FROM venta_por_vendedor v
	JOIN sellers s ON s.seller_id = v.seller_id
    ORDER BY v.unidades_vendidas DESC
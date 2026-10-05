# Flujo_de_Datos_de_SQL_a_Python_tania_lena_eddy_franco
<img width="1280" height="640" alt="image" src="https://github.com/user-attachments/assets/08630d49-0f5e-42a5-8d01-eac9891b703d" />

## Integrantes
- Tania
- Lena
- Eddy
- Franco

## Descripción del proyecto
En este proyecto trabajamos con datos mediante consultas SQL y Python.

Hemos realizado la extracción de datos desde SQL, creado diferentes dataframes y seleccionado uno de ellos para su análisis y limpieza. Posteriormente, hemos trabajado estos datos en Python para prepararlos y analizarlos.

## Tecnologías utilizadas
- SQL
- Python
- Pandas
- Google Collab

# DF3 – Vendedores y Popularidad (Olist Dataset)

## 1. Descripción del Proyecto

Este análisis se centra en el **DataFrame 3: Vendedores y Popularidad**, construido a partir de los microdatos del marketplace brasileño Olist. El propósito principal es entender la estructura del catálogo por comerciante, la frecuencia de rotación de sus productos y el grado de concentración del volumen total de ventas en la plataforma.

---

## 2. Origen y Modelado de Datos

El conjunto de datos unificado proviene del cruce relacional de tres tablas maestras de la base de datos de Olist:

- **`sellers`**: Información de ubicación geográfica del vendedor (`seller_city`, `seller_state`).
- **`order_items`**: Transacciones y unidades comercializadas por ítem (`order_item_id`, `price`, `freight_value`).
- **`products`**: Clasificación y atributos del catálogo (`product_category_name`).

---

## 3. Definición del Grano de Negocio

Para asegurar la coherencia analítica y la correcta agregación de métricas, el grano de este estudio se define formalmente de la siguiente manera:

* **GRANO:** `"Nivel de Vendedor"`
* **CLAVE_DE_GRANO:** `"seller_id"`

### Interpretación en Lenguaje de Negocio:
Cada registro consolidado para la toma de decisiones representa a **un comerciante único** activo en la plataforma. A este nivel se evalúan sus métricas clave: volumen agregado de unidades vendidas, amplitud de catálogo (variedad de productos únicos ofrecidos), diversificación de categorías y cuota de participación sobre el total transaccionado en el ecosistema.

> **Nota sobre el dataset intermedio (`df3_vendedores_productos.csv`):**  
> El paso previo de consolidación opera a nivel par vendedor-producto (`(seller_id, product_id)`) para capturar la dispersión del catálogo, colapsándose posteriormente sobre la clave de grano (`seller_id`) para el ranking de concentración y análisis de desempeño.

---

## 4. Pipeline de Limpieza y Preparación de Datos

En el notebook `df3_vendedores_populares.ipynb` se aplica el siguiente protocolo de calidad de datos:

1. **Gestión de Fechas:** Se documenta que el dataset exportado no contiene atributos temporales directos debido a su nivel de agregación transaccional.
2. **Normalización de Cadenas:** Estandarización de `seller_city`, `seller_state` y `product_category_name` eliminando espacios en blanco perimetrales (`strip`) y forzando minúsculas (`lower`).
3. **Control de Duplicados e Integridad de Clave:** Verificación de unicidad tanto a nivel de fila completa como sobre la clave de combinación par `(seller_id, product_id)`.
4. **Valores Faltantes:** Validación y registro de las decisiones de negocio previas (categorías no especificadas imputadas en SQL como `'sin_categoria'`).
5. **Tipos Numéricos y Optimización:** Conversión estricta de `unidades_vendidas` a tipo entero (`int32`) y categorización de campos de baja cardinalidad (`seller_state`).
6. **Detección y Criterio de Outliers:** Identificación de valores atípicos mediante el método de Rango Intercuartílico (IQR). Se adopta el criterio de negocio de **no suprimir** valores extremos, dado que representan los productos *best-seller* y vendedores de alto volumen indispensables para evaluar la concentración real.
7. **Ingeniería de Variables (Columnas Derivadas):**
   - `total_unidades_vendedor`: Suma total de unidades vendidas por comerciante.
   - `catalogo_vendedor_count`: Cantidad de productos distintos ofertados por vendedor.
   - `pct_ventas_producto_vendedor`: Peso porcentual de cada producto en la facturación física del vendedor.
8. **Validación de Distribuciones:** Generación de histogramas (en escala logarítmica para mitigar asimetría positiva) y diagramas de caja (*boxplots*).
9. **Exportación:** Generación del archivo procesado `df3_vendedores_productos_limpio.csv` (excluido del repositorio de código mediante `.gitignore`).

---

## 5. Hallazgos Principales

- **Universo evaluado:** 3.095 vendedores activos y 112.650 unidades vendidas consolidadas.
- **Concentración:** El **top 10 de vendedores (0,3 % del total)** concentra **15.942 unidades**, equivalente al **14,2 %** del volumen total del marketplace.
- **Distribución de la cabeza del ranking:** El decrecimiento entre los diez primeros vendedores es progresivo y escalonado (desde 2.033 unidades el líder hasta 1.171 el décimo puesto), sin existir un actor monopolístico único.

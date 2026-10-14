# Chinook: del CSV al dashboard

Guía individual. Vas a repetir, tú solo, el proceso del proyecto del grupo 0 con una base más pequeña: consultas en MySQL, un ETL en Python que comprueba el grano, los CSV generados y un libro de Excel con Power Query y un modelo de datos.

**Tiempo:** una tarde o una noche, de 3 a 4 horas si lees cada paso.

**Cómo usar esta guía:**

- No copies a ciegas. Antes de cada bloque de código hay una pregunta: respóndela con tus palabras.
- Después de cada paso hay una **cifra de control**. Si no te sale, no sigas: vuelve al paso.
- Si algo falla en tu máquina, lo más probable es la configuración (contraseña, nombre de la base, rutas), no el código.

## Qué necesitas

| Herramienta | Versión | Para qué |
| :--- | :--- | :--- |
| MySQL Server | 8.0 | La base de datos (el mismo de la P3) |
| MySQL Workbench | 8.0 | Escribir y probar consultas |
| Python | 3.11 o superior | El ETL |
| Excel | 2016 o superior | El dashboard, con Power Query |

---

## 0. El encargo

Chinook es una tienda digital de música: vende canciones por unidades, con facturas a clientes de todo el mundo. Tú eres su analista de datos.

La dirección comercial te pide tres cosas:

1. **Qué géneros y qué artistas generan más ingresos**, y cómo evolucionan año a año.
2. **Qué países compran más.**
3. **Reto opcional:** cuántas canciones tienen una duración fuera de lo normal, y si se venden igual que el resto.

Lo que vas a entregar:

- La carpeta `chinook-automatizacion` con los CSV generados.
- Un libro de Excel con los tres datasets en el modelo de datos, sus relaciones y tres tablas dinámicas.
- Tres frases en la hoja `Dashboard` con lo que dice cada dinámica.

---

## 1. El mapa antes de empezar

Este proyecto tiene las mismas piezas que el del grupo 0. Antes de escribir nada, entiende para qué sirve cada una:

| Fichero | Para qué existe |
| :--- | :--- |
| `queries/ventas_linea.sql` | La tabla de hechos: una fila por línea de factura. Es lo que se mide. |
| `queries/canciones.sql` | Una dimensión: describe cada canción. Junta artista, álbum y género en una sola fila. |
| `queries/clientes.sql` | Otra dimensión: describe cada cliente. |
| `src/config.py` | Lee las credenciales del `.env`. No hace falta tocarlo. |
| `src/limpieza.py` | Las reglas que necesitan ver todo el conjunto (aquí, las canciones atípicas). |
| `src/chinook_ETL.py` | El motor: ejecuta cada consulta, comprueba el grano, limpia y exporta. |
| `src/excel.py` | Crea el libro de Excel la primera vez. No lo diseña: eso lo haces tú. |
| `main.py` | El punto de entrada. `python main.py` y ya. |
| `.env` | Tus credenciales. No se sube nunca al repositorio. |

Estructura final:

```
chinook-automatizacion/
├── main.py
├── requirements.txt
├── .env.example        plantilla; tu .env se crea a partir de ella
├── .gitignore
├── queries/
│   ├── ventas_linea.sql
│   ├── canciones.sql
│   └── clientes.sql
├── src/
│   ├── __init__.py
│   ├── config.py
│   ├── limpieza.py
│   ├── chinook_ETL.py
│   └── excel.py
├── output/             aquí se generan los CSV
└── dashboard/          aquí va tu libro de Excel
```

En el proyecto data automation grupo 0 hay también un notebook de exploración. Aquí no hace falta: lo sustituye MySQL Workbench.

---

## 2. Descargar la base de datos

**Qué base es:** Chinook, una base de ejemplo con licencia MIT (uso libre, también en formación) que lleva años usándose para enseñar bases de datos. Tiene 11 tablas: canciones, álbumes, artistas, géneros, clientes, empleados, facturas y líneas de factura.

**Dónde está:** en el repositorio oficial `lerocha/chinook-database`.

**Opción A, sin Git:**

1. Abre https://github.com/lerocha/chinook-database
2. Pulsa el botón verde **Code** > **Download ZIP**.
3. Descomprime el ZIP. El fichero que necesitas está en:

```
chinook-database-master/ChinookDatabase/DataSources/Chinook_MySql.sql
```

**Opción B, con Git:**

```powershell
git clone https://github.com/lerocha/chinook-database.git
```

El mismo fichero queda en `chinook-database\ChinookDatabase\DataSources\Chinook_MySql.sql`.

**Qué fichero exactamente:** `Chinook_MySql.sql`. No el de SQL Server, ni el de Oracle, ni el de SQLite. Pesa unos 600 KB.

> **Cuidado:** el script empieza con `DROP DATABASE IF EXISTS Chinook`. Si ya tienes una base llamada `Chinook` con datos que quieras conservar, haz una copia antes de ejecutarlo.

---

## 3. Cargarla en MySQL Workbench

1. Abre MySQL Workbench y conéctate con tu usuario de la P3.
2. `File` > `Open SQL Script` > elige `Chinook_MySql.sql`.
3. Ejecútalo entero: `Query` > `Execute` (o `Ctrl + Shift + Enter`).
4. En el panel izquierdo, pulsa el botón de refrescar bajo `SCHEMAS`. Debe aparecer `Chinook`.

**Comprobación.** Pega esto en una pestaña nueva y ejecútalo:

```sql
USE Chinook;

SELECT 'Invoice' AS tabla, COUNT(*) AS filas FROM Invoice
UNION ALL SELECT 'InvoiceLine', COUNT(*) FROM InvoiceLine
UNION ALL SELECT 'Track', COUNT(*) FROM Track
UNION ALL SELECT 'Customer', COUNT(*) FROM Customer;
```

Debe salir:

| tabla | filas |
| :--- | ---: |
| Invoice | 412 |
| InvoiceLine | 2240 |
| Track | 3503 |
| Customer | 59 |

Si no te salen estos números, no sigas.

Las fechas del script vienen escritas como `2021/1/1`. MySQL las guarda como `2021-01-01 00:00:00`. Es normal. Compruébalo:

```sql
SELECT MIN(InvoiceDate), MAX(InvoiceDate) FROM Invoice;
```

Debe salir `2021-01-01 00:00:00` como mínimo, y una fecha de finales de 2025 como máximo.

---

## 4. La primera pregunta: qué cuenta cada fila

Antes de escribir código de proyecto, haz este ejercicio en Workbench.

**Paso A.** Calcula la facturación total de la tienda:

```sql
SELECT ROUND(SUM(Total), 2) AS facturacion FROM Invoice;
```

Debe salir **2328.60**. Ese es el número bueno.

**Paso B.** Calcula la misma facturación, pero uniendo las facturas con sus líneas, y suma el total de cada factura:

```sql
SELECT ROUND(SUM(i.Total), 2) AS facturacion
FROM Invoice i
JOIN InvoiceLine il
    ON il.InvoiceId = i.InvoiceId;
```

Sale **20848.62**. Casi nueve veces más. Nadie ha cambiado los datos.

**Pregunta:** ¿por qué sale más? Antes de abrir la respuesta, ejecuta esto y piensa qué significa:

```sql
SELECT InvoiceId, COUNT(*) AS lineas
FROM InvoiceLine
GROUP BY InvoiceId
ORDER BY lineas DESC
LIMIT 5;
```

<details>
<summary>Respuesta (intenta antes de abrirla)</summary>

Cada factura tiene varias líneas. Al unir `Invoice` con `InvoiceLine`, la fila de la factura se repite una vez por cada línea, y `SUM(Total)` la suma tantas veces como líneas tenga. La factura no ha cambiado: lo que ha cambiado es lo que cuenta cada fila.

Esto es el **grano**: qué representa una fila. En `Invoice` una fila es una factura; después del JOIN, una fila es una línea. Si sumas una medida de la factura después de unirla con sus líneas, la estás contando varias veces. Por eso en este proyecto el importe se calcula **por línea**, nunca se toma el total de la factura.

</details>

---

## 5. Preparar el proyecto

En PowerShell, dentro de la carpeta donde quieras trabajar:

```powershell
mkdir chinook-automatizacion
cd chinook-automatizacion
mkdir queries, src, output, dashboard
New-Item -ItemType File output\.gitkeep
New-Item -ItemType File src\__init__.py
python -m venv .venv
.venv\Scripts\activate
```

Crea los ficheros con los bloques de código de las secciones 6 y 7, en las rutas que indica cada encabezado. Cuando estén todos:

```powershell
pip install -r requirements.txt
Copy-Item .env.example .env
```

Abre `.env` y pon tu contraseña de MySQL en `DB_PASSWORD`. Deja `DB_NAME=Chinook`.

> Guarda siempre los ficheros en **UTF-8**. Si el editor te pregunta por la codificación, elige UTF-8.

---

## 6. Las consultas (`queries/`)

Cada consulta tiene una cabecera que declara su **grano** (qué es una fila) y su **papel** (si mide o describe). Es la regla que sigue todo el proyecto: si no sabes decir qué es una fila, la consulta no está terminada.

### 6.1 `queries/ventas_linea.sql`: la tabla de hechos

```sql
-- GRANO: una fila = una linea de factura (linea_id)
-- PAPEL: TABLA DE HECHOS. Mide. Es el centro del modelo:
--         las dos dimensiones se unen a ella por su clave.
--
-- Cada linea es una cancion vendida a un cliente en una fecha.
-- No agrega nada: InvoiceLine ya viene al grano de linea.
-- Sumar el importe de la factura (Invoice.Total) aqui multiplicaria cada
-- factura por su numero de lineas. Por eso el importe se calcula por linea.

SELECT
    il.InvoiceLineId                AS linea_id,
    il.InvoiceId                    AS factura_id,
    i.CustomerId                    AS cliente_id,
    il.TrackId                      AS cancion_id,
    DATE(i.InvoiceDate)             AS fecha,
    il.UnitPrice                    AS precio,
    il.Quantity                     AS cantidad,
    il.UnitPrice * il.Quantity      AS importe_linea
FROM InvoiceLine il
JOIN Invoice i
    ON i.InvoiceId = il.InvoiceId
ORDER BY il.InvoiceLineId
```

**Pregunta:** ¿qué pasaría si, en vez de `il.UnitPrice * il.Quantity`, sumáramos `i.Total`? Relaciónalo con lo que acabas de ver en la sección 4.

**Comprobación en Workbench.** Pega la consulta (si termina en `;`, quítalo) y envuélvela así para contar filas y claves:

```sql
SELECT COUNT(*) AS filas, COUNT(DISTINCT linea_id) AS claves
FROM (
    -- pega aquí la consulta, sin el ; final
) AS t;
```

Debe salir **2240** y **2240**. Si las dos cifras no coinciden, algo está multiplicando filas.

### 6.2 `queries/canciones.sql`: una dimensión, aplanada

```sql
-- GRANO: una fila = una cancion (cancion_id)
-- PAPEL: dimension. Describe la cancion.
--
-- En la base de origen, la cancion esta repartida en cuatro tablas encadenadas:
-- Track -> Album -> Artist, y Track -> Genre aparte.
-- Esta consulta las aplana: una sola fila por cancion, con el artista, el album
-- y el genero como texto. Es el mismo paso que catalogo_productos.sql en el
-- proyecto del grupo 0: el copo de nieve se convierte en estrella.

SELECT
    t.TrackId                          AS cancion_id,
    t.Name                             AS cancion,
    COALESCE(ar.Name, 'sin_artista')   AS artista,
    COALESCE(al.Title, 'sin_album')    AS album,
    COALESCE(g.Name, 'sin_genero')     AS genero,
    t.Milliseconds                     AS duracion_ms,
    t.UnitPrice                        AS precio
FROM Track t
LEFT JOIN Album al
    ON al.AlbumId = t.AlbumId
LEFT JOIN Artist ar
    ON ar.ArtistId = al.ArtistId
LEFT JOIN Genre g
    ON g.GenreId = t.GenreId
ORDER BY t.TrackId
```

En la base, una canción está repartida en cuatro tablas: `Track`, `Album`, `Artist` y `Genre`. Aquí las juntamos en una sola fila. Es el mismo gesto que en el grupo 0 con las categorías de los productos: un copo de nieve convertido en estrella.

**Comprobación:** con la misma plantilla de la sección 6.1, debe salir **3503** y **3503**.

### 6.3 `queries/clientes.sql`: una dimensión

```sql
-- GRANO: una fila = un cliente (cliente_id)
-- PAPEL: dimension. Describe al cliente.
--
-- Las dos columnas de medida (facturas y gasto_total) se calculan a su propio
-- grano. Sirven para ordenar y filtrar, no para sumarlas en una dinamica cruzada:
-- para eso se usa ventas_linea.

SELECT
    c.CustomerId                                  AS cliente_id,
    CONCAT(c.FirstName, ' ', c.LastName)          AS cliente,
    c.Country                                     AS pais,
    c.City                                        AS ciudad,
    COUNT(DISTINCT i.InvoiceId)                   AS facturas,
    ROUND(COALESCE(SUM(i.Total), 0), 2)           AS gasto_total
FROM Customer c
LEFT JOIN Invoice i
    ON i.CustomerId = c.CustomerId
GROUP BY c.CustomerId, c.FirstName, c.LastName, c.Country, c.City
ORDER BY gasto_total DESC
```

**Comprobación:** **59** y **59**.

---

## 7. El código Python

Crea cada fichero con su contenido. No ejecutes nada hasta tener todos.

### `requirements.txt`

```text
pandas==2.3.3
SQLAlchemy==2.0.44
mysql-connector-python==9.5.0
python-dotenv==1.2.1
openpyxl==3.1.5
```

### `.env.example`

```ini
# Plantilla de configuracion. Copiad este fichero como .env y rellenad vuestros datos.
# El .env nunca se sube al repositorio: contiene vuestra contrasena.

# Conexion a MySQL
DB_USER=root
DB_PASSWORD=
DB_HOST=localhost
DB_PORT=3306
DB_NAME=Chinook

# Carpeta donde el ETL deja los CSV
OUTPUT_FOLDER=output

# Excel
EXCEL_FILE=dashboard/Chinook_Dashboard.xlsx
AUTO_OPEN_EXCEL=true
```

### `.gitignore`

```text
# Credenciales
.env

# Entorno virtual
.venv/
venv/

# Python
__pycache__/
*.py[cod]

# Datos generados: se regeneran ejecutando main.py
output/*.csv

# Ficheros temporales de Excel
~$*.xlsx

# Editores
.vscode/
.idea/
```

### `src/config.py`

```python
"""Configuracion del proyecto. Todo lo que cambia de un ordenador a otro vive aqui."""

import os
from pathlib import Path

from dotenv import load_dotenv

# La raiz es la carpeta que contiene a src/. Se calcula desde este fichero, no
# desde el directorio actual, para que el proyecto funcione se lance desde donde se lance.
RAIZ = Path(__file__).resolve().parent.parent

load_dotenv(RAIZ / ".env")

# Conexion a MySQL
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "3306")
DB_NAME = os.getenv("DB_NAME", "Chinook")

# Carpetas de trabajo
CARPETA_QUERIES = RAIZ / "queries"
CARPETA_OUTPUT = RAIZ / os.getenv("OUTPUT_FOLDER", "output")

# Excel
EXCEL_FILE = RAIZ / os.getenv("EXCEL_FILE", "dashboard/Chinook_Dashboard.xlsx")
AUTO_OPEN_EXCEL = os.getenv("AUTO_OPEN_EXCEL", "false").lower() == "true"
```

### `src/limpieza.py`

```python
"""Reglas de limpieza. Cada funcion recibe un DataFrame y devuelve otro.

Regla para decidir donde va cada limpieza:
    - Si es un filtro o un valor por defecto, va en SQL (corre en el servidor).
    - Si necesita mirar el conjunto entero, o manipular texto, va aqui.
"""

import pandas as pd


def tipar_fechas(df):
    """Convierte a fecha las columnas que lo son.

    Sin esto Excel las lee como texto y no deja agrupar por mes ni por ano.
    """
    for columna in df.columns:
        if columna.startswith("fecha"):
            df[columna] = pd.to_datetime(df[columna], errors="coerce")
    return df


def marcar_duraciones_atipicas(df):
    """Marca las canciones con duracion fuera del rango intercuartilico.

    Ejemplo de regla que SQL lleva mal: necesita los cuartiles de todo el
    conjunto. Marca, no borra: una cancion larga no es un error, pero conviene
    poder excluirla de un grafico con un filtro.
    """
    q1, q3 = df["duracion_ms"].quantile([0.25, 0.75])
    rango = q3 - q1
    df["duracion_atipica"] = (df["duracion_ms"] > q3 + 1.5 * rango) | (
        df["duracion_ms"] < q1 - 1.5 * rango
    )
    return df


# Reglas que se aplican a todos los datasets.
COMUNES = [tipar_fechas]

# Reglas propias de cada dataset.
LIMPIEZA = {
    "ventas_linea": [],
    "canciones": [marcar_duraciones_atipicas],
    "clientes": [],
}


def limpiar(df, nombre):
    """Aplica las reglas comunes y las del dataset. Informa de lo que cambian."""
    for regla in COMUNES + LIMPIEZA.get(nombre, []):
        antes = len(df)
        df = regla(df)
        diferencia = antes - len(df)
        if diferencia > 0:
            print(f"    {regla.__name__}: {diferencia} filas fuera")
        elif diferencia < 0:
            print(f"    {regla.__name__}: {-diferencia} filas DE MAS, revisad la regla")
    return df
```

**Pregunta:** de las dos reglas de este fichero, ¿cuál necesita ver todo el conjunto de datos, y por qué no se puede resolver con un simple `WHERE` en SQL?

<details>
<summary>Respuesta</summary>

`marcar_duraciones_atipicas`. Para decir si una canción es atípica hay que calcular los cuartiles de **todas** las canciones, y eso depende del conjunto entero. Un `WHERE` mira una fila cada vez y no sabe cuál es el umbral. Por eso la regla vive en Python.

`tipar_fechas`, en cambio, es una conversión de tipo que no depende de ningún otro dato.

</details>

### `src/chinook_ETL.py`

```python
"""ETL de Chinook: extrae con SQL, comprueba el grano, limpia y exporta un CSV por consulta.

Las fases estan separadas a proposito:
    extraer   -> lee el .sql y lo ejecuta contra MySQL
    comprobar -> valida que el resultado tiene el grano declarado
    limpiar   -> aplica las reglas de src/limpieza.py
    exportar  -> escribe el CSV que consumira Excel

Las comprobaciones de grano son las que diferencian un ETL de un script que
escribe ficheros: si algo multiplica filas, el proceso se detiene.
"""

from urllib.parse import quote_plus

import pandas as pd
from sqlalchemy import create_engine, text

from src.config import (
    CARPETA_OUTPUT,
    CARPETA_QUERIES,
    DB_HOST,
    DB_NAME,
    DB_PASSWORD,
    DB_PORT,
    DB_USER,
)
from src.limpieza import limpiar

# Cada consulta con la columna que define su grano.
CONSULTAS = {
    # TABLA DE HECHOS: mide, y es el centro del modelo.
    "ventas_linea": "linea_id",
    # DIMENSIONES: describen, y se unen al hecho por su clave.
    "canciones": "cancion_id",
    "clientes": "cliente_id",
}


def crear_engine():
    """Devuelve el engine de SQLAlchemy a partir de las credenciales del .env."""
    if not DB_USER or not DB_PASSWORD:
        raise RuntimeError(
            "Faltan DB_USER o DB_PASSWORD en el fichero .env. "
            "Copiad .env.example como .env y rellenadlo."
        )
    # quote_plus escapa los caracteres que romperian la URL (@, #, /, ...).
    url = (
        f"mysql+mysqlconnector://{quote_plus(DB_USER)}:{quote_plus(DB_PASSWORD)}"
        f"@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    )
    return create_engine(url)


def extraer(engine, nombre):
    """Ejecuta queries/<nombre>.sql y devuelve el resultado como DataFrame."""
    ruta = CARPETA_QUERIES / f"{nombre}.sql"
    if not ruta.exists():
        raise FileNotFoundError(f"No existe la consulta {ruta}")
    # El punto y coma final sobra al enviar la consulta desde Python.
    consulta = ruta.read_text(encoding="utf-8").strip().rstrip(";")
    return pd.read_sql(text(consulta), engine)


def comprobar_grano(df, clave, nombre):
    """Detiene el proceso si la consulta no respeta el grano que declara."""
    if clave not in df.columns:
        raise KeyError(f"{nombre}: la consulta no devuelve la columna de grano '{clave}'")

    distintos = df[clave].nunique(dropna=False)
    if distintos != len(df):
        raise ValueError(
            f"{nombre}: {len(df)} filas para {distintos} valores distintos de '{clave}'. "
            "Algo esta multiplicando filas: el JOIN del .sql o una regla de limpieza."
        )


def exportar(df, nombre):
    """Escribe el CSV en output/ y devuelve la ruta."""
    CARPETA_OUTPUT.mkdir(parents=True, exist_ok=True)
    destino = CARPETA_OUTPUT / f"{nombre}.csv"
    # utf-8-sig para que Excel abra bien los acentos y las eñes.
    df.to_csv(destino, index=False, encoding="utf-8-sig")
    return destino


def ejecutar_etl():
    """Recorre todas las consultas. Devuelve {nombre: (filas, ruta del csv)}."""
    engine = crear_engine()
    resultados = {}

    for nombre, clave_de_grano in CONSULTAS.items():
        df = extraer(engine, nombre)
        comprobar_grano(df, clave_de_grano, f"{nombre} (SQL)")
        df = limpiar(df, nombre)
        comprobar_grano(df, clave_de_grano, f"{nombre} (tras limpiar)")
        resultados[nombre] = (len(df), exportar(df, nombre))

    return resultados
```

**Pregunta:** el grano se comprueba **dos veces**. ¿Qué detecta cada comprobación?

<details>
<summary>Respuesta</summary>

La primera comprueba la consulta SQL: si el JOIN del `.sql` multiplica filas, se detecta antes de tocar nada. La segunda comprueba la limpieza: si una regla de `limpieza.py` duplica filas (por ejemplo, con un `concat` mal hecho), también se detecta.

</details>

### `src/excel.py`

```python
"""Enlace entre el ETL y Excel.

Este modulo no disena nada. Hace tres cosas:
    - crea el libro si todavia no existe, con una hoja que lista las fuentes
    - nunca toca el libro si ya existe, para no pisar vuestro dashboard
    - lo abre al terminar, si AUTO_OPEN_EXCEL es true

La conexion la montais vosotros en Excel con Power Query, apuntando a los CSV
de output/. Python solo se encarga de que esos CSV esten frescos.
"""

import os

from openpyxl import Workbook

from src.config import EXCEL_FILE


def crear_libro_si_no_existe(resultados):
    """Crea el libro con una hoja Fuentes y una hoja Dashboard vacia.

    Si el fichero ya existe no se toca: a partir de la segunda ejecucion
    vuestro trabajo en Excel esta a salvo.
    """
    if EXCEL_FILE.exists():
        return False

    EXCEL_FILE.parent.mkdir(parents=True, exist_ok=True)

    libro = Workbook()
    fuentes = libro.active
    fuentes.title = "Fuentes"
    fuentes.append(["Dataset", "Filas", "Ruta del CSV"])
    for nombre, (filas, destino) in resultados.items():
        fuentes.append([nombre, filas, str(destino)])
    fuentes.column_dimensions["A"].width = 22
    fuentes.column_dimensions["B"].width = 10
    fuentes.column_dimensions["C"].width = 90

    libro.create_sheet("Dashboard")
    libro.save(EXCEL_FILE)
    return True


def abrir_libro():
    """Abre el libro. os.startfile solo existe en Windows."""
    if not EXCEL_FILE.exists():
        return
    if hasattr(os, "startfile"):
        os.startfile(str(EXCEL_FILE))
    else:
        print(f"Abrid manualmente {EXCEL_FILE}")
```

### `main.py`

```python
"""Punto de entrada del proyecto.

    python main.py

Ejecuta el ETL completo, deja un CSV por consulta en output/ y, si hace falta,
crea el libro de Excel. Se lanza desde la raiz del proyecto, no desde src/.
"""

import sys

from src.chinook_ETL import ejecutar_etl
from src.config import AUTO_OPEN_EXCEL, EXCEL_FILE, RAIZ
from src.excel import abrir_libro, crear_libro_si_no_existe


def main():
    try:
        resultados = ejecutar_etl()
    except Exception as error:
        print(f"ETL detenido: {error}")
        return 1

    print("CSV generados en output/:")
    for nombre, (filas, destino) in resultados.items():
        print(f"  {nombre:<14} {filas:>6} filas   {destino.name}")

    if crear_libro_si_no_existe(resultados):
        print(f"\nLibro creado: {EXCEL_FILE.relative_to(RAIZ)}")
        print("La hoja Fuentes lleva las rutas que necesita Power Query.")

    if AUTO_OPEN_EXCEL:
        abrir_libro()

    return 0


if __name__ == "__main__":
    sys.exit(main())
```

---

## 8. Ejecutar y comprobar

**Antes de ejecutar:** cierra cualquier CSV que tengas abierto en Excel. Si está abierto, Windows no deja sobrescribirlo y el proceso falla.

```powershell
python main.py
```

Debe salir:

```
CSV generados en output/:
  ventas_linea     2240 filas   ventas_linea.csv
  canciones        3503 filas   canciones.csv
  clientes           59 filas   clientes.csv

Libro creado: dashboard\Chinook_Dashboard.xlsx
La hoja Fuentes lleva las rutas que necesita Power Query.
```

**Cifras de control:**

| Comprobación | Cómo | Debe salir |
| :--- | :--- | ---: |
| Líneas exportadas | Filas de `ventas_linea.csv` | 2240 |
| Suma de importes | Abre `ventas_linea.csv` en Excel, selecciona la columna `importe_linea` y mira la barra de estado | 2.328,60 |
| Canciones atípicas | En `canciones.csv`, filtra `duracion_atipica` = TRUE | 357 |
| Clientes | Filas de `clientes.csv` | 59 |

**Si algo falla:**

| Mensaje | Qué revisar |
| :--- | :--- |
| `Faltan DB_USER o DB_PASSWORD` | El `.env` no existe, o le falta la contraseña |
| `Access denied` | La contraseña del `.env` no es la de tu MySQL |
| `Unknown database 'Chinook'` | No se ejecutó el script de la sección 3, o quedó en otra base |
| `Algo esta multiplicando filas` | La consulta no respeta el grano que declara. Usa la plantilla de la sección 6 para ver cuál |
| `PermissionError` al escribir el CSV | Tienes el CSV abierto en Excel. Ciérralo y repite |

---

## 9. Excel: Power Query y el modelo de datos

### 9.1 Cargar los tres CSV

Repite estos pasos para `ventas_linea.csv`, `canciones.csv` y `clientes.csv`:

1. `Datos` > `Obtener datos` > `Desde un archivo` > `Desde texto/CSV`.
2. Elige el CSV de `output/`. La ruta completa está en la hoja **Fuentes** del libro.
3. En la vista previa: origen `65001: Unicode (UTF-8)`, delimitador `Coma`.
4. `Transformar datos`. Comprueba que las fechas son **Fecha** y los importes **Número decimal**.
5. `Cerrar y cargar en...` > **Solo crear conexión**, y marca **Agregar estos datos al modelo de datos**.

> **Si los importes salen mal** (`89.90` como texto, o `8990`): en esa columna, `Transformar` > `Tipo de datos` > `Usar configuración regional` > `Inglés (Estados Unidos)` > `Número decimal`. Pasa cuando Excel está en español y el CSV usa punto decimal.

### 9.2 El calendario

`Datos` > `Obtener datos` > `Otras fuentes` > `Consulta en blanco`. En `Editor avanzado`, pega esto. Cierra y carga como **Solo crear conexión**, marcando la opción del modelo de datos:

```m
let
    Inicio = #date(2021, 1, 1),
    Fin = #date(2025, 12, 31),
    Dias = List.Dates(Inicio, Duration.Days(Fin - Inicio) + 1, #duration(1, 0, 0, 0)),
    Tabla = Table.FromList(Dias, Splitter.SplitByNothing(), {"Fecha"}),
    Tipo = Table.TransformColumnTypes(Tabla, {{"Fecha", type date}}),
    Anio = Table.AddColumn(Tipo, "Anio", each Date.Year([Fecha]), Int64.Type),
    Mes = Table.AddColumn(Anio, "Mes", each Date.Month([Fecha]), Int64.Type),
    NombreMes = Table.AddColumn(Mes, "NombreMes", each Date.MonthName([Fecha]), type text),
    AnioMes = Table.AddColumn(NombreMes, "AnioMes", each Date.ToText([Fecha], "yyyy-MM"), type text),
    Trimestre = Table.AddColumn(AnioMes, "Trimestre", each "T" & Text.From(Date.QuarterOfYear([Fecha])), type text)
in
    Trimestre
```

Los datos van del 1 de enero de 2021 al 22 de diciembre de 2025. El calendario llega hasta el 31 para que no falte ningún día.

### 9.3 Las relaciones

`Datos` > `Relaciones` > `Nueva`, tres veces. Primero la tabla del lado **varios**:

| Tabla (varios) | Columna | Tabla (uno) | Columna |
| :--- | :--- | :--- | :--- |
| `ventas_linea` | `cancion_id` | `canciones` | `cancion_id` |
| `ventas_linea` | `cliente_id` | `clientes` | `cliente_id` |
| `ventas_linea` | `fecha` | `Calendario` | `Fecha` |

**Fíjate en la última.** El calendario va **directo** al hecho, porque aquí solo hay un hecho. En el proyecto del grupo 0 va a `entregas_retrasos`, porque allí hay dos. Es la misma regla con un caso más.

**Comprobación:** el lado uno debe tener valores únicos. `canciones[cancion_id]` tiene 3503 valores distintos para 3503 filas; `clientes[cliente_id]`, 59 para 59. Si Excel rechaza una relación, casi siempre es que la has creado al revés.

### 9.4 Tres dinámicas

Inserta una tabla dinámica usando el modelo de datos (`Insertar` > `Tabla dinámica`, y marca la opción de usar el modelo de datos).

**Dinámica 1: género y año.**

- Filas: `canciones[genero]`
- Columnas: `Calendario[Anio]`
- Valores: suma de `ventas_linea[importe_linea]`

Controles: el total de **Rock** debe ser **826,65**, y el de **Latin**, **382,14**.

**Dinámica 2: los artistas que más venden.**

- Filas: `canciones[artista]`
- Valores: suma de `ventas_linea[importe_linea]`. Ordena de mayor a menor.

Control: **Iron Maiden** arriba, con **138,60**. Después, **U2**, con **105,93**.

**Dinámica 3: los países que más compran.**

- Filas: `clientes[pais]`
- Valores: suma de `ventas_linea[importe_linea]`.

Control: **USA**, con **523,06**. Después, **Canada**, con **303,96**.

**Segmentación de datos** sobre `Calendario[Anio]`: conéctala a las tres dinámicas. Si todas se mueven a la vez, las relaciones están bien.

### 9.5 Un experimento: la dirección del filtro

Crea una dinámica con filas `clientes[pais]` y valores **suma de `canciones[precio]`**.

Verás el mismo número en todos los países. Explica por qué. (Pista: no hay ningún camino entre `canciones` y `clientes`. La tabla de hechos es la única que las conecta.)

<details>
<summary>Respuesta</summary>

Las dos tablas son dimensiones y no se unen entre sí. Un filtro solo viaja por las relaciones, y aquí no hay ninguna relación entre `clientes` y `canciones`. Así que el país no filtra la suma de precios de las canciones, y sale el mismo total para todos.

La regla es: **las medidas salen de la tabla de hechos**, `ventas_linea`. Las columnas de las dimensiones sirven para ordenar y filtrar.

</details>

---

## 10. Reto opcional: canciones con duración atípica

La dirección quiere saber si las canciones con duración fuera de lo normal se venden igual que el resto. La limpieza ya lo ha marcado en la columna `duracion_atipica`.

Crea una dinámica con:

- Filas: `canciones[duracion_atipica]`
- Valores: suma de `ventas_linea[importe_linea]`, y recuento de `ventas_linea[linea_id]`.

Controles: las atípicas deben sumar **308,01** y **199** líneas. Las demás, **2.020,59** y **2.041** líneas.

**Pregunta de cierre:** las canciones atípicas son el 10% del catálogo, pero generan el 13% de la facturación. ¿Qué significa eso, y qué cautela tendrías antes de quitarlas de un análisis? Recuerda la regla de `limpieza.py`: se marcan, no se borran.

---

## 11. Errores típicos

| Síntoma | Causa probable | Qué hacer |
| :--- | :--- | :--- |
| El total de una dinámica es igual en todas las filas | Una medida sale de una dimensión, o no hay relación entre las tablas | Revisa la sección 9.5 |
| Excel no deja crear una relación | El lado uno tiene duplicados, o la relación va al revés | Revisa la sección 9.3 |
| Las fechas no agrupan por año | La columna está como Texto | Power Query > `Transformar` > `Tipo de datos` > `Fecha` |
| Los importes salen como texto, o 100 veces menos | Configuración regional | Sección 9.1 |
| `ETL detenido` con una cifra de filas | Un JOIN multiplica filas | La plantilla de la sección 6 te dice qué consulta |
| Los datos no cambian al actualizar | Excel no vuelve a leer el CSV | Ejecuta `python main.py` primero, y después `Datos` > `Actualizar todo` |

---

## 12. Entrega

- La carpeta `chinook-automatizacion` completa, con `output/` generado y **sin** `.env`.
- `dashboard/Chinook_Dashboard.xlsx` con el modelo, las tres relaciones, las tres dinámicas y la segmentación.
- En la hoja `Dashboard`, tres frases: qué género lidera y por qué crees que es, qué país pesa más, y qué cifra te ha sorprendido.

Si quieres un último reto: cambia el rango de la segmentación a un solo año y mira cómo se mueve cada dinámica. Eso es, en esencia, lo que hace un análisis.

---

## Apéndice: en qué se parece y en qué no al proyecto del grupo 0

| | Grupo 0 (Olist) | Esta guía (Chinook) |
| :--- | :--- | :--- |
| Tablas de hechos | 2: líneas y pedidos | 1: líneas |
| Dimensiones | 3, más el calendario | 2, más el calendario |
| Copo de nieve | Categoría de producto | Artista, álbum y género de cada canción |
| Limpieza | Atípicos de ingresos | Atípicos de duración |
| Pagos | Varias filas de pago por pedido, que hay que agregar | No existe esa tabla: el total está en la factura |
| Notebook de exploración | Sí | No: lo sustituye Workbench |

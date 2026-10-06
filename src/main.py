"""
Proyecto III · Flujo de datos de SQL a Python

Lee UNA de las consultas de sql/, la ejecuta contra MySQL y exporta el
resultado a data/.

Ejecutar desde la RAÍZ del proyecto:

    python src/main.py

Las funciones están declaradas pero vacías: os toca a vosotros.
Cada TODO dice qué hacer, no cómo.
"""

from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text

from config import DB_USER, DB_PASSWORD, DB_HOST, DB_NAME

RAIZ = Path(__file__).resolve().parent.parent
SQL = RAIZ / "sql"
DATA = RAIZ / "data"


# ---------------------------------------------------------------------------
# CONFIGURACIÓN DEL EQUIPO · rellenad estas tres líneas antes de programar
# ---------------------------------------------------------------------------

# ¿Cuál de las tres consultas lleváis hasta el CSV?
CONSULTA = "df3_vendedores_popularidad.sql"

# El grano, en lenguaje de negocio. Ejemplo: "un pedido entregado"
GRANO = "Nivel de Vendedor"

# La columna que identifica una fila según ese grano. Ejemplo: "order_id"
# Sirve para comprobar que el JOIN no está multiplicando filas.
CLAVE_DE_GRANO = "seller_id, product_id"


# ---------------------------------------------------------------------------


def conection_bd():
    """Crea el motor de conexión a MySQL con las credenciales del .env."""
    # 1. Construir la URL de conexión completa
    url = f"mysql+mysqlconnector://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_NAME}"
    # 2. Crear el objeto 'motor' (engine) usando la URL
    engine = create_engine(url)
    return engine.connect()

def test_connection():
    """Probar la conexión a la base de datos"""
    connection = conection_bd()
    try:
        with connection:
            print("Conexión exitosa a la base de datos.")
            result = connection.execute(text("SELECT * FROM products;"))
            print(result.fetchone())

    except Exception as e:
        print(f"Error al conectar a la base de datos: {e}")
        

def leer_consulta():
    connection = conection_bd()
    
    join_query_sql = """ 
        SELECT
            v.seller_id,
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
    """

    # ✅ Ejecutar y extraer los datos dentro del bloque with
    with connection:
        result = connection.execute(text(join_query_sql))
        rows = result.fetchall()
        columns = result.keys()

    # Ahora sí puedes construir el DataFrame
    df = pd.DataFrame(rows, columns=columns)
            
    df.to_csv(
        "data/df3_vendedores_productos.csv",
        index=False,
        encoding='utf-8'
    )

    print("✅ DataFrame successfully created and saved to data/df3_vendedores_productos.csv")
    return df

#def ejecutar(engine, consulta_sql):
    """Ejecuta la consulta y devuelve un DataFrame de pandas."""
    # TODO: abrir una conexión y leer el resultado en un DataFrame
    #       Pista: pandas sabe hablar con SQLAlchemy directamente
    raise NotImplementedError("ejecutar")


#def comprobar_grano(df):
    """Avisa si el número de filas no cuadra con el grano declarado.

    Si el grano es 'un pedido', entonces debe cumplirse que
    len(df) == número de order_id distintos. Si no cuadra, el JOIN
    está duplicando filas y todas vuestras sumas serán mayores de lo real.
    """
    # TODO: comparar el total de filas con el de valores únicos de
    #       CLAVE_DE_GRANO, e imprimir un aviso claro si no coinciden
    raise NotImplementedError("comprobar_grano")


#def exportar(df, nombre_csv):
    """Guarda el DataFrame en data/ como CSV."""
    DATA.mkdir(exist_ok=True)  # por si la carpeta no existe todavía
    # TODO: exportar a DATA / nombre_csv
    #       Cuidado con dos cosas: el índice y la codificación de los acentos
    raise NotImplementedError("exportar")


#def main():
    if not GRANO or not CLAVE_DE_GRANO:
        raise SystemExit(
            "Antes de ejecutar: rellenad GRANO y CLAVE_DE_GRANO arriba.\n"
            "Si no sabéis qué poner, aún no estáis listos para escribir el JOIN."
        )

    print(f"Consulta ....... {CONSULTA}")
    print(f"Grano .......... una fila = {GRANO}")

    engine = conection_bd()
    consulta_sql = leer_consulta(CONSULTA)
    df = ejecutar(engine, consulta_sql)

    print(f"Filas .......... {len(df):,}")
    print(f"Columnas ....... {df.shape[1]}")

    comprobar_grano(df)
    exportar(df, CONSULTA.replace(".sql", ".csv"))


if __name__ == "__main__":
    test_connection()
    leer_consulta()

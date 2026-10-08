"""Donde aterriza la limpieza que traeis del Proyecto III.

Una celda de notebook se convierte en funcion con dos cambios: un `def` arriba
y un `return` abajo. El cuerpo no se toca.

    # Proyecto III, celda del notebook
    df = df[df["precio"] > 0]
    df["ciudad"] = df["ciudad"].str.strip()

    # Proyecto IV, funcion
    def quitar_precios_a_cero(df):
        df = df[df["precio"] > 0]
        df["ciudad"] = df["ciudad"].str.strip()
        return df

Despues se registra en LIMPIEZA, debajo del dataset al que se aplica. El ETL
la ejecuta sola en cada pasada.

Regla para decidir donde va cada limpieza:
    - Si es un filtro o un valor por defecto, va en SQL. Corre en el servidor
      y reduce lo que viaja por la red.
    - Si necesita mirar el conjunto entero (atipicos, medias, percentiles) o
      manipular texto, va aqui.
"""

import pandas as pd


def tipar_fechas(df):
    """Las columnas de fecha de DF1 terminan en _date, _timestamp o _at."""
    for col in df.columns:
        if col.endswith(("_date", "_timestamp", "_at")):
            df[col] = pd.to_datetime(df[col], errors="coerce")
    return df

def marcar_vendedores_atipicos(df):
    """Marca (no borra) vendedores con unidades fuera del rango IQR.
    En el P3 decidimos no suprimirlos: son los best-sellers."""
    q1, q3 = df["unidades_vendidas"].quantile([0.25, 0.75])
    techo = q3 + 1.5 * (q3 - q1)
    df["vendedor_atipico"] = df["unidades_vendidas"] > techo
    return df

def cuota_de_mercado(df):
    """Porcentaje de unidades del marketplace que vende cada vendedor."""
    df["pct_unidades_total"] = (
        df["unidades_vendidas"] / df["unidades_vendidas"].sum() * 100
    ).round(4)
    return df

# Reglas que se aplican a todos los datasets.
COMUNES = [tipar_fechas]

# Reglas propias de cada dataset. Aqui van las vuestras del Proyecto III.
LIMPIEZA = {
    "df1_actividad_clientes": [tipar_fechas],
    "df2_catalogo_productos": [],
    "df3_vendedores": [marcar_vendedores_atipicos, cuota_de_mercado],
}


# Si algun equipo usa la tabla geolocation, es la unica de Olist que esta
# sucia de verdad y el sitio natural para tres reglas mas: quitar las 261.831
# filas duplicadas exactas, normalizar las tildes de geolocation_city (2.073
# ciudades son la misma escrita de dos formas) y descartar las 42 coordenadas
# que caen fuera de Brasil.


def limpiar(df, nombre):
    """Aplica las reglas comunes y las del dataset. Informa de lo que quitan."""
    for regla in COMUNES + LIMPIEZA.get(nombre, []):
        antes = len(df)
        df = regla(df)
        diferencia = antes - len(df)
        if diferencia > 0:
            print(f"    {regla.__name__}: {diferencia} filas fuera")
        elif diferencia < 0:
            print(f"    {regla.__name__}: {-diferencia} filas DE MAS, revisad la regla")
    return df

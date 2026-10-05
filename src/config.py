"""
Credenciales de la base de datos.

Este fichero NO contiene ninguna contraseña: las lee del `.env`, que no se
sube al repositorio. Si te falta el `.env`, copia `.env_example` y rellénalo.

Aquí no hace falta tocar nada.
"""

import os
from pathlib import Path

from dotenv import load_dotenv

# La raíz del proyecto es la carpeta que contiene a src/.
# Calcularla así hace que funcione lo lances desde donde lo lances.
RAIZ = Path(__file__).resolve().parent.parent

load_dotenv(RAIZ / ".env")

DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME", "olist")

_faltan = [
    nombre
    for nombre, valor in (
        ("DB_USER", DB_USER),
        ("DB_PASSWORD", DB_PASSWORD),
        ("DB_HOST", DB_HOST),
        ("DB_NAME", DB_NAME),
    )
    if not valor
]

if _faltan:
    raise RuntimeError(
        f"Faltan variables en el .env: {', '.join(_faltan)}.\n"
        "Copia .env_example a .env y rellena tus credenciales."
    )

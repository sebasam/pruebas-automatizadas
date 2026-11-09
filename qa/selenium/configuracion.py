"""Parámetros de ejecución. Se pueden cambiar con variables de entorno."""
import os

URL_BASE = os.environ.get("SIGR_URL", "http://localhost:3601")
NAVEGADOR_BINARIO = os.environ.get("CHROME_BIN", "/opt/pw-browsers/chromium-1194/chrome-linux/chrome")
ESPERA_SEGUNDOS = 5
CARPETA_CAPTURAS = os.path.join(os.path.dirname(__file__), "capturas")


def ruta_driver():
    """Usa el driver indicado por CHROMEDRIVER o el que trae el paquete chromedriver-py."""
    if os.environ.get("CHROMEDRIVER"):
        return os.environ["CHROMEDRIVER"]
    from chromedriver_py import binary_path
    return binary_path

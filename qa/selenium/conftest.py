"""Fixtures de pytest: navegador, capturas de pantalla y servidor del SIGR."""
import os
import re
import shutil
import subprocess
import tempfile
import time
import urllib.request

import pytest
from selenium import webdriver
from selenium.webdriver.chrome.service import Service

import configuracion as cfg

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def _esperar_servicio(url, intentos=50):
    for _ in range(intentos):
        try:
            urllib.request.urlopen(url + "/salud", timeout=1)
            return True
        except Exception:
            time.sleep(0.1)
    return False


@pytest.fixture(scope="session", autouse=True)
def servidor():
    """Levanta el SIGR con una base limpia, salvo que SIGR_EXTERNO=1 (ya hay uno corriendo)."""
    if os.environ.get("SIGR_EXTERNO") == "1":
        yield
        return
    puerto = cfg.URL_BASE.rsplit(":", 1)[1]
    tmp = tempfile.mkdtemp()
    env = dict(os.environ, SIGR_DB=os.path.join(tmp, "db.json"), PORT=puerto)
    subprocess.run(["node", "src/seed.js"], cwd=RAIZ, env=env, check=True, stdout=subprocess.DEVNULL)
    proceso = subprocess.Popen(["node", "src/server.js"], cwd=RAIZ, env=env,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    assert _esperar_servicio(cfg.URL_BASE), "El SIGR no arrancó"
    yield
    proceso.terminate()
    proceso.wait(timeout=5)
    shutil.rmtree(tmp, ignore_errors=True)


@pytest.fixture
def driver():
    opciones = webdriver.ChromeOptions()
    opciones.binary_location = cfg.NAVEGADOR_BINARIO
    for arg in ("--headless=new", "--no-sandbox", "--disable-dev-shm-usage", "--window-size=1000,900", "--lang=es"):
        opciones.add_argument(arg)
    d = webdriver.Chrome(service=Service(cfg.ruta_driver()), options=opciones)
    yield d
    d.quit()


def _nombre_seguro(texto):
    return re.sub(r"[^A-Za-z0-9_-]+", "_", texto).strip("_")[:70]


@pytest.fixture
def capturar(driver, request):
    """Devuelve una función que guarda una captura con el nombre de la prueba."""
    os.makedirs(cfg.CARPETA_CAPTURAS, exist_ok=True)

    def _capturar(etiqueta=""):
        nombre = _nombre_seguro(request.node.name + ("_" + etiqueta if etiqueta else "")) + ".png"
        driver.save_screenshot(os.path.join(cfg.CARPETA_CAPTURAS, nombre))
    return _capturar


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    """Si una prueba falla guarda una captura automática para el diagnóstico."""
    resultado = (yield).get_result()
    if resultado.when == "call" and resultado.failed and "driver" in item.funcargs:
        os.makedirs(cfg.CARPETA_CAPTURAS, exist_ok=True)
        item.funcargs["driver"].save_screenshot(
            os.path.join(cfg.CARPETA_CAPTURAS, "FALLO_" + _nombre_seguro(item.name) + ".png"))

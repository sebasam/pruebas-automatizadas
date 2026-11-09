"""Clase base del patrón Page Object: reúne las acciones comunes de cualquier página."""
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

import configuracion as cfg


class PaginaBase:
    RUTA = "/"

    def __init__(self, driver):
        self.driver = driver
        self.espera = WebDriverWait(driver, cfg.ESPERA_SEGUNDOS)

    def abrir(self):
        self.driver.get(cfg.URL_BASE + self.RUTA)
        return self

    def escribir(self, id_campo, texto):
        """Limpia el campo y escribe el texto; si el dato es None deja el campo vacío."""
        campo = self.espera.until(EC.visibility_of_element_located((By.ID, id_campo)))
        campo.clear()
        if texto:
            campo.send_keys(texto)

    def pulsar(self, id_boton):
        self.espera.until(EC.element_to_be_clickable((By.ID, id_boton))).click()

    def mensaje(self):
        """Espera a que aparezca el aviso de resultado y devuelve (texto, clase CSS)."""
        el = self.espera.until(EC.visibility_of_element_located((By.ID, "mensaje")))
        return el.text, el.get_attribute("class")

    def titulo_h1(self):
        return self.driver.find_element(By.TAG_NAME, "h1").text

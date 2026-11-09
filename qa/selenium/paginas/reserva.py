from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import Select

from paginas.base import PaginaBase


class PaginaReserva(PaginaBase):
    RUTA = "/ui/reserva.html"

    def reservar(self, cliente, fecha, hora, personas, mesa):
        self.escribir("cliente", cliente)
        self._fijar_valor("fecha", fecha)
        self._fijar_valor("hora", hora)
        self.escribir("personas", str(personas) if personas not in (None, "") else "")
        Select(self.driver.find_element(By.ID, "mesa")).select_by_value(str(mesa))
        self.pulsar("enviar")
        return self.mensaje()

    def _fijar_valor(self, id_campo, valor):
        """Los campos date/time dependen del idioma del navegador; se fija el valor por JavaScript."""
        campo = self.driver.find_element(By.ID, id_campo)
        self.driver.execute_script(
            "arguments[0].value = arguments[1];", campo, valor or "")

    def opciones_de_mesa(self):
        return [o.text for o in Select(self.driver.find_element(By.ID, "mesa")).options]

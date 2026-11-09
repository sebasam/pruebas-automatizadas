"""Pruebas del formulario de inicio de sesión (datos de entrada -> resultado esperado)."""
import pytest

from paginas.login import PaginaLogin

CASOS = [
    pytest.param("admin@sigr.local", "Admin12345", True, "Bienvenido, Administrador (administrador)", id="administrador"),
    pytest.param("mesero@sigr.local", "Mesero12345", True, "Bienvenido, Mesero 1 (mesero)", id="mesero"),
    pytest.param("admin@sigr.local", "clave-mala", False, "Credenciales invalidas.", id="clave_incorrecta"),
    pytest.param("nadie@sigr.local", "Admin12345", False, "Credenciales invalidas.", id="correo_inexistente"),
    pytest.param("admin@sigr.local", "", False, "Credenciales invalidas.", id="clave_vacia"),
    pytest.param("", "", False, "Credenciales invalidas.", id="formulario_vacio"),
]


def test_la_pagina_carga_con_sus_campos(driver, capturar):
    pagina = PaginaLogin(driver).abrir()
    assert pagina.titulo_h1() == "Iniciar sesión"
    assert driver.title == "SIGR - Iniciar sesión"
    assert driver.find_element("id", "clave").get_attribute("type") == "password"
    capturar("inicial")


@pytest.mark.parametrize("email,clave,exito,texto", CASOS)
def test_inicio_de_sesion(driver, capturar, email, clave, exito, texto):
    texto_obtenido, clases = PaginaLogin(driver).abrir().iniciar_sesion(email, clave)
    assert texto_obtenido == texto
    assert ("ok" in clases.split()) is exito
    assert ("error" in clases.split()) is (not exito)
    capturar("resultado")

"""Pruebas del formulario de reservas: caso feliz, validaciones y reglas de negocio."""
import pytest

from paginas.reserva import PaginaReserva


def test_el_formulario_ofrece_diez_mesas(driver, capturar):
    pagina = PaginaReserva(driver).abrir()
    opciones = pagina.opciones_de_mesa()
    assert opciones[0] == "Mesa 1" and opciones[-1] == "Mesa 10"
    assert len(opciones) == 10
    capturar("inicial")


def test_reserva_exitosa_muestra_confirmacion(driver, capturar):
    texto, clases = PaginaReserva(driver).abrir().reservar("Laura Gómez", "2027-03-10", "19:30", 4, 2)
    assert "ok" in clases.split()
    assert texto.startswith("Reserva confirmada: número ")
    assert "mesa 2, 2027-03-10 19:30" in texto
    capturar("confirmada")


def test_misma_mesa_y_horario_es_rechazada(driver, capturar):
    pagina = PaginaReserva(driver).abrir()
    pagina.reservar("Primero", "2027-03-11", "20:00", 2, 6)
    pagina.abrir()
    texto, clases = pagina.reservar("Segundo", "2027-03-11", "20:00", 2, 6)
    assert "error" in clases.split()
    assert texto == "La mesa ya esta reservada en ese horario."
    capturar("duplicada")


def test_horario_solapado_es_rechazado_pero_el_siguiente_turno_no(driver):
    pagina = PaginaReserva(driver).abrir()
    pagina.reservar("Turno 1", "2027-03-12", "20:00", 2, 7)
    pagina.abrir()
    texto, _ = pagina.reservar("Turno 2", "2027-03-12", "21:00", 2, 7)
    assert texto == "La mesa ya esta reservada en ese horario."
    pagina.abrir()
    texto, clases = pagina.reservar("Turno 3", "2027-03-12", "22:00", 2, 7)
    assert "ok" in clases.split(), texto


# cliente, fecha, hora, personas, mensaje esperado
INVALIDOS = [
    pytest.param("", "2027-04-01", "20:00", 2, "El nombre del cliente es obligatorio.", id="sin_nombre"),
    pytest.param("Ana", "2027-04-01", "20:00", 0, "El numero de personas debe estar entre 1 y 12.", id="cero_personas"),
    pytest.param("Ana", "2027-04-01", "20:00", 13, "El numero de personas debe estar entre 1 y 12.", id="trece_personas"),
    pytest.param("Ana", "2027-04-01", "20:00", "", "El numero de personas debe estar entre 1 y 12.", id="personas_vacio"),
    pytest.param("Ana", "", "20:00", 2, "La fecha debe tener el formato AAAA-MM-DD.", id="sin_fecha"),
    pytest.param("Ana", "2027-04-01", "", 2, "La hora debe tener el formato HH:MM.", id="sin_hora"),
]


@pytest.mark.parametrize("cliente,fecha,hora,personas,esperado", INVALIDOS)
def test_datos_invalidos_muestran_el_error(driver, capturar, cliente, fecha, hora, personas, esperado):
    texto, clases = PaginaReserva(driver).abrir().reservar(cliente, fecha, hora, personas, 1)
    assert "error" in clases.split()
    assert texto == esperado
    capturar("error")


@pytest.mark.parametrize("personas,fecha", [(1, "2027-05-01"), (12, "2027-05-02")])
def test_valores_limite_de_personas_se_aceptan(driver, personas, fecha):
    # Cada caso usa su propia fecha para que las reservas no dependan unas de otras.
    texto, clases = PaginaReserva(driver).abrir().reservar(f"Límite {personas}", fecha, "12:00", personas, 9)
    assert "ok" in clases.split(), texto


def test_navegacion_entre_formularios(driver):
    PaginaReserva(driver).abrir()
    driver.find_element("link text", "Iniciar sesión").click()
    PaginaReserva(driver).espera.until(lambda d: d.current_url.endswith("/ui/login.html"))
    assert driver.find_element("tag name", "h1").text == "Iniciar sesión"

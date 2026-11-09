from paginas.base import PaginaBase


class PaginaLogin(PaginaBase):
    RUTA = "/ui/login.html"

    def iniciar_sesion(self, email, clave):
        self.escribir("email", email)
        self.escribir("clave", clave)
        self.pulsar("enviar")
        return self.mensaje()

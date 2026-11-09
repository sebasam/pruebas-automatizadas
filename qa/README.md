# Pruebas automatizadas del SIGR

Dos conjuntos de pruebas sobre el mismo sistema:

| Área | Herramienta | Carpeta | Qué prueba |
|---|---|---|---|
| API REST | Postman + Newman | `postman/` | 3 colecciones: flujo funcional (45 peticiones), registro y login guiados por datos |
| Formularios web | Selenium WebDriver (Python + pytest) | `selenium/` | Formulario de inicio de sesión y formulario de reservas |

## Requisitos
Node.js 22, Python 3.10+, Chrome o Chromium.

## Ejecución
```bash
# API (levanta el SIGR en el puerto 3600 con base limpia)
cd qa && npm install && bash run_api.sh

# Formularios web (levanta el SIGR en el puerto 3601)
cd qa/selenium && pip install -r requirements.txt
python3 -m pytest --html=resultados.html --self-contained-html
```
Variables útiles: `SIGR_URL`, `SIGR_EXTERNO=1` (usar un servidor ya iniciado), `CHROME_BIN`, `CHROMEDRIVER`.
El driver debe coincidir con la versión mayor del navegador; `chromedriver-py` 141 corresponde a Chromium 141.

## Estructura de Selenium
- `paginas/`: patrón Page Object (una clase por página; los selectores viven solo ahí).
- `pruebas/`: casos de prueba; los datos de entrada se declaran con `pytest.mark.parametrize`.
- `conftest.py`: servidor, navegador y capturas (también automáticas ante un fallo).

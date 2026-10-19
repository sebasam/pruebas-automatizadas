# Registro de cambios

Formato basado en *Keep a Changelog*. Versionado semántico.

## [1.1.0] - Automatización del pipeline CI/CD

### Añadido
- Pipeline de ocho etapas en `scripts/pipeline.sh`: preparación, construcción, pruebas con cobertura, seguridad, rendimiento, empaquetado, despliegue a staging y pruebas de humo con reversión automática.
- Prueba de carga ligera (`scripts/carga.js`).
- Flujo de GitHub Actions (`.github/workflows/ci-cd.yml`) y `Jenkinsfile` que usan las mismas etapas.
- Ruta `/salud` informa el commit desplegado.
- Archivo `package-lock.json` y lista `files` en `package.json` para el empaquetado.
- Documentación del pipeline en `docs/PIPELINE.md`.
- Verificación del contenido del artefacto antes de desplegarlo.

## [1.0.0] - Línea base (etiqueta `v1.0.0-linea-base`)

### Añadido
- Estructura inicial del proyecto, licencia MIT y archivo `.gitignore`.
- Almacén de datos en memoria con persistencia opcional en archivo JSON.
- Módulo de autenticación: registro con clave cifrada (scrypt), inicio de sesión con token y control de acceso por rol.
- Módulo de menú digital: CRUD de categorías y platos con validación de precio y categoría.
- Módulo de pedidos: cálculo del total, estados ordenados (recibido, en preparación, listo, entregado, pagado) y consulta por estado.
- Módulo de reservas: validación de fecha, hora y personas; bloqueo de mesas por franja de dos horas; cancelación.
- Módulo de caja: reporte diario de ventas por plato y cierre de caja único por fecha.
- Servidor HTTP con las rutas de la API y manejo uniforme de errores.
- Datos iniciales (`npm run seed`).
- 18 pruebas automáticas: unitarias por módulo y de integración (flujo completo por HTTP).
- Documentación: README, estructura de base de datos, manual de despliegue y convenciones.

### Limitaciones conocidas (fuera de la línea base)
- Sin interfaz gráfica; solo API.
- Persistencia en archivo JSON; no hay motor de base de datos relacional.
- Sin seguimiento de pedidos por conexión persistente (se consulta periódicamente).
- Las sesiones se guardan en memoria y se pierden al reiniciar el servidor.

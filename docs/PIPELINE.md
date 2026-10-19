# Pipeline CI/CD del SIGR

El pipeline se define una sola vez en `scripts/pipeline.sh` y se puede ejecutar en local, en GitHub Actions (`.github/workflows/ci-cd.yml`) o en Jenkins (`Jenkinsfile`). Los dos archivos de plataforma solo llaman a la etapa correspondiente del script.

## Etapas

| N.º | Etapa | Qué hace | Criterio para continuar |
|---|---|---|---|
| 1 | Preparación | Muestra rama y commit; exige un repositorio sin cambios sin confirmar | Árbol de trabajo limpio |
| 2 | Construcción | Verifica la sintaxis de todos los archivos y genera `build-info.json` | Sin errores de sintaxis |
| 3 | Pruebas y cobertura | `node --test` con cobertura sobre `src/` | Todas las pruebas aprobadas y cobertura de líneas ≥ 80 % |
| 4 | Seguridad | Búsqueda de secretos en el código y `npm audit` | Sin secretos y sin vulnerabilidades altas o críticas |
| 5 | Rendimiento | Prueba de carga ligera (`scripts/carga.js`) | 0 errores y p95 ≤ 200 ms |
| 6 | Empaquetado | `npm pack` y suma SHA-256 | Artefacto generado y con todos los archivos obligatorios |
| 7 | Despliegue a staging | Instala el artefacto en una release nueva y cambia el enlace `current` | Servicio iniciado |
| 8 | Pruebas de humo | `/salud` con el commit esperado, `/menu` y control de acceso | Respuestas esperadas; si fallan, reversión automática |

## Variables

| Variable | Uso | Valor por defecto |
|---|---|---|
| `STAGING_DIR` | Carpeta del entorno de staging | `/tmp/sigr-staging` |
| `STAGING_PORT` | Puerto del servicio en staging | `3500` |
| `UMBRAL_COBERTURA` | Cobertura mínima de líneas (%) | `80` |
| `UMBRAL_P95_MS` | Latencia p95 máxima (ms) | `200` |

## Uso

```bash
npm run pipeline               # todas las etapas
bash scripts/pipeline.sh probar  # una sola etapa
```

#!/usr/bin/env bash
# Pipeline CI/CD del SIGR.
# Uso: scripts/pipeline.sh [todo|construir|probar|seguridad|rendimiento|empaquetar|desplegar|humo]
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

STAGING="${STAGING_DIR:-/tmp/sigr-staging}"
PUERTO="${STAGING_PORT:-3500}"
UMBRAL_COBERTURA="${UMBRAL_COBERTURA:-80}"
export UMBRAL_P95_MS="${UMBRAL_P95_MS:-200}"
DIST="$RAIZ/dist"
mkdir -p "$DIST"

COMMIT_CORTO="$(git rev-parse --short=7 HEAD)"
RAMA="$(git rev-parse --abbrev-ref HEAD)"
info() { echo "[$(date +%H:%M:%S)]     $*"; }

# ---------------------------------------------------------------- etapas
etapa_preparar() {
  info "Rama: $RAMA | commit: $COMMIT_CORTO | $(git log -1 --format=%s)"
  info "Node $(node -v) | npm $(npm -v)"
  if [ -n "$(git status --porcelain)" ]; then
    info "Hay cambios sin confirmar en el repositorio; el pipeline solo corre sobre commits."
    return 1
  fi
}

etapa_construir() {
  local n=0 f
  for f in src/*.js src/modules/*.js scripts/carga.js; do
    node --check "$f" || return 1
    n=$((n + 1))
  done
  info "Sintaxis verificada en $n archivos"
  local version
  version="$(node -p "require('./package.json').version")"
  printf '{"version":"%s","commit":"%s","fecha":"%s"}\n' "$version" "$COMMIT_CORTO" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > build-info.json
  info "Generado build-info.json (versión $version, commit $COMMIT_CORTO)"
}

etapa_probar() {
  node --test --experimental-test-coverage --test-coverage-include="src/**" "test/*.test.js" > "$DIST/pruebas.log" 2>&1
  local rc=$?
  info "Pruebas: $(grep -E '^# tests' "$DIST/pruebas.log" | sed 's/# tests //') ejecutadas, $(grep -E '^# pass' "$DIST/pruebas.log" | sed 's/# pass //') aprobadas, $(grep -E '^# fail' "$DIST/pruebas.log" | sed 's/# fail //') fallidas"
  if [ $rc -ne 0 ]; then
    grep -E '^not ok' "$DIST/pruebas.log" | while IFS= read -r l; do info "$l"; done
    grep -E '^ +(expected|actual):' "$DIST/pruebas.log" | head -6 | while IFS= read -r l; do info "  $(echo "$l" | sed 's/^ *//')"; done
    return 1
  fi
  local cob
  cob="$(grep -E 'all files' "$DIST/pruebas.log" | awk -F'|' '{gsub(/ /,"",$2); print $2}')"
  info "Cobertura de líneas en src/: ${cob} % (umbral ${UMBRAL_COBERTURA} %)"
  awk -v c="$cob" -v u="$UMBRAL_COBERTURA" 'BEGIN{exit !(c+0>=u+0)}' || { info "Cobertura por debajo del umbral."; return 1; }
}

etapa_seguridad() {
  local patron='(password|passwd|clave|secret|token|api[_-]?key)[a-z_]*[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{6,}["'"'"']'
  local hallazgos
  hallazgos="$(grep -rnEi "$patron" src --include='*.js' --exclude='seed.js' || true)"
  if [ -n "$hallazgos" ]; then
    info "Posibles secretos escritos en el código:"
    echo "$hallazgos" | while IFS= read -r l; do info "  $l"; done
    return 1
  fi
  info "Búsqueda de secretos en src/: sin hallazgos (se excluye seed.js, datos de demostración)"
  if timeout 60 npm audit --audit-level=high > "$DIST/audit.log" 2>&1; then
    info "npm audit: $(tail -1 "$DIST/audit.log")"
  else
    info "npm audit encontró vulnerabilidades de nivel alto o crítico:"
    tail -5 "$DIST/audit.log" | while IFS= read -r l; do info "  $l"; done
    return 1
  fi
}

etapa_rendimiento() {
  node scripts/carga.js | while IFS= read -r l; do info "$l"; done
  return "${PIPESTATUS[0]}"
}

etapa_empaquetar() {
  rm -f "$DIST"/*.tgz "$DIST"/*.sha256
  npm pack --pack-destination "$DIST" --silent > "$DIST/pack.txt" 2>&1 || { cat "$DIST/pack.txt"; return 1; }
  local nombre
  nombre="$(tail -1 "$DIST/pack.txt")"
  ( cd "$DIST" && sha256sum "$nombre" > "$nombre.sha256" )
  info "Artefacto: $nombre ($(du -h "$DIST/$nombre" | cut -f1)) con $(tar -tzf "$DIST/$nombre" | wc -l) archivos"
  info "SHA-256: $(cut -c1-16 "$DIST/$nombre.sha256")..."
}

artefacto() { ls -1t "$DIST"/*.tgz 2>/dev/null | head -1; }

detener_servicio() {
  if [ -f "$STAGING/sigr.pid" ]; then
    kill "$(cat "$STAGING/sigr.pid")" 2>/dev/null
    sleep 0.5
    rm -f "$STAGING/sigr.pid"
  fi
}

iniciar_servicio() {
  ( cd "$STAGING/current" && SIGR_DB="$STAGING/shared/db.json" PORT="$PUERTO" nohup node src/server.js > "$STAGING/servicio.log" 2>&1 & echo $! > "$STAGING/sigr.pid" )
  local i
  for i in $(seq 1 20); do
    curl -sf -m 1 "http://localhost:$PUERTO/salud" > /dev/null 2>&1 && return 0
    kill -0 "$(cat "$STAGING/sigr.pid")" 2>/dev/null || return 0
    sleep 0.25
  done
}

etapa_desplegar() {
  local art
  art="$(artefacto)"
  [ -n "$art" ] || { info "No hay artefacto; ejecute antes la etapa de empaquetado."; return 1; }
  mkdir -p "$STAGING/releases" "$STAGING/shared"
  local rel="$STAGING/releases/$(date +%Y%m%d%H%M%S)-$COMMIT_CORTO"
  mkdir -p "$rel"
  tar -xzf "$art" -C "$rel" --strip-components=1 || return 1
  if [ -L "$STAGING/current" ]; then
    ln -sfn "$(readlink "$STAGING/current")" "$STAGING/previous"
    info "Versión previa conservada: $(basename "$(readlink "$STAGING/previous")")"
  fi
  detener_servicio
  ln -sfn "$rel" "$STAGING/current"
  iniciar_servicio
  info "Release desplegada: $(basename "$rel") (puerto $PUERTO)"
}

etapa_humo() {
  local r
  if ! r="$(curl -s -m 3 "http://localhost:$PUERTO/salud")" || [ -z "$r" ]; then
    info "El servicio no responde en el puerto $PUERTO"
    tail -4 "$STAGING/servicio.log" 2>/dev/null | while IFS= read -r l; do info "  registro: $l"; done
    return 1
  fi
  info "GET /salud -> $r"
  echo "$r" | grep -q "\"commit\":\"$COMMIT_CORTO\"" || { info "El servicio responde con una versión distinta a $COMMIT_CORTO"; return 1; }
  local c1 c2
  c1="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PUERTO/menu")"
  c2="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PUERTO/reportes/ventas?fecha=2026-01-01")"
  info "GET /menu -> $c1 (esperado 200) | GET /reportes/ventas sin sesión -> $c2 (esperado 401)"
  [ "$c1" = "200" ] && [ "$c2" = "401" ]
}

revertir() {
  info "Reversión automática a la versión previa..."
  if [ ! -L "$STAGING/previous" ]; then info "No existe una versión previa a la cual volver."; return 1; fi
  detener_servicio
  ln -sfn "$(readlink "$STAGING/previous")" "$STAGING/current"
  iniciar_servicio
  local r
  if r="$(curl -s -m 3 "http://localhost:$PUERTO/salud")" && [ -n "$r" ]; then
    info "Servicio restaurado: $r"
  else
    info "No se pudo restaurar la versión previa."
    return 1
  fi
}

# ---------------------------------------------------------------- orquestación
ORDEN=(preparar construir probar seguridad rendimiento empaquetar desplegar humo)
declare -A TITULO=(
  [preparar]="Preparación (checkout)" [construir]="Construcción (build)" [probar]="Pruebas y cobertura (test)"
  [seguridad]="Seguridad" [rendimiento]="Rendimiento" [empaquetar]="Empaquetado"
  [desplegar]="Despliegue a staging (deploy)" [humo]="Pruebas de humo"
)
declare -A ESTADO DURACION

ejecutar() {
  local e="$1" t0 t1
  echo "[$(date +%H:%M:%S)] ▶ ${TITULO[$e]}"
  t0="$(date +%s.%N)"
  if "etapa_$e"; then ESTADO[$e]="OK"; else ESTADO[$e]="FALLO"; fi
  t1="$(date +%s.%N)"
  DURACION[$e]="$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.1f", b-a}')"
  echo "[$(date +%H:%M:%S)] ■ ${TITULO[$e]}: ${ESTADO[$e]} (${DURACION[$e]} s)"
  [ "${ESTADO[$e]}" = "OK" ]
}

resumen() {
  echo
  echo "RESUMEN DEL PIPELINE  rama=$RAMA  commit=$COMMIT_CORTO"
  printf '  %-34s %-9s %s\n' "Etapa" "Estado" "Duración"
  local e
  for e in "${ORDEN[@]}"; do
    printf '  %-34s %-9s %s\n' "${TITULO[$e]}" "${ESTADO[$e]:-OMITIDA}" "${DURACION[$e]:+${DURACION[$e]} s}"
  done
  [ -n "${REVERSION:-}" ] && printf '  %-34s %-9s\n' "Reversión automática" "$REVERSION"
}

modo="${1:-todo}"
if [ "$modo" = "todo" ]; then
  fallo=""
  for e in "${ORDEN[@]}"; do
    if ! ejecutar "$e"; then
      fallo="$e"
      break
    fi
  done
  if [ "$fallo" = "humo" ]; then
    if revertir; then REVERSION="OK"; else REVERSION="FALLO"; fi
  fi
  resumen
  if [ -z "$fallo" ]; then echo "RESULTADO FINAL: ÉXITO"; exit 0; fi
  echo "RESULTADO FINAL: FALLO en la etapa '${TITULO[$fallo]}'"
  exit 1
fi
if [[ " ${ORDEN[*]} " == *" $modo "* ]]; then
  ejecutar "$modo"
  exit $?
fi
echo "Etapa desconocida: $modo"; exit 2

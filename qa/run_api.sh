#!/usr/bin/env bash
# Levanta el SIGR con una base de datos limpia, ejecuta las colecciones de Postman con Newman y apaga el servicio.
set -u
AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(dirname "$AQUI")"
PUERTO="${PUERTO:-3600}"
TMP="$(mktemp -d)"
export SIGR_DB="$TMP/db.json" PORT="$PUERTO"
cd "$RAIZ"
node src/seed.js > /dev/null
setsid bash -c 'echo $$ > "$0"; exec node src/server.js' "$TMP/pid" > "$TMP/servicio.log" 2>&1 < /dev/null &
for _ in $(seq 1 50); do curl -s "http://localhost:$PUERTO/salud" > /dev/null && break; sleep 0.1; done
mkdir -p "$AQUI/resultados"
NEWMAN="$AQUI/node_modules/.bin/newman"
P="$AQUI/postman"
ENV=(-e "$P/SIGR_local.postman_environment.json" --env-var "baseUrl=http://localhost:$PUERTO")
fallo=0
echo "=== 1/3 Pruebas funcionales ==="
"$NEWMAN" run "$P/SIGR_funcional.postman_collection.json" "${ENV[@]}" --color off \
  -r cli,htmlextra --reporter-htmlextra-export "$AQUI/resultados/informe_funcional.html" || fallo=1
echo "=== 2/3 Registro guiado por datos ==="
"$NEWMAN" run "$P/SIGR_registro_datos.postman_collection.json" "${ENV[@]}" -d "$P/datos_registro.json" --color off || fallo=1
echo "=== 3/3 Login guiado por datos ==="
"$NEWMAN" run "$P/SIGR_login_datos.postman_collection.json" "${ENV[@]}" -d "$P/datos_login.json" --color off || fallo=1
kill "$(cat "$TMP/pid")" 2>/dev/null
rm -rf "$TMP"
exit $fallo

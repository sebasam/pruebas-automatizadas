'use strict';
// Prueba de carga ligera para la etapa de rendimiento del pipeline.
// Levanta el servicio con datos de ejemplo y mide latencia y errores.
const http = require('node:http');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { crearDb } = require('../src/db');
const menu = require('../src/modules/menu');
const { crearServidor } = require('../src/server');

const TOTAL = Number(process.env.CARGA_SOLICITUDES) || 1000;
const CONCURRENCIA = Number(process.env.CARGA_CONCURRENCIA) || 20;
const UMBRAL_P95_MS = Number(process.env.UMBRAL_P95_MS) || 200;
const RUTAS = ['/menu', '/salud', '/reservas/disponibilidad?fecha=2026-12-01&hora=13:00'];

function prepararDatos() {
  const archivo = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'sigr-carga-')), 'db.json');
  const db = crearDb(archivo);
  const cat = menu.crearCategoria(db, { nombre: 'Platos fuertes' });
  for (let i = 1; i <= 20; i += 1) menu.crearPlato(db, { nombre: `Plato ${i}`, precio: 10000 + i * 500, categoriaId: cat.id });
  return archivo;
}

function percentil(valores, p) {
  const orden = [...valores].sort((a, b) => a - b);
  return orden[Math.min(orden.length - 1, Math.ceil((p / 100) * orden.length) - 1)];
}

async function main() {
  const servidor = crearServidor({ archivoDb: prepararDatos() });
  await new Promise((r) => servidor.listen(0, r));
  const { port } = servidor.address();
  const agente = new http.Agent({ keepAlive: true, maxSockets: CONCURRENCIA });
  const latencias = [];
  let errores = 0;
  let siguiente = 0;

  function una() {
    return new Promise((resolver) => {
      const ruta = RUTAS[siguiente % RUTAS.length];
      siguiente += 1;
      const t0 = process.hrtime.bigint();
      http.get({ port, path: ruta, agent: agente }, (res) => {
        res.resume();
        res.on('end', () => {
          if (res.statusCode !== 200) errores += 1;
          latencias.push(Number(process.hrtime.bigint() - t0) / 1e6);
          resolver();
        });
      }).on('error', () => { errores += 1; resolver(); });
    });
  }

  async function trabajador() {
    while (siguiente < TOTAL) await una();
  }

  const inicio = process.hrtime.bigint();
  await Promise.all(Array.from({ length: CONCURRENCIA }, trabajador));
  const segundos = Number(process.hrtime.bigint() - inicio) / 1e9;
  agente.destroy();
  await new Promise((r) => servidor.close(r));

  const prom = latencias.reduce((a, b) => a + b, 0) / latencias.length;
  const p95 = percentil(latencias, 95);
  console.log(`Carga: ${TOTAL} solicitudes con concurrencia ${CONCURRENCIA}`);
  console.log(`Errores: ${errores} (${((errores / TOTAL) * 100).toFixed(1)} %)`);
  console.log(`Latencia promedio: ${prom.toFixed(1)} ms | p95: ${p95.toFixed(1)} ms | máxima: ${Math.max(...latencias).toFixed(1)} ms`);
  console.log(`Rendimiento: ${(TOTAL / segundos).toFixed(0)} solicitudes/s`);
  console.log(`Umbral de p95: ${UMBRAL_P95_MS} ms`);
  if (errores > 0 || p95 > UMBRAL_P95_MS) {
    console.log('Resultado: no se cumplen los umbrales de rendimiento.');
    process.exit(1);
  }
  console.log('Resultado: cumple los umbrales de rendimiento.');
}

main();

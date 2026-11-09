'use strict';
const http = require('http');
const path = require('path');
const fs = require('fs');

const TIPOS = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8' };
const PUBLICO = path.join(__dirname, '..', 'public');

/** Sirve las paginas estaticas bajo /ui/. Devuelve true si atendio la peticion. */
function servirEstatico(req, res) {
  if (req.method !== 'GET') return false;
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/') { res.writeHead(302, { Location: '/ui/reserva.html' }); res.end(); return true; }
  if (!url.pathname.startsWith('/ui/')) return false;
  const archivo = path.normalize(path.join(PUBLICO, url.pathname.slice(4)));
  if (!archivo.startsWith(PUBLICO + path.sep) || !fs.existsSync(archivo)) {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('No encontrado');
    return true;
  }
  res.writeHead(200, { 'Content-Type': TIPOS[path.extname(archivo)] || 'application/octet-stream' });
  res.end(fs.readFileSync(archivo));
  return true;
}
const { crearApp } = require('./app');

function crearServidor(opciones = {}) {
  const app = crearApp(opciones);
  return http.createServer((req, res) => {
    if (servirEstatico(req, res)) return;
    let texto = '';
    req.on('data', (d) => { texto += d; });
    req.on('end', () => {
      let cuerpo = {};
      try {
        cuerpo = texto ? JSON.parse(texto) : {};
      } catch {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({ error: 'JSON no valido.' }));
      }
      const token = (req.headers.authorization || '').replace(/^Bearer /, '');
      const r = app.manejar(req.method, req.url, cuerpo, token);
      res.writeHead(r.estado, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(r.cuerpo === null ? '' : JSON.stringify(r.cuerpo));
    });
  });
}

if (require.main === module) {
  const puerto = Number(process.env.PORT) || 3000;
  crearServidor({ archivoDb: process.env.SIGR_DB || path.join(__dirname, '..', 'data', 'db.json') })
    .listen(puerto, () => console.log(`SIGR escuchando en http://localhost:${puerto}`));
}

module.exports = { crearServidor };

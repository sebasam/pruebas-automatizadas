'use strict';
const { crearDb } = require('./db');
const { ErrorSigr } = require('./errores');
const auth = require('./modules/auth');
const menu = require('./modules/menu');
const pedidos = require('./modules/pedidos');
const reservas = require('./modules/reservas');
const caja = require('./modules/caja');

/** Crea el manejador de peticiones. Recibe una funcion `ahora` para facilitar las pruebas. */
function crearApp({ archivoDb = null, ahora = () => new Date() } = {}) {
  const db = crearDb(archivoDb);
  const sesiones = new Map();
  let infoBuild = {};
  try { infoBuild = require('../build-info.json'); } catch { /* en desarrollo no existe */ }

  const rutas = [
    ['GET', /^\/salud$/, () => ({ estado: 'ok', version: require('../package.json').version, commit: infoBuild.commit })],
    ['POST', /^\/auth\/registro$/, (c) => auth.registrar(db, { ...c.cuerpo, rol: 'cliente' }), 201],
    ['POST', /^\/auth\/login$/, (c) => auth.iniciarSesion(db, sesiones, c.cuerpo)],
    ['GET', /^\/menu$/, () => menu.listarMenu(db)],
    ['POST', /^\/menu\/categorias$/, (c) => { auth.exigirRol(c.usuario, 'administrador'); return menu.crearCategoria(db, c.cuerpo); }, 201],
    ['POST', /^\/menu\/platos$/, (c) => { auth.exigirRol(c.usuario, 'administrador'); return menu.crearPlato(db, c.cuerpo); }, 201],
    ['PUT', /^\/menu\/platos\/(\d+)$/, (c) => { auth.exigirRol(c.usuario, 'administrador'); return menu.actualizarPlato(db, Number(c.p[1]), c.cuerpo); }],
    ['DELETE', /^\/menu\/platos\/(\d+)$/, (c) => { auth.exigirRol(c.usuario, 'administrador'); menu.eliminarPlato(db, Number(c.p[1])); return null; }, 204],
    ['POST', /^\/pedidos$/, (c) => { auth.exigirRol(c.usuario, 'mesero', 'administrador'); return pedidos.crearPedido(db, c.cuerpo, c.usuario.id, ahora); }, 201],
    ['GET', /^\/pedidos$/, (c) => { auth.exigirRol(c.usuario, 'mesero', 'administrador'); return pedidos.listarPedidos(db, c.query.get('estado')); }],
    ['PATCH', /^\/pedidos\/(\d+)\/estado$/, (c) => { auth.exigirRol(c.usuario, 'mesero', 'administrador'); return pedidos.cambiarEstado(db, Number(c.p[1]), c.cuerpo.estado, ahora); }],
    ['GET', /^\/reservas\/disponibilidad$/, (c) => ({ mesasLibres: reservas.disponibilidad(db, c.query.get('fecha'), c.query.get('hora')) })],
    ['POST', /^\/reservas$/, (c) => reservas.crearReserva(db, c.cuerpo), 201],
    ['DELETE', /^\/reservas\/(\d+)$/, (c) => reservas.cancelarReserva(db, Number(c.p[1]))],
    ['GET', /^\/reportes\/ventas$/, (c) => { auth.exigirRol(c.usuario, 'administrador'); return caja.reporteVentas(db, c.query.get('fecha')); }],
    ['POST', /^\/caja\/cierre$/, (c) => { auth.exigirRol(c.usuario, 'administrador'); return caja.cierreCaja(db, c.cuerpo.fecha, c.usuario.nombre, ahora); }, 201],
  ];

  function manejar(metodo, url, cuerpo, token) {
    const u = new URL(url, 'http://localhost');
    try {
      for (const [m, patron, fn, exito = 200] of rutas) {
        const p = patron.exec(u.pathname);
        if (m === metodo && p) {
          const usuario = token ? sesiones.get(token) : null;
          const r = fn({ cuerpo: cuerpo || {}, query: u.searchParams, p, usuario });
          return { estado: exito, cuerpo: r };
        }
      }
      throw new ErrorSigr('Ruta no encontrada.', 404);
    } catch (e) {
      if (e instanceof ErrorSigr) return { estado: e.estado, cuerpo: { error: e.message } };
      return { estado: 500, cuerpo: { error: 'Error interno del servidor.' } };
    }
  }

  return { db, manejar };
}

module.exports = { crearApp };

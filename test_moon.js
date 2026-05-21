import { Observer, Body, Equator, Horizon } from 'astronomy-engine';

const lat = 22.6273;
const lon = 120.3014;
const date = new Date('2026-05-20T14:19:00+08:00');

const observer = new Observer(lat, lon, 0);
const body = Body.Moon;
const eq = Equator(body, date, observer, true, true);
const hor = Horizon(date, observer, eq.ra, eq.dec, 'normal');

console.log(`Moon Altitude: ${hor.altitude.toFixed(2)}`);

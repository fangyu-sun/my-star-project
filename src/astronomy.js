import { Observer, Body, Equator, Horizon } from 'astronomy-engine';
import famousStars from './data/stars.json';
import hygStars from './data/hyg_stars.json';
import { constellations } from './data/constellations.js';

const planets = [
    { id: 'Sun', name: '太阳', isPlanet: true },
    { id: 'Moon', name: '月亮', isPlanet: true },
    { id: 'Jupiter', name: '木星', isPlanet: true },
    { id: 'Venus', name: '金星', isPlanet: true },
    { id: 'Mars', name: '火星', isPlanet: true },
    { id: 'Saturn', name: '土星', isPlanet: true }
];

export function getBestZenithObject(lat, lon, date) {
    const observer = new Observer(lat, lon, 0);
    const candidates = [];

    // Evaluate Planets
    for (const p of planets) {
        const body = Body[p.id];
        const eq = Equator(body, date, observer, true, true);
        const hor = Horizon(date, observer, eq.ra, eq.dec, 'normal');
        
        if (hor.altitude >= 80) {
            const distKm = eq.dist * 1.496e8; // AU to km
            let distStr = "";
            if (distKm > 1e8) {
                distStr = (distKm / 1e8).toFixed(1) + " 亿公里";
            } else if (distKm > 1e4) {
                distStr = (distKm / 1e4).toFixed(1) + " 万公里";
            } else {
                distStr = distKm.toFixed(0) + " 公里";
            }

            candidates.push({
                ...p,
                altitude: hor.altitude,
                distanceStr: distStr,
                isPlanet: true
            });
        }
    }

    // Evaluate Famous Stars
    for (const star of famousStars) {
        const hor = Horizon(date, observer, star.ra, star.dec, 'normal');
        if (hor.altitude >= 80) {
            candidates.push({
                ...star,
                altitude: hor.altitude,
                distanceStr: star.distance + " 光年",
                isPlanet: false,
                isFamous: true
            });
        }
    }

    // Evaluate HYG Stars
    for (const star of hygStars) {
        const hor = Horizon(date, observer, star.ra, star.dec, 'normal');
        if (hor.altitude >= 80) {
            const conName = constellations[star.con] ? `位于${constellations[star.con]}的恒星` : '暗星';
            candidates.push({
                ...star,
                name: conName,
                altitude: hor.altitude,
                distanceStr: star.distanceLy + " 光年",
                isPlanet: false,
                isFamous: false
            });
        }
    }

    // Scoring system
    // Base score is normalized altitude: (altitude / 90)
    // Multipliers give preference to more "interesting" objects
    candidates.forEach(c => {
        let weight = 1.0;
        if (c.id === 'Moon' || c.id === 'Sun') weight = 1.5;
        else if (c.isPlanet) weight = 1.3;
        else if (c.isFamous) weight = 1.2;
        else weight = 1.0;

        c.score = (c.altitude / 90) * weight;
    });

    // Sort by score descending
    candidates.sort((a, b) => b.score - a.score);

    return candidates.length > 0 ? candidates[0] : null;
}

import * as satellite from 'satellite.js';

/**
 * Calculates look angles (altitude, azimuth, range) for a satellite.
 * @param {string} tle1 - Line 1 of Two-Line Element set
 * @param {string} tle2 - Line 2 of Two-Line Element set
 * @param {number} observerLat - Observer latitude in degrees
 * @param {number} observerLon - Observer longitude in degrees
 * @param {Date} date - Calculation datetime
 * @returns {object|null} Look angles object containing altitude, azimuth, range, or null if propagation fails.
 */
export function getSatelliteLookAngles(tle1, tle2, observerLat, observerLon, date) {
    try {
        const satrec = satellite.twoline2satrec(tle1, tle2);
        
        // Propagate satellite position
        const positionAndVelocity = satellite.propagate(satrec, date);
        const positionEci = positionAndVelocity.position;
        
        if (!positionEci || isNaN(positionEci.x) || isNaN(positionEci.y) || isNaN(positionEci.z)) {
            return null;
        }
        
        // Geodetic observer coordinates (lat/lon in radians, height in km)
        const observerGd = {
            latitude: satellite.degreesToRadians(observerLat),
            longitude: satellite.degreesToRadians(observerLon),
            height: 0.1 // Assume 100 meters above sea level
        };
        
        // Greenwich Mean Sidereal Time
        const gmst = satellite.gstime(date);
        
        // Transform coordinates to ECF and calculate look angles
        const positionEcf = satellite.eciToEcf(positionEci, gmst);
        const lookAngles = satellite.ecfToLookAngles(observerGd, positionEcf);
        
        // Convert Look Angles to Degrees
        const azimuth = satellite.radiansToDegrees(lookAngles.azimuth);
        const elevation = satellite.radiansToDegrees(lookAngles.elevation);
        const range = lookAngles.rangeSat; // In kilometers
        
        return {
            azimuth,
            elevation, // Same as altitude in astronomy
            range
        };
    } catch (e) {
        console.error("Satellite propagation error:", e);
        return null;
    }
}

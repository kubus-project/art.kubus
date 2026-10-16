// Pure solar/camera mathematics adapted from art.kubus.site sunPosition.ts @97471111.
// Presentation and lifecycle are owned by kubus_globe_atmosphere.mjs.
const degToRad = (d) => (d * Math.PI) / 180;
const radToDeg = (r) => (r * 180) / Math.PI;
const normalizeDeg360 = (d) => ((d % 360) + 360) % 360;
const normalizeLng180 = (d) => (((d + 180) % 360) + 360) % 360 - 180;
export function getSubsolarPoint(date = new Date()) {
    const J2000 = Date.UTC(2000, 0, 1, 12, 0, 0);
    const daysSinceJ2000 = (date.getTime() - J2000) / 86400000;
    const meanLongitudeDeg = normalizeDeg360(280.46 + 0.9856474 * daysSinceJ2000);
    const meanAnomalyDeg = normalizeDeg360(357.528 + 0.9856003 * daysSinceJ2000);
    const meanAnomalyRad = degToRad(meanAnomalyDeg);
    const eclipticLongitudeDeg = normalizeDeg360(meanLongitudeDeg +
        1.915 * Math.sin(meanAnomalyRad) +
        0.02 * Math.sin(2 * meanAnomalyRad));
    const eclipticLongitudeRad = degToRad(eclipticLongitudeDeg);
    const obliquityDeg = 23.439 - 0.0000004 * daysSinceJ2000;
    const obliquityRad = degToRad(obliquityDeg);
    const declinationRad = Math.asin(Math.sin(obliquityRad) * Math.sin(eclipticLongitudeRad));
    const y = Math.tan(obliquityRad / 2) ** 2;
    const meanLongitudeRad = degToRad(meanLongitudeDeg);
    const eqTimeMinutes = 4 *
        radToDeg(y * Math.sin(2 * meanLongitudeRad) -
            2 * 0.0167 * Math.sin(meanAnomalyRad) +
            4 * 0.0167 * y * Math.sin(meanAnomalyRad) * Math.cos(2 * meanLongitudeRad) -
            0.5 * y * y * Math.sin(4 * meanLongitudeRad) -
            1.25 * 0.0167 * 0.0167 * Math.sin(2 * meanAnomalyRad));
    const utcHours = date.getUTCHours() + date.getUTCMinutes() / 60 + date.getUTCSeconds() / 3600;
    const subsolarLng = normalizeLng180(-15 * (utcHours - 12 + eqTimeMinutes / 60));
    return { lat: radToDeg(declinationRad), lng: subsolarLng };
}
const unitVector = (lng, lat) => {
    const la = degToRad(lat);
    const lo = degToRad(lng);
    return [
        Math.cos(la) * Math.cos(lo),
        Math.cos(la) * Math.sin(lo),
        Math.sin(la),
    ];
};
export function sunDirectionInView(sun, centerLng, centerLat) {
    const v = unitVector(sun.lng, sun.lat);
    const f = unitVector(centerLng, centerLat);
    let u = [-f[2] * f[0], -f[2] * f[1], 1 - f[2] * f[2]];
    let uLen = Math.hypot(u[0], u[1], u[2]);
    if (uLen < 1e-9) {
        u = [1, 0, 0];
        uLen = 1;
    }
    u = [u[0] / uLen, u[1] / uLen, u[2] / uLen];
    const r = [
        u[1] * f[2] - u[2] * f[1],
        u[2] * f[0] - u[0] * f[2],
        u[0] * f[1] - u[1] * f[0],
    ];
    return {
        x: v[0] * r[0] + v[1] * r[1] + v[2] * r[2],
        y: v[0] * u[0] + v[1] * u[1] + v[2] * u[2],
        z: v[0] * f[0] + v[1] * f[1] + v[2] * f[2],
    };
}
export function isLocalDaytime(date = new Date()) {
    const hour = date.getHours();
    return hour >= 7 && hour < 19;
}

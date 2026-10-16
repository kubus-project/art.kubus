// Pure solar/camera mathematics adapted from art.kubus.site globeShading.ts @97471111.
// Presentation and lifecycle are owned by kubus_globe_atmosphere.mjs.
const DEG = Math.PI / 180;
export function solveGlobeCamera(d1, theta1Deg, d2, theta2Deg) {
    const s1 = Math.sin(theta1Deg * DEG);
    const c1 = Math.cos(theta1Deg * DEG);
    const s2 = Math.sin(theta2Deg * DEG);
    const c2 = Math.cos(theta2Deg * DEG);
    const den = d1 * s2 - d2 * s1;
    if (!Number.isFinite(den) || Math.abs(den) < 1e-9)
        return null;
    const D = (d1 * c1 * s2 - d2 * c2 * s1) / den;
    if (!Number.isFinite(D) || D <= 1.02 || D > 1e4)
        return null;
    const k = (d1 * (D - c1)) / s1;
    if (!Number.isFinite(k) || k <= 0)
        return null;
    return { k, D };
}
export function destinationPoint(latDeg, lngDeg, bearingDeg, thetaDeg) {
    const lat1 = latDeg * DEG;
    const brg = bearingDeg * DEG;
    const th = thetaDeg * DEG;
    const lat2 = Math.asin(Math.sin(lat1) * Math.cos(th) +
        Math.cos(lat1) * Math.sin(th) * Math.cos(brg));
    const lng2 = lngDeg * DEG +
        Math.atan2(Math.sin(brg) * Math.sin(th) * Math.cos(lat1), Math.cos(th) - Math.sin(lat1) * Math.sin(lat2));
    let lng = lng2 / DEG;
    lng = ((((lng + 180) % 360) + 360) % 360) - 180;
    return { lat: lat2 / DEG, lng };
}
export function fitGlobeCamera(probes) {
    const usable = probes.filter((p) => Number.isFinite(p.distance) &&
        p.distance > 0 &&
        p.thetaDeg > 0.5 &&
        p.thetaDeg < 89.5);
    if (usable.length < 3)
        return null;
    const n = usable.length;
    const sinTheta = new Float64Array(n);
    const cosTheta = new Float64Array(n);
    const dist = new Float64Array(n);
    let sumD2 = 0;
    for (let i = 0; i < n; i++) {
        const p = usable[i];
        sinTheta[i] = Math.sin(p.thetaDeg * DEG);
        cosTheta[i] = Math.cos(p.thetaDeg * DEG);
        dist[i] = p.distance;
        sumD2 += p.distance * p.distance;
    }
    const errorAt = (D) => {
        let num = 0;
        let den = 0;
        for (let i = 0; i < n; i++) {
            const w = sinTheta[i] / (D - cosTheta[i]);
            num += w * dist[i];
            den += w * w;
        }
        if (den <= 0)
            return { k: 0, err: Number.POSITIVE_INFINITY };
        return { k: num / den, err: sumD2 - (num * num) / den };
    };
    let lo = 1.05;
    let hi = 40;
    let best = { D: lo, k: 0, err: Number.POSITIVE_INFINITY };
    for (let pass = 0; pass < 4; pass++) {
        const steps = 40;
        let localBest = best;
        for (let i = 0; i <= steps; i++) {
            const D = lo + ((hi - lo) * i) / steps;
            const { k, err } = errorAt(D);
            if (err < localBest.err)
                localBest = { D, k, err };
        }
        best = localBest;
        const span = (hi - lo) / steps;
        lo = Math.max(1.05, best.D - span);
        hi = best.D + span;
    }
    if (!Number.isFinite(best.k) || best.k <= 0 || best.D <= 1.02)
        return null;
    return { k: best.k, D: best.D };
}
export function screenDistanceAt(thetaDeg, cam) {
    const s = Math.sin(thetaDeg * DEG);
    const c = Math.cos(thetaDeg * DEG);
    return (cam.k * s) / (cam.D - c);
}
export function limbAngleDeg(cam) {
    return Math.acos(1 / cam.D) / DEG;
}
export function limbRadius(cam) {
    const cosLimb = 1 / cam.D;
    const sinLimb = Math.sqrt(Math.max(0, 1 - cosLimb * cosLimb));
    return (cam.k * sinLimb) / (cam.D - cosLimb);
}
export function nightFilterRegion(originX, originY, limbR, sigma) {
    const margin = Math.max(4, sigma * 4);
    const half = limbR + margin;
    return {
        x: originX - half,
        y: originY - half,
        width: half * 2,
        height: half * 2,
    };
}
export function projectUnitVector(n, cam) {
    const den = cam.D - n[2];
    return [(cam.k * n[0]) / den, (-cam.k * n[1]) / den];
}
export function nightRegionGeometry(sun, cam, steps = 96, closurePaddingPx = 0) {
    const cosLimb = 1 / cam.D;
    const lr = limbRadius(cam);
    const maxR = lr;
    const clamp = (q) => {
        const d = Math.hypot(q[0], q[1]);
        return d > maxR ? [(q[0] * maxR) / d, (q[1] * maxR) / d] : q;
    };
    const closeR = lr + Math.max(0, closurePaddingPx);
    const closure = (q) => {
        if (closurePaddingPx <= 0)
            return clamp(q);
        const d = Math.hypot(q[0], q[1]) || 1;
        return [(q[0] * closeR) / d, (q[1] * closeR) / d];
    };
    const m = Math.sqrt(Math.max(0, 1 - cosLimb * cosLimb));
    const S = [sun.x, sun.y, sun.z];
    const limbPoint = (psi) => [
        m * Math.cos(psi),
        m * Math.sin(psi),
        cosLimb,
    ];
    const wholeLimb = () => {
        const pts = [];
        for (let i = 0; i <= steps; i++) {
            pts.push(closure(projectUnitVector(limbPoint((2 * Math.PI * i) / steps), cam)));
        }
        return pts;
    };
    const allOrNothing = () => ({
        nightRegion: S[2] < 0 ? wholeLimb() : [],
        terminatorArc: [],
    });
    const ux = S[1];
    const uy = -S[0];
    const uLen = Math.hypot(ux, uy);
    if (uLen < 1e-9)
        return allOrNothing();
    const U = [ux / uLen, uy / uLen, 0];
    let V = [
        S[1] * U[2] - S[2] * U[1],
        S[2] * U[0] - S[0] * U[2],
        S[0] * U[1] - S[1] * U[0],
    ];
    if (V[2] < 0)
        V = [-V[0], -V[1], -V[2]];
    if (V[2] < 1e-9)
        return allOrNothing();
    const a = cosLimb / V[2];
    if (a >= 1)
        return allOrNothing();
    const phi1 = Math.asin(Math.max(-1, Math.min(1, a)));
    const phi2 = Math.PI - phi1;
    const term = (phi) => {
        const c = Math.cos(phi);
        const s = Math.sin(phi);
        return [
            U[0] * c + V[0] * s,
            U[1] * c + V[1] * s,
            U[2] * c + V[2] * s,
        ];
    };
    const terminatorArc = [];
    for (let i = 0; i <= steps; i++) {
        terminatorArc.push(clamp(projectUnitVector(term(phi1 + ((phi2 - phi1) * i) / steps), cam)));
    }
    const nightRegion = [...terminatorArc];
    const end = term(phi2);
    const start = term(phi1);
    const psiEnd = Math.atan2(end[1], end[0]);
    const psiStart = Math.atan2(start[1], start[0]);
    let delta = psiStart - psiEnd;
    while (delta <= 0)
        delta += 2 * Math.PI;
    const mid = limbPoint(psiEnd + delta / 2);
    const midIsNight = mid[0] * S[0] + mid[1] * S[1] + mid[2] * S[2] < 0;
    if (!midIsNight)
        delta -= 2 * Math.PI;
    for (let i = 1; i <= steps; i++) {
        nightRegion.push(closure(projectUnitVector(limbPoint(psiEnd + (delta * i) / steps), cam)));
    }
    return { nightRegion, terminatorArc };
}

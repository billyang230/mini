// Pose generator for the hero sprites. Local space: facing +z, up +y, character's right hand at -x.
const V = {
  add: (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]],
  sub: (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]],
  mul: (a, s) => [a[0] * s, a[1] * s, a[2] * s],
  dot: (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2],
  len: a => Math.hypot(a[0], a[1], a[2]),
  norm: a => { const l = Math.hypot(a[0], a[1], a[2]) || 1; return [a[0] / l, a[1] / l, a[2] / l]; },
  cross: (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]],
  mix: (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t],
};
function rotY(v, a) { const c = Math.cos(a), s = Math.sin(a); return [v[0] * c + v[2] * s, v[1], -v[0] * s + v[2] * c]; }
function rotX(v, a) { const c = Math.cos(a), s = Math.sin(a); return [v[0], v[1] * c - v[2] * s, v[1] * s + v[2] * c]; }
function ik(a, t, l1, l2, pole) {
  let d = V.sub(t, a); let dl = V.len(d); const mx = (l1 + l2) * 0.999;
  if (dl > mx) { d = V.mul(V.norm(d), mx); dl = mx; t = V.add(a, d); }
  const dir = V.norm(d);
  const ca = Math.max(-1, Math.min(1, (l1 * l1 + dl * dl - l2 * l2) / (2 * l1 * dl)));
  const sa = Math.sqrt(1 - ca * ca);
  let pp = V.sub(pole, V.mul(dir, V.dot(pole, dir))); pp = V.norm(pp);
  return { mid: V.add(a, V.add(V.mul(dir, l1 * ca), V.mul(pp, l1 * sa))), end: t };
}
const lerp = (a, b, t) => a + (b - a) * t;
const ease = t => t * t * (3 - 2 * t);

// keyframes for attack: grip G, axis U, twist, lean, lunge
const ATK = [
  { G: [-0.14, 1.30, 0.06], U: [-0.35, 0.9, -0.25], tw: -0.35, le: -0.04, lu: 0.0 },
  { G: [-0.08, 1.55, -0.04], U: [-0.2, 0.55, -0.8], tw: -0.55, le: -0.12, lu: 0.05 },
  { G: [0.0, 1.50, 0.18], U: [0.0, 0.95, 0.3], tw: -0.15, le: 0.04, lu: 0.4 },
  { G: [0.06, 1.12, 0.4], U: [0.2, -0.05, 1.0], tw: 0.25, le: 0.22, lu: 1.0 },
  { G: [0.14, 0.95, 0.3], U: [0.75, -0.4, 0.5], tw: 0.45, le: 0.2, lu: 1.0 },
  { G: [-0.12, 1.12, 0.14], U: [-0.15, 0.9, 0.35], tw: 0.1, le: 0.06, lu: 0.4 },
];

function pose(hero, anim, f, nf, T) {
  const t = T;
  let pel = [0, 0.98, 0], lean = 0, twist = 0;
  let ankL = [0.13, 0.09, 0.02], ankR = [-0.13, 0.09, -0.02];
  let liftL = 0, liftR = 0;
  let handR, handL, WB, WT, WN, capeAmt = 0.06, tasSw = 0;
  let breath = 0;
  if (anim === 'idle') {
    const ph = 2 * Math.PI * f / nf;
    breath = Math.sin(ph) * 0.012;
    pel = [0, 0.98 + breath * 0.3, 0];
    ankL = [0.15, 0.09, 0.05]; ankR = [-0.14, 0.09, -0.03];
    handR = [-0.37, 1.0 + breath * 0.5, 0.1];
    const Uw = V.norm([-0.13, 1, 0.08 + Math.sin(ph) * 0.01]);
    WB = V.sub(handR, V.mul(Uw, 1.0)); WT = V.add(handR, V.mul(Uw, 0.98));
    WN = [1, 0, -0.35];
    handL = [0.27, 0.98 + breath * 0.5, 0.07];
    capeAmt = 0.06 + Math.sin(ph) * 0.03; tasSw = Math.sin(ph) * 0.03;
  } else if (anim === 'walk') {
    const ph = 2 * Math.PI * f / nf;
    const s = Math.sin(ph), c = Math.cos(ph);
    pel = [0, 0.97 - 0.03 * Math.abs(s) + 0.015, 0];
    ankL = [0.12, 0.09, 0.22 * s]; ankR = [-0.12, 0.09, -0.22 * s];
    liftL = Math.max(0, c) * 0.1; liftR = Math.max(0, -c) * 0.1;
    ankL[1] += liftL; ankR[1] += liftR;
    lean = 0.08; twist = 0.08 * s;
    handR = [-0.27, 1.03 - 0.02 * Math.abs(s), 0.12];
    const Uw = V.norm([0.05, 0.78, 0.6]);
    WB = V.sub(handR, V.mul(Uw, 0.75)); WT = V.add(handR, V.mul(Uw, 1.15));
    WN = [1, 0, -0.1];
    handL = [0.25, 1.0, -0.16 * s + 0.02];
    capeAmt = 0.13 + 0.03 * c; tasSw = -0.08 + 0.04 * s;
  } else if (anim === 'attack') {
    const k = ATK[f], kp = ATK[Math.max(0, f - 1)], kn = ATK[Math.min(ATK.length - 1, f + 1)];
    lean = k.le; twist = k.tw;
    pel = [0, 0.98 - 0.07 * k.lu, 0.05 * k.lu];
    ankL = [0.15, 0.09, 0.05 + 0.25 * k.lu]; ankR = [-0.15, 0.09, -0.03 - 0.17 * k.lu];
    const U = V.norm(k.U);
    const G = k.G;
    handR = V.sub(G, V.mul(U, 0.17)); handL = V.add(G, V.mul(U, 0.17));
    WB = V.sub(G, V.mul(U, 0.85)); WT = V.add(G, V.mul(U, 1.05));
    let s = V.sub(V.norm(kn.U), V.norm(kp.U)); if (V.len(s) < 1e-3) s = [0, 0, 1];
    WN = V.norm(V.cross(U, V.norm(s)));
    capeAmt = 0.1 + 0.25 * k.lu; tasSw = -0.1 * (f - 2);
  } else if (anim === 'hurt') {
    const k = f === 0 ? 0.6 : 1;
    lean = -0.18 * k; twist = 0.12 * k;
    pel = [0, 0.96, -0.05 * k];
    ankL = [0.15, 0.09, 0.08]; ankR = [-0.14, 0.09, -0.08];
    handR = [-0.3, 1.05, 0.1];
    const Uw = V.norm([-0.1, 1, -0.25 * k]);
    WB = V.sub(handR, V.mul(Uw, 1.0)); WT = V.add(handR, V.mul(Uw, 0.98));
    WN = [1, 0, -0.3];
    handL = [0.3, 1.1, 0.12];
    capeAmt = 0.02; tasSw = 0.08;
  }
  // upper-body frame
  const ub = p => V.add(pel, rotY(rotX(V.sub(p, [0, 0.98, 0]), lean), twist));
  const che = ub([0, 1.36 + breath, 0]);
  const nec = ub([0, 1.55 + breath, 0]);
  const hea = ub([0, 1.685 + breath, 0.012]);
  const shL = ub([0.24, 1.465 + breath, 0]);
  const shR = ub([-0.24, 1.465 + breath, 0]);
  const BF = rotY(rotX([0, 0, 1], lean), twist);
  const BU = rotY(rotX([0, 1, 0], lean), twist);
  let HF = V.norm(V.add(BF, [0, -0.08, 0]));
  if (anim === 'attack') HF = V.norm(V.add(rotY([0, 0, 1], twist * 0.4), [0, -0.05, 0]));
  const hipL = V.add(pel, rotY([0.09, -0.03, 0], twist * 0.3));
  const hipR = V.add(pel, rotY([-0.09, -0.03, 0], twist * 0.3));
  const kL = ik(hipL, ankL, 0.46, 0.45, [0.1, 0, 1]);
  const kR = ik(hipR, ankR, 0.46, 0.45, [-0.1, 0, 1]);
  const toeL = V.add(kL.end, [0.02, -0.05, 0.13]);
  const toeR = V.add(kR.end, [-0.02, -0.05, 0.13]);
  const eL = ik(shL, handL, 0.3, 0.28, [0.6, -0.3, -0.6]);
  const eR = ik(shR, handR, 0.3, 0.28, [-0.6, -0.3, -0.6]);
  const hem = hero === 0
    ? [(kL.end[0] + kR.end[0]) / 2, 0.2, (kL.end[2] + kR.end[2]) / 2 + 0.02]
    : [(kL.mid[0] + kR.mid[0]) / 2 * 0.8, 0.42, (kL.mid[2] + kR.mid[2]) / 2 + 0.03];
  const capeV = V.mul(V.norm(V.add(V.mul(BF, -1), [0, 0.0, 0])), capeAmt);
  const tas = [tasSw * 0.5, -0.17, -tasSw];
  const J = new Array(64).fill(0).map(() => [0, 0, 0]);
  Object.assign(J, { 0: pel, 1: che, 2: nec, 3: hea, 4: shL, 5: shR, 6: eL.mid, 7: eR.mid, 8: eL.end, 9: eR.end,
    10: hipL, 11: hipR, 12: kL.mid, 13: kR.mid, 14: kL.end, 15: kR.end, 16: toeL, 17: toeR,
    18: WB, 19: WT, 20: WN, 21: BF, 22: BU, 23: hem, 24: capeV, 25: HF, 26: tas });
  // feathers
  const hr = V.norm(V.cross(BU, HF));
  for (let side = 0; side < 2; side++) {
    const sg = side ? -1 : 1;
    const base = V.add(V.add(hea, V.mul(BU, 0.13)), V.add(V.mul(hr, 0.03 * sg), V.mul(HF, 0.02)));
    const sway = Math.sin(t * 2 + side) * 0.04 + (anim === 'walk' ? 0.06 : 0) + (anim === 'attack' ? 0.08 : 0);
    const P1 = V.add(base, V.add(V.mul(hr, 0.07 * sg), V.add(V.mul(BU, 0.38), V.mul(HF, -0.02))));
    const P2 = V.add(base, V.add(V.mul(hr, 0.3 * sg), V.add(V.mul(BU, 0.42 - sway), V.mul(HF, -0.5 - sway))));
    for (let i = 0; i < 8; i++) {
      const u = i / 7;
      const q = V.add(V.add(V.mul(base, (1 - u) * (1 - u)), V.mul(P1, 2 * (1 - u) * u)), V.mul(P2, u * u));
      J[32 + side * 8 + i] = q;
    }
  }
  // beard
  const up = BU;
  const chin = V.add(V.add(hea, V.mul(HF, 0.065)), V.mul(up, -0.085));
  const bs = Math.sin(t * 2.3) * 0.01 + (anim === 'walk' ? -0.03 : 0) + (anim === 'attack' ? -0.04 * twist : 0);
  J[48] = chin;
  J[49] = V.add(chin, V.add(V.mul(up, -0.1), V.mul(HF, 0.035)));
  J[50] = V.add(J[49], V.add(V.mul(up, -0.11), V.mul(HF, 0.005 + bs)));
  J[51] = V.add(J[50], V.add(V.mul(up, -0.1), V.mul(HF, -0.01 + bs * 1.5)));
  const U = V.norm(V.sub(WT, WB));
  const bladeTip = V.add(WT, V.mul(U, hero === 0 ? 0.55 : 0.5));
  return { J, bladeTip, WT };
}
if (typeof module !== 'undefined') module.exports = { pose, ATK };

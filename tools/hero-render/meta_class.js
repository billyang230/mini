// 算出職業角色每一格武器的握把與尖端位置（1x 像素座標），寫回 <dir>/meta.json，給發光系統用
const { pose } = require('./pose.js'); const fs = require('fs');
const DIR = process.argv[2] || 'full';
const NF = { idle: 6, walk: 8, attack: 6, hurt: 2 };
const PITCH = 30 * Math.PI / 180, WW = 5.4, WH = 4.1, CX = 0, CY = 1.05;
const YAW = { front: Math.PI / 4, back: 3 * Math.PI / 4 };
const n = a => { const l = Math.hypot(...a); return a.map(v => v / l); };
const add = (a, b, k) => a.map((v, i) => v + b[i] * k);
const M = JSON.parse(fs.readFileSync(DIR + '/meta.json'));
for (let hero = 3; hero <= 10; hero++) {
  const c = (hero - 3) >> 1;
  for (const view of ['front', 'back']) for (const anim in NF) for (let f = 0; f < NF[anim]; f++) {
    const t = f / NF[anim] * Math.PI, ps = pose(hero, anim, f, NF[anim], t), J = ps.J;
    const HAR = J[9], u = n(J[19].map((v, i) => v - J[18][i]));
    let G, T;
    if (c === 2) { G = add(HAR, u, 0.55); T = add(HAR, u, 1.04); }
    else { const gL = [0.42, 0.1, 0, 0.08][c], bL = [1.13, 0.9, 0, 0.55][c]; G = add(HAR, u, gL); T = add(G, u, bL); }
    const y = YAW[view], proj = q => { const w = [q[0] * Math.cos(y) + q[2] * Math.sin(y), q[1], -q[0] * Math.sin(y) + q[2] * Math.cos(y)];
      return [(w[0] - CX) * 72 + WW * 72 / 2, WH * 72 / 2 - ((w[1] * Math.cos(PITCH) - w[2] * Math.sin(PITCH)) - CY) * 72]; };
    const k = `h${hero}_${view}_${anim}_${f}`; M[k] = Object.assign(M[k] || {}, { g: proj(G), t: proj(T) });
  }
}
fs.writeFileSync(DIR + '/meta.json', JSON.stringify(M));

// node render.js <outdir> [hero] [anims] [views] [ss]
const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');
const { pose } = require('./pose.js');
const OUT = process.argv[2] || 'out';
const HEROES = (process.argv[3] || '0,1').split(',').map(Number);
const ANIMS = (process.argv[4] || 'idle,walk,attack,hurt').split(',');
const VIEWS = (process.argv[5] || 'front,back').split(',');
const SS = +(process.argv[6] || 2);
const NF = { idle: 6, walk: 8, attack: 6, hurt: 2 };
const PPU = 72 * SS, PITCH = 30 * Math.PI / 180;
const WW = 5.4, WH = 4.1, CX = 0, CY = 1.05;
const W = Math.round(WW * PPU), H = Math.round(WH * PPU);
const YAW = { front: 45 * Math.PI / 180, back: 135 * Math.PI / 180 };
fs.mkdirSync(OUT, { recursive: true });
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage();
  p.on('console', m => console.log('[page]', m.text()));
  const src = fs.readFileSync(path.join(__dirname, process.env.SHADER||'shader.glsl'), 'utf8');
  await p.evaluate(([src, W, H]) => {
    const c = document.createElement('canvas'); c.width = W; c.height = H; document.body.appendChild(c);
    const g = c.getContext('webgl2', { preserveDrawingBuffer: true, premultipliedAlpha: false, antialias: false });
    const vs = `#version 300 es\nin vec2 a;void main(){gl_Position=vec4(a,0,1);}`;
    const mk = (t, s) => { const sh = g.createShader(t); g.shaderSource(sh, s); g.compileShader(sh); if (!g.getShaderParameter(sh, g.COMPILE_STATUS)) throw new Error(g.getShaderInfoLog(sh)); return sh; };
    const pr = g.createProgram(); g.attachShader(pr, mk(g.VERTEX_SHADER, vs)); g.attachShader(pr, mk(g.FRAGMENT_SHADER, src)); g.linkProgram(pr);
    if (!g.getProgramParameter(pr, g.LINK_STATUS)) throw new Error(g.getProgramInfoLog(pr));
    g.useProgram(pr);
    const bf = g.createBuffer(); g.bindBuffer(g.ARRAY_BUFFER, bf); g.bufferData(g.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), g.STATIC_DRAW);
    const al = g.getAttribLocation(pr, 'a'); g.enableVertexAttribArray(al); g.vertexAttribPointer(al, 2, g.FLOAT, false, 0, 0);
    window.R = (u) => {
      const L = n => g.getUniformLocation(pr, n);
      g.uniform2f(L('uRes'), W, H); g.uniform1f(L('uYaw'), u.yaw); g.uniform1f(L('uPitch'), u.pitch); g.uniform1f(L('uPPU'), u.ppu);
      g.uniform2f(L('uCenter'), u.cx, u.cy); g.uniform1i(L('uHero'), u.hero); g.uniform1f(L('uT'), u.t);
      g.uniform3fv(L('J'), new Float32Array(u.J.flat()));
      g.viewport(0, 0, W, H); g.clearColor(0, 0, 0, 0); g.clear(g.COLOR_BUFFER_BIT); g.drawArrays(g.TRIANGLES, 0, 3);
      return c.toDataURL('image/png');
    };
  }, [src, W, H]);
  const meta = {};
  for (const hero of HEROES) for (const view of VIEWS) for (const anim of ANIMS) {
    for (let f = 0; f < NF[anim]; f++) {
      const t = f / NF[anim] * Math.PI;
      const ps = pose(hero, anim, f, NF[anim], t);
      const t0 = Date.now();
      const url = await p.evaluate(u => window.R(u), { yaw: YAW[view], pitch: PITCH, ppu: PPU, cx: CX, cy: CY, hero, t, J: ps.J });
      const fn = `${OUT}/h${hero}_${view}_${anim}_${f}.png`;
      fs.writeFileSync(fn, Buffer.from(url.split(',')[1], 'base64'));
      // projected blade tip (pixel coords at 1x)
      const proj = q => { const w = [q[0] * Math.cos(YAW[view]) + q[2] * Math.sin(YAW[view]), q[1], -q[0] * Math.sin(YAW[view]) + q[2] * Math.cos(YAW[view])];
        const sx = w[0], sy = w[1] * Math.cos(PITCH) - w[2] * Math.sin(PITCH);
        return [(sx - CX) * 72 + WW * 72 / 2, WH * 72 / 2 - (sy - CY) * 72]; };
      meta[`h${hero}_${view}_${anim}_${f}`] = { tip: proj(ps.bladeTip), wt: proj(ps.WT), foot: proj([0, 0, 0]) };
      console.log(fn, Date.now() - t0, 'ms');
    }
  }
  const mf = `${OUT}/meta.json`; let old = {}; try { old = JSON.parse(fs.readFileSync(mf)); } catch (e) { }
  fs.writeFileSync(mf, JSON.stringify(Object.assign(old, meta)));
  await b.close();
})().catch(e => { console.error(e); process.exit(1); });

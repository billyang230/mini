// 掉落查詢：輸入或選擇物品，列出會掉它的怪物、所在地圖，以及套用目前倍率後的機率
(() => {
  const DQ = { idx: null, at: 0, mul: 1, loading: false, q: "", cat: "all", sel: null, host: null };
  window.__dropQ = DQ;

  const esc = s => String(s == null ? "" : s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const clean = n => String(n || "").replace(/^★/, "").replace(/^\+\d+\s*/, "").trim();
  const catOf = icon => /\/weapons\//.test(icon) ? "wpn" : /\/armors\//.test(icon) ? "arm" : "etc";
  const fmt = p => (p >= 1 ? +(+p).toFixed(2) : +(+p).toPrecision(2)) + "%";

  const css = `
.dq-wrap{padding:8px 6px 16px}
.dq-mul{font-size:12px;color:#c9b88a;background:#1d150d;border:1px solid #4a3a20;border-radius:8px;padding:6px 10px;margin-bottom:8px;line-height:1.5}
.dq-mul b{color:#f5c451}
.dq-search{display:flex;gap:6px;margin-bottom:8px}
.dq-search input{flex:1;min-width:0;background:#0f0b07;border:1px solid #5a4a26;color:#f3e9d2;border-radius:8px;padding:10px 12px;font-size:16px}
.dq-search button{background:#2a2013;border:1px solid #5a4a26;color:#d8cba8;border-radius:8px;padding:0 12px;font-size:14px}
.dq-cats{display:flex;gap:6px;margin-bottom:8px;flex-wrap:wrap}
.dq-cat{padding:5px 12px;border-radius:14px;border:1px solid #4a3a20;background:#1d150d;color:#c9b88a;font-size:13px;cursor:pointer}
.dq-cat.on{background:#c19a4a;border-color:#c19a4a;color:#1a1208;font-weight:700}
.dq-row{display:flex;align-items:center;gap:10px;padding:8px 6px;border-bottom:1px solid #2a2013;cursor:pointer}
.dq-row:active{background:#2a2013}
.dq-row img{width:34px;height:34px;object-fit:contain;flex:none}
.dq-mid{flex:1;min-width:0}
.dq-n{color:#f3e9d2;font-size:14px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.dq-sub{color:#8a7a55;font-size:11.5px;margin-top:2px;line-height:1.4}
.dq-p{color:#f5c451;font-size:14px;font-weight:700;text-align:right;flex:none}
.dq-p small{display:block;font-size:10px;color:#8a7a55;font-weight:400}
.dq-hd{display:flex;align-items:center;gap:10px;padding:4px 2px 10px;border-bottom:1px solid #4a3a20;margin-bottom:4px}
.dq-hd img{width:44px;height:44px;object-fit:contain}
.dq-hd .dq-n{font-size:16px;font-weight:700;color:#f5c451;white-space:normal}
.dq-back{background:#2a2013;border:1px solid #5a4a26;color:#d8cba8;border-radius:8px;padding:6px 10px;font-size:13px;flex:none}
.dq-empty{text-align:center;color:#8a7a55;padding:24px 10px;font-size:13px}
.dq-boss{color:#f87171}
.dq-src{margin-top:8px;font-size:13px;color:#93c5fd;cursor:pointer;text-decoration:underline}
#mob-drops .drop-row{cursor:pointer}
`;
  const st = document.createElement("style");
  st.textContent = css;
  document.head.appendChild(st);

  // 怪物 → 地圖
  let zoneMap = null;
  function zonesOf(mon) {
    if (!zoneMap) {
      zoneMap = {};
      const zs = (window.MOCK_DATA && MOCK_DATA.zones) || [];
      zs.forEach(z => (z.mobs || []).forEach(m => (zoneMap[m] = zoneMap[m] || []).push(z.name)));
    }
    return zoneMap[mon] || [];
  }

  function build(res) {
    const items = {};
    (res.mons || []).forEach(m => {
      const md = (window.MOCK_DATA && MOCK_DATA.mons && MOCK_DATA.mons[m.name]) || {};
      (m.drops || []).forEach(d => {
        const it = items[d.n] || (items[d.n] = { n: d.n, icon: d.icon, cat: catOf(d.icon), src: [], best: 0 });
        it.src.push({ mon: m.name, lv: m.lv, img: md.img || "", pct: d.pct, base: d.base, zones: zonesOf(m.name) });
        if (d.pct > it.best) it.best = d.pct;
      });
    });
    Object.values(items).forEach(it => it.src.sort((a, b) => b.pct - a.pct || a.lv - b.lv));
    DQ.idx = items;
    DQ.mul = res.mul;
    DQ.at = Date.now();
  }

  // 向遊戲要所有怪物的掉落（與怪物資訊視窗同一套算法、同一個倍率）
  let pending = [];
  DQ.load = function (cb) {
    if (DQ.idx && Date.now() - DQ.at < 60000) return cb && cb();
    if (cb) pending.push(cb);
    if (DQ.loading) return;
    if (typeof socket === "undefined" || !socket) return;
    DQ.loading = true;
    if (!DQ._hooked) {
      DQ._hooked = true;
      socket.on("dropIndexResult", res => {
        DQ.loading = false;
        try { build(res || {}); } catch (e) { console.error(e); }
        const p = pending; pending = [];
        p.forEach(f => { try { f(); } catch (e) { console.error(e); } });
      });
    }
    socket.emit("dropIndex");
  };

  DQ.has = name => !!(DQ.idx && DQ.idx[clean(name)]);

  DQ.render = function (host) {
    DQ.host = host;
    if (!DQ.idx || Date.now() - DQ.at >= 60000) {
      if (!DQ.idx) host.innerHTML = '<div class="dq-empty">讀取掉落資料中…</div>';
      DQ.load(() => { if (DQ.host && DQ.host.isConnected) DQ.render(DQ.host); });
      if (!DQ.idx) return;
    }
    if (DQ.sel && DQ.idx[DQ.sel]) return renderItem(host, DQ.idx[DQ.sel]);
    DQ.sel = null;
    renderList(host);
  };

  function mulBox() {
    return `<div class="dq-mul">目前掉寶倍率 <b>×${esc(DQ.mul)}</b>，以下機率都已套用倍率（每隻怪最高 100%）。點怪物可看牠的完整資料。</div>`;
  }

  function renderList(host) {
    host.innerHTML = `<div class="dq-wrap">${mulBox()}
      <div class="dq-search"><input id="dq-in" type="search" placeholder="搜尋物品名稱，例如：歐西斯、藥水" value="${esc(DQ.q)}" autocomplete="off" enterkeyhint="search"><button id="dq-clr">清除</button></div>
      <div class="dq-cats">${[["all", "全部"], ["wpn", "武器"], ["arm", "防具"], ["etc", "道具"]].map(c => `<span class="dq-cat${DQ.cat === c[0] ? " on" : ""}" data-c="${c[0]}">${c[1]}</span>`).join("")}</div>
      <div id="dq-list"></div></div>`;
    const inp = host.querySelector("#dq-in");
    inp.oninput = () => { DQ.q = inp.value; fill(); };
    host.querySelector("#dq-clr").onclick = () => { DQ.q = ""; inp.value = ""; fill(); };
    host.querySelectorAll(".dq-cat").forEach(el => el.onclick = () => {
      DQ.cat = el.dataset.c;
      host.querySelectorAll(".dq-cat").forEach(x => x.classList.toggle("on", x === el));
      fill();
    });
    host.querySelector("#dq-list").onclick = e => {
      const r = e.target.closest(".dq-row[data-i]");
      if (!r) return;
      DQ.sel = r.dataset.i;
      DQ.render(host);
      const ps = document.getElementById("panel-scroll");
      if (ps) ps.scrollTop = 0;
    };
    fill();
  }

  function fill() {
    const box = DQ.host && DQ.host.querySelector("#dq-list");
    if (!box) return;
    const words = DQ.q.trim().toLowerCase().split(/\s+/).filter(Boolean);
    let list = Object.values(DQ.idx).filter(it => (DQ.cat === "all" || it.cat === DQ.cat) && words.every(w => it.n.toLowerCase().includes(w)));
    list.sort((a, b) => {
      if (words.length) {
        const sa = a.n.toLowerCase().startsWith(words[0]) ? 0 : 1, sb = b.n.toLowerCase().startsWith(words[0]) ? 0 : 1;
        if (sa !== sb) return sa - sb;
      }
      return a.n.localeCompare(b.n, "zh-Hant");
    });
    const total = list.length, LIM = 150;
    list = list.slice(0, LIM);
    box.innerHTML = total
      ? list.map(it => `<div class="dq-row" data-i="${esc(it.n)}"><img src="${esc(it.icon)}" loading="lazy" onerror="this.style.visibility='hidden'"><div class="dq-mid"><div class="dq-n">${esc(it.n)}</div><div class="dq-sub">${it.src.length} 種怪物會掉</div></div><div class="dq-p">${fmt(it.best)}<small>最高</small></div></div>`).join("")
        + (total > LIM ? `<div class="dq-empty">還有 ${total - LIM} 項，輸入關鍵字縮小範圍</div>` : "")
      : `<div class="dq-empty">找不到「${esc(DQ.q)}」的掉落資料<br>（可能是商店、合成或活動才拿得到）</div>`;
  }

  function renderItem(host, it) {
    host.innerHTML = `<div class="dq-wrap">
      <div class="dq-hd"><img src="${esc(it.icon)}" onerror="this.style.visibility='hidden'"><div class="dq-mid"><div class="dq-n">${esc(it.n)}</div><div class="dq-sub">${it.src.length} 種怪物會掉・倍率 ×${esc(DQ.mul)}</div></div><button class="dq-back" id="dq-back">‹ 返回</button></div>
      ${it.src.map(s => {
        const z = s.zones.length ? esc(s.zones.join("、")) : '<span class="dq-boss">BOSS／特殊出現</span>';
        const base = s.base != null && s.base !== s.pct ? `<small>原 ${fmt(s.base)}</small>` : "";
        return `<div class="dq-row" data-m="${esc(s.mon)}"><img src="${esc(s.img)}" loading="lazy" onerror="this.style.visibility='hidden'"><div class="dq-mid"><div class="dq-n">${esc(s.mon)} <span style="color:#8a7a55;font-size:12px">Lv${esc(s.lv)}</span></div><div class="dq-sub">📍 ${z}</div></div><div class="dq-p">${fmt(s.pct)}${base}</div></div>`;
      }).join("")}</div>`;
    host.querySelector("#dq-back").onclick = () => { DQ.sel = null; DQ.render(host); };
    host.querySelectorAll(".dq-row[data-m]").forEach(r => r.onclick = () => {
      try { mn = !1; } catch (e) {}
      socket && socket.emit("mobInfo", r.dataset.m);
    });
  }

  // 從別處（物品視窗、怪物視窗）跳到查詢頁並選好物品
  DQ.open = function (name) {
    name = clean(name);
    DQ.sel = name; DQ.q = "";
    ["item-popup", "mob-popup"].forEach(id => { const el = document.getElementById(id); el && el.classList.add("hidden"); });
    try {
      document.querySelectorAll("#tabbar .tab").forEach(x => x.classList.remove("active"));
      const tb = document.querySelector('#tabbar .tab[data-tab="set"]');
      tb && tb.classList.add("active");
      t = "set"; _e = "drop";
      Vr();
      const ps = document.getElementById("panel-scroll");
      if (ps) ps.scrollTop = 0;
    } catch (e) { console.error(e); }
  };

  function hook() {
    // 物品視窗：會掉的物品多一行「查掉落來源」
    if (typeof window.pr === "function" && !window.pr.__dq) {
      const orig = window.pr;
      const w = function (it, desc) {
        const r = orig.apply(this, arguments);
        try {
          const old = document.getElementById("dq-src");
          old && old.remove();
          const name = it && clean(it.n);
          if (!name) return r;
          const add = () => {
            if (!DQ.has(name) || document.getElementById("dq-src")) return;
            const d = document.getElementById("ip-desc");
            if (!d) return;
            const a = document.createElement("div");
            a.id = "dq-src"; a.className = "dq-src";
            a.textContent = "🔍 查這個物品從哪隻怪掉";
            a.onclick = () => DQ.open(name);
            d.insertAdjacentElement("afterend", a);
          };
          DQ.idx ? add() : DQ.load(add);
        } catch (e) {}
        return r;
      };
      w.__dq = true;
      window.pr = w;
    }
    // 怪物視窗：點掉落物品 → 查它還會從哪些怪掉
    const md = document.getElementById("mob-drops");
    if (md && !md.__dq) {
      md.__dq = true;
      md.addEventListener("click", e => {
        const r = e.target.closest(".drop-row");
        const n = r && r.querySelector(".drop-n");
        if (n) DQ.open(n.textContent);
      });
    }
  }
  hook();
  document.addEventListener("DOMContentLoaded", hook);
})();

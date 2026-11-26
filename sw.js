// 迷你測試服：快取靜態檔，第二次起開啟幾乎秒開
const V = "mini-sw-1";
const STATIC = /\/(assets\/|vendor\/|boot-pack-[^/]+\.json$|assets-index\.json$)/;
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", e => {
  e.waitUntil((async () => {
    for (const k of await caches.keys()) if (k !== V && k.indexOf("mini-sw") === 0) await caches.delete(k);
    await self.clients.claim();
  })());
});
self.addEventListener("fetch", e => {
  const r = e.request, u = new URL(r.url);
  if (r.method !== "GET" || u.origin !== location.origin) return; // Supabase 等外部請求不碰
  if (STATIC.test(u.pathname)) {
    // 圖片、資料包：有快取就直接用
    e.respondWith(caches.open(V).then(async c => {
      const hit = await c.match(r);
      if (hit) return hit;
      const res = await fetch(r);
      if (res.ok) c.put(r, res.clone());
      return res;
    }));
  } else {
    // 程式與網頁：優先拿最新，斷線才用快取
    // 不用瀏覽器 HTTP 快取（GitHub Pages 會快取 10 分鐘），每次都向伺服器確認最新版
    e.respondWith(fetch(u.href, { cache: "no-cache", credentials: "same-origin" }).then(res => {
      if (res.ok) caches.open(V).then(c => c.put(r, res.clone()));
      return res;
    }).catch(() => caches.match(r)));
  }
});

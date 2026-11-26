// 迷你測試服：開啟圓圈撞圓圈模式（KMSRV）；瀏覽器暫存的鍵名都加 "mini:" 前綴，和同網域的可樂測試服（記住帳密等）分開
(function () {
  window.KMSRV = 1;
  var P = "mini:", S;
  try { S = window.localStorage; } catch (e) { return; }
  function keys() { var a = []; for (var i = 0; i < S.length; i++) { var k = S.key(i); k && k.indexOf(P) === 0 && a.push(k.slice(P.length)); } return a; }
  var L = {
    getItem: function (k) { return S.getItem(P + k); },
    setItem: function (k, v) { S.setItem(P + k, String(v)); },
    removeItem: function (k) { S.removeItem(P + k); },
    clear: function () { keys().forEach(function (k) { S.removeItem(P + k); }); },
    key: function (i) { return keys()[i] == null ? null : keys()[i]; }
  };
  Object.defineProperty(L, "length", { get: function () { return keys().length; } });
  try { Object.defineProperty(window, "localStorage", { configurable: true, get: function () { return L; } }); } catch (e) { console.error("[mini] localStorage 分流失敗", e); }
})();

// 在畫面上顯示線上模式的實際錯誤，方便手機除錯
(() => {
  const show = (args) => {
    try {
      const parts = args.map(a => a && typeof a === 'object' ? (a.message || a.details || a.hint || JSON.stringify(a)) : String(a));
      const t = parts.join(' ').slice(0, 300);
      if (!/error|失敗|denied|permission|exist|violat|42|PGRST/i.test(t)) return;
      const el = document.getElementById('login-msg');
      if (el) { el.style.whiteSpace = 'pre-wrap'; el.textContent = (el.textContent ? el.textContent + '\n' : '') + '［除錯］' + t; }
    } catch (e) {}
  };
  const w = console.warn.bind(console), er = console.error.bind(console);
  console.warn = (...a) => { show(a); w(...a); };
  console.error = (...a) => { show(a); er(...a); };
})();

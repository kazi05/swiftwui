// SwiftWUI dev client — injected by `swiftwui dev`. Never shipped to production.
(() => {
  const es = new EventSource("/__swiftwui/events");
  es.addEventListener("reload", () => {
    try {
      // Synchronous: the wasm runtime writes the @State snapshot to
      // sessionStorage inside this dispatch (DevReload, spec §7).
      window.dispatchEvent(new CustomEvent("swiftwui:dev-snapshot-request"));
    } catch (e) { /* never block the reload */ }
    location.reload();
  });
  es.addEventListener("build-error", (e) => {
    let text = e.data;
    try { text = JSON.parse(e.data); } catch (_) {}
    showOverlay(text);
  });
  function showOverlay(text) {
    let el = document.getElementById("__swiftwui-error-overlay");
    if (!el) {
      el = document.createElement("pre");
      el.id = "__swiftwui-error-overlay";
      el.style.cssText =
        "position:fixed;inset:0;z-index:2147483647;margin:0;padding:24px;" +
        "overflow:auto;background:rgba(20,0,0,.92);color:#ff8080;" +
        "font:12px/1.5 ui-monospace,SFMono-Regular,monospace;white-space:pre-wrap";
      document.documentElement.appendChild(el);
    }
    el.textContent = "swiftwui build failed\n\n" + text;
  }
})();

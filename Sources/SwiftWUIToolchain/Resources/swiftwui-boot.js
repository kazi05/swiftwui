// SwiftWUI boot shim. Copied verbatim from toolchain resources to
// dist/app/swiftwui-boot.js and loaded as a module by the tag carrying the
// build's boot config.
//
// Contract with the document (boot spec §4, §6):
//   <html data-swui-boot="downloading|starting|failed">   absent === ready
//   <html data-swui-boot-progress="unknown">              size not stamped
//   --swui-boot-progress: 0…1  on <html>                  size known
//   <template data-swui-boot-ui>                          cloned in once shown
//   [data-swui-boot-veil]                                 real content, CSS-hidden
//   [data-swui-boot-retry]                                delegated reload
//
// No JS test harness exists in this repo, so this file carries its reasoning in
// comments; the only other coverage is the browser acceptance checklist.

const root = document.documentElement;
const tag = document.querySelector("script[data-swui-boot-config]");
// Invariant for every emitter of the shim's script tag (SSG, build splice, dev
// serving): the config travels on the tag. Named here because the unguarded
// deref below would otherwise report it as "cannot read properties of null".
if (!tag) throw new Error("swiftwui-boot.js loaded without data-swui-boot-config");
const cfg = {
  wasm: tag.dataset.wasm,
  entry: tag.dataset.entry,
  // ?? and not ||: `after: .ms(0)` is a documented setting and `"0" || 300`
  // silently becomes 300. `data-size` is omitted outright when unknown.
  size: Number(tag.dataset.size ?? 0),
  delay: Number(tag.dataset.delay ?? 300),
};
const MIN_SHOW_MS = 300;    // once shown, stay shown this long (§6.3)
const STALL_MS = 30000;     // no byte for this long === failed (§6.4)

// Taken before init(): templates exist from parse time, and init() is called
// while the download is still streaming, so a later snapshot could miss them —
// DOMRuntime.mount() detaches them from inside init(). These references keep
// them alive and a detached <template>'s .content still clones, which is what
// makes a post-mount failure recoverable (§6.4).
const bootTemplates = [...document.querySelectorAll("template[data-swui-boot-ui]")];

let state = "downloading";  // what show() would display; "ready" is terminal
let shownAt = 0;
let showTimer = 0;
let stallTimer = 0;

/// Clone every retained template into the document, once.
function instantiateBootUI() {
  if (document.querySelector("[data-swui-boot-ui]:not(template)")) return;
  for (const t of bootTemplates) {
    // Height of the real subtree this placeholder stands in for, measured
    // before <html> takes the state attribute — the veil rule display:none's
    // those elements and a hidden element measures 0. The clone itself is inert
    // until the attribute lands (BootCSS hides [data-swui-boot-ui] while the
    // page is ready), so inserting it below cannot disturb the measurement.
    // `content` may resolve to several veiled roots: sum the contiguous run.
    let veiled = 0;
    for (let el = t.nextElementSibling;
         el && el.hasAttribute("data-swui-boot-veil");
         el = el.nextElementSibling) {
      veiled += el.getBoundingClientRect().height;
    }

    const frag = t.content.cloneNode(true);
    const roots = [];
    // EVERY inserted root must carry the marker. `_BootTemplate` stamps the
    // <template> ELEMENT and never its children, and inserting a fragment
    // inserts those children as siblings — so an unstamped clone is invisible
    // both to BootShim.stripBootNodes(), which selects [data-swui-boot-ui]
    // (it then survives into AdoptingBackend's stream and cold-boots the whole
    // page), and to BootCSS's html:not([data-swui-boot]) rule, so it would
    // never disappear on ready either.
    for (let node of [...frag.childNodes]) {
      if (node.nodeType !== Node.ELEMENT_NODE) {
        // A text root — `.whileBooting { Text("Loading…") }` resolves to one —
        // cannot carry an attribute. Wrap it rather than leave it unstrippable.
        const span = document.createElement("span");
        node.replaceWith(span);
        span.append(node);
        node = span;
      }
      node.setAttribute("data-swui-boot-ui", "");
      roots.push(node);
    }

    if (t.isConnected) t.before(frag);
    else document.body.appendChild(frag);   // stripped at mount: §6.4 re-instantiation

    // Two unattributed layout shifts otherwise — one when the placeholder takes
    // the veiled element's place, one when it gives it back. Never cleared, and
    // does not need to be: stripBootNodes() removes the clone outright at mount.
    if (veiled > 0 && roots.length) roots[0].style.minHeight = veiled + "px";
  }
}

/// Display the current state. The first call starts the minimum-show clock.
function show() {
  if (state === "ready") return;
  instantiateBootUI();
  if (!shownAt) shownAt = performance.now();
  // Unknown size: authors style an indeterminate spinner off this attribute
  // rather than a progress value that would be a lie.
  if (!cfg.size) root.dataset.swuiBootProgress = "unknown";
  root.dataset.swuiBoot = state;
}

function minShowRemaining() {
  const left = shownAt ? MIN_SHOW_MS - (performance.now() - shownAt) : 0;
  return left > 0 ? new Promise((r) => setTimeout(r, left)) : Promise.resolve();
}

function fail(err) {
  // Not merely tidy: the stall interval outlives a rejected init(), and a
  // second fail() would append a second copy of the failure UI. `failed` is
  // terminal for everything except a stall that later recovers — see the
  // stream's `state = "starting"`.
  if (state === "failed" || state === "ready") return;
  console.error("SwiftWUI boot failed:", err);
  clearTimeout(showTimer);
  clearInterval(stallTimer);
  state = "failed";
  show();   // re-instantiates from the retained templates if mount() stripped them
}

// Delegated: the retry control does not exist until the failure UI is
// instantiated, and §6.4 can instantiate a fresh one after mount.
document.addEventListener("click", (e) => {
  if (!e.target.closest || !e.target.closest("[data-swui-boot-retry]")) return;
  const u = new URL(location.href);
  u.searchParams.delete("swui-boot");   // never reload back into a forced state
  // replace() with an unchanged URL that has a fragment is a same-document
  // fragment navigation — it would not reload, leaving the retry button dead.
  if (u.href === location.href) location.reload();
  else location.replace(u);
});

// --- form state across hydration --------------------------------------------
// Keyed by the element reference itself: adoption reuses the existing DOM
// nodes, so no path or id scheme is needed.
const captured = new Map();
let lastFocused = null;

function capture(e) {
  const el = e.target;
  if (!el || !("value" in el)) return;
  // Re-insert rather than overwrite: a Map keeps FIRST-insertion order across a
  // re-set, and checking radio B fires no event on the radio it unchecks, so
  // the loser keeps a stale checked:true. An A→B→A run would otherwise replay
  // B last and submit the option the user moved away from.
  captured.delete(el);
  captured.set(el, {
    value: el.value,
    checked: el.checked,
    selectionStart: el.selectionStart,
    selectionEnd: el.selectionEnd,
  });
  lastFocused = el;
}
document.addEventListener("input", capture, true);
document.addEventListener("change", capture, true);

function restore() {
  for (const [el, s] of captured) {
    if (!el.isConnected) continue;   // adoption failed → cold boot rebuilt the DOM
    // try per ELEMENT, never around the loop: a file input rejects a non-empty
    // value assignment with InvalidStateError, and setSelectionRange throws on
    // input types that have no selection. One outer try would abandon the
    // restore for every element after the first such throw.
    try {
      if (el.type !== "file" && el.value !== s.value) el.value = s.value;
      if (el.checked !== s.checked) el.checked = s.checked;
      el.setSelectionRange(s.selectionStart, s.selectionEnd);
    } catch { /* per element */ }
  }
  // Only when the user has not moved on — otherwise the restore yanks the caret
  // out from under them.
  if (document.activeElement === document.body && lastFocused && lastFocused.isConnected) {
    lastFocused.focus();
  }
  // Released here and not on a terminal state: this is the last read of the
  // Map. Left attached, the capture listeners run on every keystroke of the
  // live app and the Map grows without bound, holding strong references to
  // inputs an SPA navigation has long since detached.
  document.removeEventListener("input", capture, true);
  document.removeEventListener("change", capture, true);
  captured.clear();
  lastFocused = null;
}

// --- boot --------------------------------------------------------------------
// Honoured ONLY under the dev flag DevInjection writes into every dev-served
// document. In a built dist/ a forced `failed` on a real URL is a dead page
// with the site's own content veiled behind its error UI (§9.3).
const debug = window.__swiftwui_dev === true
  ? new URLSearchParams(location.search).get("swui-boot")
  : null;

showTimer = setTimeout(show, cfg.delay);

(async () => {
  try {
    if (debug === "fail") throw new Error("forced by ?swui-boot=fail");
    // No credentials option: a bare `crossorigin` on the preload link is the
    // Anonymous keyword — cors + same-origin — which is fetch's default.
    // credentials:"omit" mismatches the preload key and downloads the binary a
    // second time; dropping crossorigin makes the preload no-cors, whose opaque
    // response has a null body and cannot be read at all (§8.1).
    const res = await fetch(cfg.wasm);
    if (!res.ok) throw new Error("HTTP " + res.status + " for " + cfg.wasm);

    let loaded = 0;
    let lastByteAt = performance.now();
    // A stall, not a wall-clock timeout: a 3G client legitimately spends a
    // minute on this download, and failing it mid-transfer is self-inflicted.
    stallTimer = setInterval(() => {
      if (performance.now() - lastByteAt > STALL_MS) fail("stalled");
    }, 1000);

    const reader = res.body.getReader();
    const counted = new ReadableStream({
      async start(c) {
        for (;;) {
          const { done, value } = await reader.read();
          if (done) break;
          if (debug === "stall") await new Promise(() => {});
          if (debug === "slow") await new Promise((r) => setTimeout(r, 50));
          loaded += value.byteLength;
          lastByteAt = performance.now();
          // Counted against the build-stamped UNCOMPRESSED size, never
          // Content-Length: under brotli that header is the compressed length
          // while the reader yields decompressed bytes, which reports ~390%.
          // Clamped so stale HTML paired with a newer binary degrades instead
          // of failing. A custom property, so a progress bar is pure CSS and
          // the shim touches no element per chunk.
          if (cfg.size) {
            root.style.setProperty("--swui-boot-progress",
                                   String(Math.min(loaded / cfg.size, 0.99)));
          }
          c.enqueue(value);
        }
        clearInterval(stallTimer);
        // Deliberately unguarded against `failed`: a stall that recovers walks
        // back out of the failure UI and the page heals, rather than sitting
        // dead while the app boots behind it. mount()'s strip takes the failure
        // clones with it on that path.
        state = "starting";
        if (shownAt) show();
        // The minimum-show window is held HERE, on the stream, and not by
        // delaying the attribute removal: mount() deletes the boot nodes as its
        // first act and runs inside init(), so a late removal would leave a
        // stale attribute over an already-empty screen. instantiateStreaming
        // cannot finish before the stream closes, so main() cannot run early.
        await minShowRemaining();
        c.close();
      },
    });

    const { init } = await import(cfg.entry);
    // The content-type is mandatory: instantiateStreaming rejects without it,
    // and the fallback buffers the whole binary before compiling — which is the
    // streaming compile this whole design is built around.
    await init({
      module: new Response(counted, { headers: { "content-type": "application/wasm" } }),
    });

    clearTimeout(showTimer);
    state = "ready";
    delete root.dataset.swuiBoot;
    delete root.dataset.swuiBootProgress;
    root.style.removeProperty("--swui-boot-progress");
    restore();
  } catch (err) {
    fail(err);
  }
})();

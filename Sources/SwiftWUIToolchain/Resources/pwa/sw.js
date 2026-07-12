/* SwiftWUI PWA service worker — scaffolded by `swiftwui init --pwa`.
 * You own this file; edit freely. The build regenerates /sw-assets.js
 * (the precache list) on every `swiftwui build` / `swiftwui ssg`.
 *
 * Update model: a new deploy installs into a fresh versioned cache and
 * WAITS. It activates when every tab closes, or when the app calls
 * reloadToUpdate() (which posts SKIP_WAITING). Do not call skipWaiting()
 * unconditionally — swapping caches under a running wasm app is fatal.
 */
importScripts('/sw-assets.js');

const manifest = self.__SWIFTWUI_ASSETS;
const CACHE = `swiftwui-precache-${manifest.version}`;

/* Paths that must always hit the network (edit to taste). */
const NETWORK_ONLY_PREFIXES = [
  // '/api/',
];

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    // Atomic snapshot: any failure (including an integrity mismatch)
    // fails install and the previous version keeps serving.
    await Promise.all(manifest.assets.map(async ({ url, integrity }) => {
      const response = await fetch(new Request(url, { cache: 'no-cache', integrity }));
      if (!response.ok) throw new Error(`precache ${url}: HTTP ${response.status}`);
      await cache.put(url, response);
    }));
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names
      .filter((n) => n.startsWith('swiftwui-precache-') && n !== CACHE)
      .map((n) => caches.delete(n)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (NETWORK_ONLY_PREFIXES.some((p) => url.pathname.startsWith(p))) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    if (request.mode === 'navigate') {
      // History-API SPA: every route boots from the cached shell.
      const shell = await cache.match('/index.html');
      if (shell) return shell;
    }
    const hit = await cache.match(url.pathname);
    if (hit) return hit;
    return fetch(request); // cache miss -> network, no runtime caching
  })());
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') self.skipWaiting();
});

/* --- push (phase 8b) ---------------------------------------------------
 * Push-notification handlers land here in a later SwiftWUI phase; an
 * origin has exactly one service worker, so keep push logic in this file.
 * ---------------------------------------------------------------------- */

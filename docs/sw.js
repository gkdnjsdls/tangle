/* 탱클 피젯 service worker.
   Precaches the app shell plus the two third-party files the page needs, so a
   phone that has opened it once can run it with no network at all. Bump CACHE
   whenever index.html changes, or installed copies will keep the old build. */

var CACHE = "tangle-v6";

var SHELL = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./icon-192.png",
  "./icon-512.png",
  "./icon-512-maskable.png"
];

// cdnjs and Google Fonts both send permissive CORS headers, so these cache and
// replay cleanly. They are added individually: one unreachable CDN must not
// fail the whole install and leave the toy uninstallable.
var VENDOR = [
  "https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js",
  "https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600&display=swap"
];

self.addEventListener("install", function (e) {
  e.waitUntil(
    caches.open(CACHE).then(function (c) {
      return c.addAll(SHELL).then(function () {
        return Promise.all(VENDOR.map(function (u) {
          return c.add(u).catch(function () { return null; });
        }));
      });
    }).then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener("activate", function (e) {
  e.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(keys.map(function (k) {
        return k === CACHE ? null : caches.delete(k);
      }));
    }).then(function () { return self.clients.claim(); })
  );
});

self.addEventListener("fetch", function (e) {
  if (e.request.method !== "GET") return;
  e.respondWith(
    caches.match(e.request).then(function (hit) {
      if (hit) return hit;
      return fetch(e.request).then(function (res) {
        // Font files are fetched lazily by the stylesheet; keep whatever we get
        // so the second launch is fully offline.
        if (res && (res.ok || res.type === "opaque")) {
          var copy = res.clone();
          caches.open(CACHE).then(function (c) { c.put(e.request, copy); })
            .catch(function () { /* quota or opaque-put refusal: not fatal */ });
        }
        return res;
      }).catch(function () {
        return e.request.mode === "navigate" ? caches.match("./index.html") : Response.error();
      });
    })
  );
});

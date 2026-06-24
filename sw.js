importScripts(
  'https://storage.googleapis.com/workbox-cdn/releases/7.3.0/workbox-sw.js'
);

const CACHE_VERSION = '__CACHE_VERSION__';
const { routing, strategies, expiration, precaching, core } = workbox;

core.skipWaiting();
core.clientsClaim();

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys
          .filter(k => k.includes('lumiverse-') && !k.includes(CACHE_VERSION))
          .map(k => caches.delete(k))
      )
    )
  );
});

precaching.precacheAndRoute([
  { url: '/lumiverse.js', revision: CACHE_VERSION },
  { url: '/lumiverse.css', revision: CACHE_VERSION },
]);

routing.registerRoute(
  ({ url }) => url.pathname.startsWith('/api/reader/image') || url.pathname.startsWith('/api/image/'),
  new strategies.CacheFirst({
    cacheName: `lumiverse-reader-${CACHE_VERSION}`,
    plugins: [
      new expiration.ExpirationPlugin({ maxAgeSeconds: 24 * 60 * 60 }),
    ],
  })
);

routing.registerRoute(
  ({ url }) =>
    url.pathname.startsWith('/api/reader/chapter-info') ||
    url.pathname.startsWith('/api/reader/chapter-detail'),
  new strategies.StaleWhileRevalidate({
    cacheName: `lumiverse-api-${CACHE_VERSION}`,
    plugins: [
      new expiration.ExpirationPlugin({ maxAgeSeconds: 30 * 60 }),
    ],
  })
);

// Series metadata + stream data gets stale-while-revalidate
// Because it can change once in a while
routing.registerRoute(
  ({ url }) =>
    url.pathname.startsWith('/api/series/metadata') ||
    url.pathname.startsWith('/api/series/series-detail') ||
    url.pathname.startsWith('/api/stream/') ||
    url.pathname.startsWith('/api/series/all-by-reading-date') ||
    url.pathname.startsWith('/api/series/on-deck'),
  new strategies.StaleWhileRevalidate({
    cacheName: `lumiverse-api-${CACHE_VERSION}`,
    plugins: [
      new expiration.ExpirationPlugin({ maxAgeSeconds: 60 * 60 }),
    ],
  })
);

routing.registerRoute(
  ({ url, request }) =>
    url.pathname.startsWith('/api/account') ||
    url.pathname.startsWith('/api/lumiverse/') ||
    url.pathname.startsWith('/api/health') ||
    request.method !== 'GET',
  new strategies.NetworkOnly()
);

// everything else goes network first
routing.setDefaultHandler(new strategies.NetworkFirst());

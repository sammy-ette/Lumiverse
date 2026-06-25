let _listenerController = null;

export function eventKey(event) {
  return event.key ?? "";
}

export function addListener(type, listener) {
  if (!_listenerController) _listenerController = new AbortController();
  document.addEventListener(type, listener, { signal: _listenerController.signal });
}

export function removeListeners() {
  _listenerController?.abort();
  _listenerController = null;
}

export function scrollBy(amount) {
  if (document.fullscreenElement) {
    const host = document.querySelector('reader-page');
    const container = host?.shadowRoot?.querySelector('#reader-content');
    if (container) {
      container.scrollBy({ top: amount, behavior: 'smooth' });
      return;
    }
  }
  window.scrollBy({ top: amount, behavior: 'smooth' });
}

export function windowScrollTo(y) {
  window.scrollTo(0, y);
}

export function devicePixelRatio() {
  return window.devicePixelRatio || 1;
}

// Saved position used to sync scroll across zen transitions
let _savedPos = 0;

export function captureWindowScroll() {
  _savedPos = window.scrollY; // float precision, avoids plinth's Int truncation
}

export function captureElementScroll() {
  const host = document.querySelector('reader-page');
  const container = host?.shadowRoot?.querySelector('#reader-content');
  _savedPos = container?.scrollTop ?? 0;
}

export function applyScrollToElement() {
  requestAnimationFrame(() => {
    const host = document.querySelector('reader-page');
    const container = host?.shadowRoot?.querySelector('#reader-content');
    if (container) container.scrollTop = _savedPos;
  });
}

export function applyScrollToWindow() {
  requestAnimationFrame(() => {
    window.scrollTo(0, _savedPos);
  });
}

let _lazyObs = null;
let _mutObs = null;

export function observeLazyImages() {
  if (_lazyObs) _lazyObs.disconnect();
  if (_mutObs) _mutObs.disconnect();

  const host = document.querySelector('reader-page');
  const container = host?.shadowRoot?.querySelector('#reader-content');
  if (!container) return;

  _lazyObs = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        const img = entry.target;
        const src = img.dataset.src;
        if (src) {
          img.src = src;
          img.removeAttribute('data-src');
          _lazyObs.unobserve(img);
        }
      }
    }
  }, { rootMargin: '300px' });

  container.querySelectorAll('img[data-src]').forEach(img => _lazyObs.observe(img));

  _mutObs = new MutationObserver(mutations => {
    for (const mut of mutations) {
      for (const node of mut.addedNodes) {
        if (node.tagName === 'IMG' && node.hasAttribute('data-src')) {
          _lazyObs.observe(node);
        }
      }
    }
  });
  _mutObs.observe(container, { childList: true });
}

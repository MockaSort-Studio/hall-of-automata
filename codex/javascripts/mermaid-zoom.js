/* ═══════════════════════════════════════════════════════════════
   HALL OF AUTOMATA — Mermaid pan + zoom
   Makes every Mermaid diagram interactive via svg-pan-zoom.
   Compatible with Zensical / Material instant navigation.
   ═══════════════════════════════════════════════════════════════ */

const PAN_ZOOM_CDN =
  "https://cdn.jsdelivr.net/npm/svg-pan-zoom@3.6.1/dist/svg-pan-zoom.min.js";

const DIAGRAM_HEIGHT = 440; // px — consistent frame height

let _docObserver = null; // reused across navigations

function loadScript(src) {
  return new Promise(function (resolve) {
    if (document.querySelector('script[src="' + src + '"]')) {
      resolve();
      return;
    }
    const el = document.createElement("script");
    el.src = src;
    el.onload = resolve;
    document.head.appendChild(el);
  });
}

function activateSvg(svg) {
  if (svg.dataset.panZoomAttached) return;
  if (!window.svgPanZoom) return;

  // Guard immediately so re-entrant calls from the retry don't double-init
  svg.dataset.panZoomAttached = "1";

  const container = svg.closest(".mermaid");
  if (!container) return;

  // ── Container ──
  container.style.height   = DIAGRAM_HEIGHT + "px";
  container.style.overflow = "hidden";
  container.style.position = "relative";

  // ── SVG ── override Mermaid's inline max-width / width / height attrs
  svg.removeAttribute("width");
  svg.removeAttribute("height");
  svg.style.setProperty("max-width", "none", "important");
  svg.style.width   = "100%";
  svg.style.height  = "100%";
  svg.style.display = "block";

  // svgPanZoom needs the SVG to be laid out in the DOM with real pixel sizes.
  // If offsetWidth is 0 (hidden tab / not-yet-painted), defer and retry once.
  if (svg.getBoundingClientRect().width === 0) {
    svg.dataset.panZoomAttached = "";
    setTimeout(function () { activateSvg(svg); }, 150);
    return;
  }

  try {
    const pz = window.svgPanZoom(svg, {
      zoomEnabled:           true,
      controlIconsEnabled:   true,
      fit:                   true,
      center:                true,
      minZoom:               0.1,
      maxZoom:               10,
      zoomScaleSensitivity:  0.25,
      dblClickZoomEnabled:   false,
      mouseWheelZoomEnabled: true,
      preventMouseEventsDefault: true,
    });

    // Keep panned state after browser resize
    window.addEventListener("resize", function () {
      pz.resize();
      pz.fit();
      pz.center();
    });
  } catch (_) {
    // Safety net: clear guard and retry after a short paint tick
    svg.dataset.panZoomAttached = "";
    setTimeout(function () { activateSvg(svg); }, 200);
  }
}

function activateAll() {
  document.querySelectorAll(".mermaid > svg").forEach(activateSvg);
}

function startObserver() {
  if (_docObserver) _docObserver.disconnect();

  _docObserver = new MutationObserver(function (mutations) {
    mutations.forEach(function (mut) {
      mut.addedNodes.forEach(function (node) {
        if (!node) return;
        // Direct SVG child of .mermaid
        if (
          (node.nodeName === "svg" || node.nodeName === "SVG") &&
          node.closest && node.closest(".mermaid")
        ) {
          activateSvg(node);
          return;
        }
        // SVG inside a newly inserted subtree
        if (node.querySelectorAll) {
          node.querySelectorAll(".mermaid > svg").forEach(activateSvg);
        }
      });
    });
  });

  _docObserver.observe(document.body, { childList: true, subtree: true });
}

document$.subscribe(function () {
  loadScript(PAN_ZOOM_CDN).then(function () {
    // First pass — diagrams already in the DOM
    activateAll();
    // Broad observer for async-rendered diagrams
    startObserver();
    // Second pass after a paint tick for late Mermaid renders
    setTimeout(activateAll, 400);
  });
});

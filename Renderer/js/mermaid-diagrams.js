// Renders fenced ```mermaid blocks with the vendored Mermaid bundle.
// The bundle is loaded only when a document contains a diagram.
import { createDiagramZoomControls } from './diagram-zoom-controls.js';
import { rendererLabels } from './renderer-strings.js';

const BUNDLE_URL = 'vendor/mermaid/mermaid.min.js';
const SELECTOR = 'pre > code.language-mermaid';

let loading;
let counter = 0;
/** Rendered diagram element -> what is needed to draw it again (theme change). */
const diagrams = new WeakMap();

function loadMermaid() {
    if (window.mermaid) return Promise.resolve(window.mermaid);
    loading ??= new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = BUNDLE_URL;
        script.onload = () => window.mermaid ? resolve(window.mermaid) : (loading = undefined, reject(new Error('Mermaid did not initialise')));
        script.onerror = () => { loading = undefined; reject(new Error('Mermaid could not be loaded')); };
        document.head.appendChild(script);
    });
    return loading;
}

function configure(mermaid) {
    // `strict` makes Mermaid sanitise labels and refuse click handlers and raw HTML.
    mermaid.initialize({
        startOnLoad: false,
        securityLevel: 'strict',
        theme: document.documentElement.getAttribute('data-theme') === 'dark' ? 'dark' : 'default',
    });
}

async function drawSVG(mermaid, source) {
    const id = `boa-mermaid-${++counter}`;
    try {
        return (await mermaid.render(id, source)).svg;
    } finally {
        // A failed render leaves its scratch elements in the page.
        document.getElementById(id)?.remove();
        document.getElementById(`d${id}`)?.remove();
    }
}

/** Fixed zoom steps on top of the width Mermaid chose. */
function applyZoom(entry) {
    const svg = entry.viewport.querySelector('svg');
    if (!svg) return;
    svg.style.cssText = entry.baseStyle;
    const width = svg.viewBox?.baseVal?.width;
    if (entry.controls.factor === 1 || !width) return;
    svg.style.maxWidth = 'none';
    svg.style.width = `${width * entry.controls.factor}px`;
}

function setSVG(entry, svg) {
    entry.viewport.innerHTML = svg;
    entry.baseStyle = entry.viewport.querySelector('svg')?.style.cssText ?? '';
    applyZoom(entry);
}

function buildDiagram(svg, source) {
    const host = document.createElement('div');
    host.className = 'mermaid boa-diagram';
    const viewport = document.createElement('div');
    viewport.className = 'boa-diagram-viewport';
    viewport.tabIndex = 0;
    viewport.setAttribute('role', 'img');
    viewport.setAttribute('aria-label', 'Mermaid diagram');
    const entry = { source, viewport, baseStyle: '', controls: undefined };
    entry.controls = createDiagramZoomControls('mermaid-tools', () => applyZoom(entry));
    host.append(entry.controls.element, viewport);
    setSVG(entry, svg);
    diagrams.set(host, entry);
    return host;
}

function markFailed(pre, error) {
    pre.classList.add('mermaid-error');
    const note = document.createElement('div');
    note.className = 'mermaid-error-note';
    note.textContent = `${rendererLabels().mermaidSyntaxError}: ${String(error?.message || error).split('\n')[0]}`;
    pre.before(note);
}

/**
 * Replaces each mermaid code block under `root` with its diagram. A block that
 * cannot be drawn stays as a code block with a note above it. Blocks are drawn
 * one at a time because Mermaid's renderer is not re-entrant.
 */
export async function renderDiagrams(root, isCurrent = () => true) {
    const blocks = Array.from(root.querySelectorAll(SELECTOR));
    if (blocks.length === 0) return;
    let mermaid;
    try {
        mermaid = await loadMermaid();
    } catch (error) {
        blocks.forEach(code => markFailed(code.parentElement, error));
        return;
    }
    configure(mermaid);
    for (const code of blocks) {
        if (!isCurrent()) return;
        const pre = code.parentElement;
        const source = code.textContent || '';
        try {
            const svg = await drawSVG(mermaid, source);
            if (!isCurrent()) return;
            pre.replaceWith(buildDiagram(svg, source));
        } catch (error) {
            markFailed(pre, error);
        }
    }
}

/** Draws the diagrams already on screen again, e.g. after a light/dark switch. */
export async function restyleDiagrams(root) {
    const hosts = Array.from(root?.querySelectorAll('.boa-diagram') ?? []);
    if (hosts.length === 0 || !window.mermaid) return;
    configure(window.mermaid);
    for (const host of hosts) {
        const entry = diagrams.get(host);
        if (!entry) continue;
        try { setSVG(entry, await drawSVG(window.mermaid, entry.source)); } catch { /* keep the previous drawing */ }
    }
}

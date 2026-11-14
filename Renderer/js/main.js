// Page glue for the native renderer.
//
// Markdown is parsed in Swift (Packages/BoaRender). This page receives the
// finished HTML and the heading list, then adds what needs a browser:
// code highlighting (highlight.js), math typesetting (KaTeX), the table of
// contents, search, copy buttons and export.
import { installSVGZoom } from './svg-zoom.js';
import { constrainSVGImage } from './svg-image-layout.js';
import { installBlockCopy, blockCopyResult } from './block-copy.js';
import { waitForExportReady, prepareExport } from './export-readiness.js';
import { renderTSVTable } from './tsv.js';
import { rememberMathSource } from './math-source-store.js';
import { findSourceLineTarget } from './position-navigation.js';
import { buildHeadingTree } from './outline.js';
import { TableOfContents } from './table-of-contents.js';
import { ReadingStatus } from './reading-status.js';
import { ReadingControls, updateReadingControlsLayout, captureReadingAnchor, restoreReadingAnchor } from './reading-controls.js';
import { SearchEngine } from './search.js';
import { SearchUI } from './search-ui.js';
import { HelpOverlay } from './help-overlay.js';
import { BlockquoteCollapse } from './blockquote-collapse.js';
import { detectRtlContent } from './rtl.js';
import { rendererLabels } from './renderer-strings.js';
import { buildSourceHTML } from './source-view.js';

function escapeHtml(text) {
    const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
    return text.replace(/[&<>"']/g, (char) => map[char]);
}

function logToSwift(message) {
    try {
        const logger = window.webkit?.messageHandlers?.logger;
        if (logger) logger.postMessage(message);
        else console.log('Swift logger not found: ' + message);
    } catch (e) {
        console.log('Failed to log to Swift:', e);
    }
}

window.onerror = function (message, source, lineno) {
    logToSwift(`JS Error: ${message} at ${source}:${lineno}`);
};

logToSwift('JS: main.js loaded, starting execution...');

// MARK: Code highlighting

const LANG_ALIASES = {
    'js': 'javascript', 'ts': 'typescript', 'py': 'python', 'sh': 'bash', 'zsh': 'bash', 'rb': 'ruby', 'kt': 'kotlin',
    'cs': 'csharp', 'c++': 'cpp', 'objc': 'objectivec', 'gql': 'graphql', 'mk': 'makefile', 'text': 'plaintext',
    'html': 'xml', 'svg': 'xml', 'yml': 'yaml', 'toml': 'ini', 'md': 'markdown',
};

function highlightCodeBlocks(root) {
    const highlighter = window.hljs;
    root.querySelectorAll('pre > code').forEach(code => {
        const pre = code.parentElement;
        pre.classList.add('hljs');
        const declared = Array.from(code.classList).find(name => name.startsWith('language-'))?.slice(9).toLowerCase();
        const language = declared ? (LANG_ALIASES[declared] ?? declared) : '';
        if (!highlighter || !language || !highlighter.getLanguage(language)) return;
        try {
            // highlight.js escapes the source text itself; its output contains only its own spans.
            code.innerHTML = highlighter.highlight(code.textContent || '', { language, ignoreIllegals: true }).value;
        } catch (error) {
            logToSwift(`Highlight failed for ${language}: ${error}`);
        }
    });
}

const HLJS_THEMES = {
    'github': `pre code.hljs{display:block;overflow-x:auto;padding:1em}code.hljs{padding:3px 5px}.hljs{color:#24292e;background:#fff}.hljs-doctag,.hljs-keyword,.hljs-meta .hljs-keyword,.hljs-template-tag,.hljs-template-variable,.hljs-type,.hljs-variable.language_{color:#d73a49}.hljs-title,.hljs-title.class_,.hljs-title.class_.inherited__,.hljs-title.function_{color:#6f42c1}.hljs-attr,.hljs-attribute,.hljs-literal,.hljs-meta,.hljs-number,.hljs-operator,.hljs-selector-attr,.hljs-selector-class,.hljs-selector-id,.hljs-variable{color:#005cc5}.hljs-meta .hljs-string,.hljs-regexp,.hljs-string{color:#032f62}.hljs-built_in,.hljs-symbol{color:#e36209}.hljs-code,.hljs-comment,.hljs-formula{color:#6a737d}.hljs-name,.hljs-quote,.hljs-selector-pseudo,.hljs-selector-tag{color:#22863a}.hljs-subst{color:#24292e}.hljs-section{color:#005cc5;font-weight:700}.hljs-bullet{color:#735c0f}.hljs-emphasis{color:#24292e;font-style:italic}.hljs-strong{color:#24292e;font-weight:700}.hljs-addition{color:#22863a;background-color:#f0fff4}.hljs-deletion{color:#b31d28;background-color:#ffeef0}`,
    'monokai': `pre code.hljs{display:block;overflow-x:auto;padding:1em}code.hljs{padding:3px 5px}.hljs{background:#272822;color:#ddd}.hljs-keyword,.hljs-literal,.hljs-name,.hljs-number,.hljs-selector-tag,.hljs-strong,.hljs-tag{color:#f92672}.hljs-code{color:#66d9ef}.hljs-attr,.hljs-attribute,.hljs-link,.hljs-regexp,.hljs-symbol{color:#bf79db}.hljs-addition,.hljs-built_in,.hljs-bullet,.hljs-emphasis,.hljs-section,.hljs-selector-attr,.hljs-selector-pseudo,.hljs-string,.hljs-subst,.hljs-template-tag,.hljs-template-variable,.hljs-title,.hljs-type,.hljs-variable{color:#a6e22e}.hljs-class .hljs-title,.hljs-title.class_{color:#fff}.hljs-comment,.hljs-deletion,.hljs-meta,.hljs-quote{color:#75715e}.hljs-doctag,.hljs-keyword,.hljs-literal,.hljs-section,.hljs-selector-id,.hljs-selector-tag,.hljs-title,.hljs-type{font-weight:700}`,
    'atom-one-dark': `pre code.hljs{display:block;overflow-x:auto;padding:1em}code.hljs{padding:3px 5px}.hljs{color:#abb2bf;background:#282c34}.hljs-comment,.hljs-quote{color:#5c6370;font-style:italic}.hljs-doctag,.hljs-formula,.hljs-keyword{color:#c678dd}.hljs-deletion,.hljs-name,.hljs-section,.hljs-selector-tag,.hljs-subst{color:#e06c75}.hljs-literal{color:#56b6c2}.hljs-addition,.hljs-attribute,.hljs-meta .hljs-string,.hljs-regexp,.hljs-string{color:#98c379}.hljs-attr,.hljs-number,.hljs-selector-attr,.hljs-selector-class,.hljs-selector-pseudo,.hljs-template-variable,.hljs-type,.hljs-variable{color:#d19a66}.hljs-bullet,.hljs-link,.hljs-meta,.hljs-selector-id,.hljs-symbol,.hljs-title{color:#61aeee}.hljs-built_in,.hljs-class .hljs-title,.hljs-title.class_{color:#e6c07b}.hljs-emphasis{font-style:italic}.hljs-strong{font-weight:700}.hljs-link{text-decoration:underline}`,
};

const GITHUB_DARK_OVERRIDE = `[data-theme="dark"] .hljs{color:#c9d1d9;background:#0d1117}[data-theme="dark"] .hljs-doctag,[data-theme="dark"] .hljs-keyword,[data-theme="dark"] .hljs-meta .hljs-keyword,[data-theme="dark"] .hljs-template-tag,[data-theme="dark"] .hljs-template-variable,[data-theme="dark"] .hljs-type,[data-theme="dark"] .hljs-variable.language_{color:#ff7b72}[data-theme="dark"] .hljs-title,[data-theme="dark"] .hljs-title.class_,[data-theme="dark"] .hljs-title.class_.inherited__,[data-theme="dark"] .hljs-title.function_{color:#d2a8ff}[data-theme="dark"] .hljs-attr,[data-theme="dark"] .hljs-attribute,[data-theme="dark"] .hljs-literal,[data-theme="dark"] .hljs-meta,[data-theme="dark"] .hljs-number,[data-theme="dark"] .hljs-operator,[data-theme="dark"] .hljs-selector-attr,[data-theme="dark"] .hljs-selector-class,[data-theme="dark"] .hljs-selector-id,[data-theme="dark"] .hljs-variable{color:#79c0ff}[data-theme="dark"] .hljs-meta .hljs-string,[data-theme="dark"] .hljs-regexp,[data-theme="dark"] .hljs-string{color:#a5d6ff}[data-theme="dark"] .hljs-built_in,[data-theme="dark"] .hljs-symbol{color:#ffa657}[data-theme="dark"] .hljs-code,[data-theme="dark"] .hljs-comment,[data-theme="dark"] .hljs-formula{color:#8b949e}[data-theme="dark"] .hljs-name,[data-theme="dark"] .hljs-quote,[data-theme="dark"] .hljs-selector-pseudo,[data-theme="dark"] .hljs-selector-tag{color:#7ee787}[data-theme="dark"] .hljs-subst{color:#c9d1d9}[data-theme="dark"] .hljs-section{color:#1f6feb;font-weight:700}[data-theme="dark"] .hljs-bullet{color:#f2cc60}[data-theme="dark"] .hljs-emphasis{color:#c9d1d9;font-style:italic}[data-theme="dark"] .hljs-strong{color:#c9d1d9;font-weight:700}[data-theme="dark"] .hljs-addition{color:#aff5b4;background-color:#033a16}[data-theme="dark"] .hljs-deletion{color:#ffdcd7;background-color:#67060c}`;

function applyCodeTheme(theme) {
    const styleId = 'hljs-override-theme';
    let styleEl = document.getElementById(styleId);
    const css = HLJS_THEMES[theme];
    if (css) {
        if (!styleEl) {
            styleEl = document.createElement('style');
            styleEl.id = styleId;
            document.head.appendChild(styleEl);
        }
        styleEl.textContent = css + (theme === 'github' ? GITHUB_DARK_OVERRIDE : '');
    } else {
        styleEl?.remove();
    }
}

function addLineNumbersToCodeBlocks(container) {
    for (const pre of container.querySelectorAll('pre.hljs')) {
        const codeEl = pre.querySelector('code');
        if (!codeEl) continue;
        pre.classList.add('line-numbers');
        const rawHtml = codeEl.innerHTML;
        const html = rawHtml.endsWith('\n') ? rawHtml.slice(0, -1) : rawHtml;
        codeEl.innerHTML = html.split('\n')
            .map((lineHtml, i) => `<span class="code-line" data-line="${i + 1}">${lineHtml}</span>`).join('\n');
    }
}

// MARK: Math

/** Typesets every formula the Swift renderer left as TeX source. */
function typesetMath(root) {
    const engine = window.katex;
    root.querySelectorAll('.boa-math-source').forEach(element => {
        const tex = element.textContent || '';
        const display = element.dataset.math === 'display';
        rememberMathSource(element, display ? `$$${tex}$$` : `$${tex}$`);
        if (!engine) { element.classList.add('math-error', 'module-load-error'); return; }
        try {
            // `trust: false` keeps commands that load resources or set attributes (\includegraphics, \href, \htmlClass) inert.
            engine.render(tex, element, { displayMode: display, throwOnError: true, trust: false, strict: 'ignore' });
            element.classList.add('boa-math');
        } catch (error) {
            element.classList.add('math-error');
            element.title = String(error?.message || error);
        }
    });
}

function decorateTaskLists(root) {
    root.querySelectorAll('li > input[type="checkbox"]:first-child').forEach(box => {
        box.classList.add('task-list-item-checkbox');
        box.parentElement.classList.add('task-list-item');
        box.parentElement.parentElement?.classList.add('contains-task-list');
    });
}

// MARK: Images

function imageDataForSource(source, imageData) {
    const cleanSource = source.startsWith('./') ? source.slice(2) : source;
    return imageData?.[source] || imageData?.[cleanSource] || imageData?.[`./${cleanSource}`];
}

function resolveImageSource(source, options) {
    const inlinedSource = imageDataForSource(source, options.imageData);
    if (inlinedSource) return inlinedSource;

    const isRemoteOrEmbedded = /^(?:https?:|data:|blob:|local-md:)/i.test(source) || source.startsWith('//');
    const hasUnsupportedScheme = /^[a-z][a-z0-9+.-]*:/i.test(source) && !source.startsWith('file:');
    if (isRemoteOrEmbedded || hasUnsupportedScheme || !options.baseUrl) return source;

    try {
        const baseHref = `file://${options.baseUrl.replace(/\/$/, '')}/`;
        const fileURL = source.startsWith('file:') ? new URL(source) : new URL(source, baseHref);
        const cacheBust = options.renderVersion != null ? `?v=${options.renderVersion}` : '';
        return `local-md://${fileURL.pathname}${cacheBust}`;
    } catch {
        return source;
    }
}

function prepareRenderedImages(root, options) {
    root.querySelectorAll('img[src]').forEach(img => {
        img.addEventListener('error', () => img.classList.add('image-load-failed'));
        img.addEventListener('load', () => img.classList.remove('image-load-failed'));
        const source = img.getAttribute('src');
        if (!source) return;
        const resolvedSource = constrainSVGImage(img, resolveImageSource(source, options));
        if (resolvedSource !== source) img.setAttribute('src', resolvedSource);
    });
}

// MARK: Render state

let renderCount = 0;
let completedRender = -1;
let currentRender = Promise.resolve();
let disposeSVGZoom;
let toc = null;
let readingControls = null;
let readingStatus = null;
let searchEngine = null;
let searchUI = null;
let helpOverlay = null;
let blockCopy = null;
let blockquoteCollapse = null;
let lastShowLineNumbers = false;
let currentContext = 'app';
// Set by the native host per document; block-copy requests carry it so stale ones are rejected.
let copyGeneration = '';

function disposeBlockCopy() { blockCopy?.dispose(); blockCopy = null; }

window.waitForExportReady = async (timeoutMs = 15000) => {
    const generation = renderCount;
    const started = Date.now();
    let timer;
    const checkCurrent = () => {
        if (generation !== renderCount) throw new Error('Document changed during export');
    };
    try {
        await Promise.race([
            currentRender,
            new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('Export rendering timed out')), timeoutMs); }),
        ]);
        checkCurrent();
        await waitForExportReady(Math.max(1, timeoutMs - (Date.now() - started)), checkCurrent);
        checkCurrent();
    } finally {
        if (timer !== undefined) clearTimeout(timer);
    }
};
window.prepareExport = () => prepareExport(() => window.waitForExportReady());
window.waitForRenderComplete = async () => {
    const generation = renderCount;
    await currentRender;
    if (generation !== renderCount) throw new Error('Document changed during export');
};
window.invalidateRender = () => { disposeBlockCopy(); ++renderCount; };

// MARK: Export

function collectStylesheetRules(includeWebFonts = true) {
    let css = '';
    for (const sheet of Array.from(document.styleSheets)) {
        try {
            for (const rule of Array.from(sheet.cssRules || [])) {
                if (!includeWebFonts && rule.type === CSSRule.FONT_FACE_RULE) continue;
                if (!css.includes(rule.cssText)) css += rule.cssText + '\n';
            }
        } catch (_e) { /* unreadable sheet */ }
    }
    return css;
}

window.exportHTML = function () {
    // Standalone HTML cannot reach the app's font files; leave font faces out.
    const cssText = collectStylesheetRules(false);
    const previewDiv = document.getElementById('markdown-preview');
    const clone = previewDiv ? previewDiv.cloneNode(true) : document.createElement('div');

    clone.querySelectorAll('.block-copy-tools, .diagram-tools').forEach(control => control.remove());
    clone.querySelectorAll('.block-copy-host').forEach(host => host.replaceWith(...Array.from(host.childNodes)));
    clone.querySelectorAll('.search-highlight').forEach(mark => mark.replaceWith(document.createTextNode(mark.textContent || '')));
    clone.querySelectorAll('.math-search-highlight, .search-highlight-active').forEach(node => node.classList.remove('math-search-highlight', 'search-highlight-active'));
    clone.querySelectorAll('.blockquote-placeholder').forEach(placeholder => {
        const quote = placeholder.nextElementSibling;
        if (quote?.matches('blockquote, .markdown-alert')) quote.style.display = '';
        placeholder.remove();
    });
    // Absolute sources let the native side find and inline local images.
    clone.querySelectorAll('img').forEach(img => {
        if (img.src && !img.src.startsWith('data:')) img.setAttribute('src', img.src);
    });

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data: file:; font-src data:">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Exported Markdown</title>
    <style>
        body { margin: 0; padding: 20px; background-color: #ffffff; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji"; }
        @media (prefers-color-scheme: dark) { body { background-color: #0d1117; color: #c9d1d9; } }
        .markdown-body { box-sizing: border-box; min-width: 200px; max-width: none; margin: 0 auto; padding: 45px; }
        @media (max-width: 767px) { .markdown-body { padding: 15px; } }
${cssText}
    </style>
</head>
<body>
    <div class="markdown-body">
${clone.innerHTML}
    </div>
</body>
</html>`;
};

// MARK: Layout hooks called by the native host

window.setContentsSide = function (side) {
    const normalized = side === 'left' ? 'left' : 'right';
    if (document.documentElement.dataset.tocSide === normalized) return;
    const anchor = captureReadingAnchor();
    document.documentElement.dataset.tocSide = normalized;
    if (toc?.isMounted()) toc.updateLayout();
    updateReadingControlsLayout();
    restoreReadingAnchor(anchor);
};

// A resolved JS call alone does not prove that Markdown was rendered.
window.verifyQuickLookProbe = (heading, boldText) => {
    const root = document.getElementById('markdown-preview');
    if (completedRender !== renderCount || !root?.isConnected ||
        root.classList.contains('source-mode') || root.querySelector('.render-error')) return false;
    const title = root.querySelector('h1');
    const strong = root.querySelector('p strong');
    const visible = (element) => {
        if (!element) return false;
        const box = element.getBoundingClientRect();
        if (box.width <= 0 || box.height <= 0) return false;
        for (let node = element; node; node = node.parentElement) {
            const style = getComputedStyle(node);
            if (style.display === 'none' || style.visibility === 'hidden' ||
                style.visibility === 'collapse' || style.opacity === '0') return false;
        }
        return true;
    };
    return title?.textContent === heading && strong?.textContent === boldText &&
        visible(root) && visible(title) && visible(strong);
};

function applyTheme(theme) {
    let normalized = theme || 'default';
    if (normalized === 'system') {
        normalized = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default';
    } else if (normalized === 'light') {
        normalized = 'default';
    }
    document.documentElement.setAttribute('data-theme', normalized);
    return normalized;
}

function ensureControls() {
    const controlsElement = document.getElementById('reading-controls');
    if (controlsElement && !readingControls?.isMounted()) {
        readingControls?.dispose();
        readingControls = new ReadingControls(controlsElement);
    }
    const statusElement = document.getElementById('reading-status');
    if (statusElement && !readingStatus?.isMounted()) {
        readingStatus?.dispose();
        readingStatus = new ReadingStatus(statusElement);
    }
    if (!toc || !toc.isMounted()) {
        toc?.dispose();
        try { toc = new TableOfContents('toc-container'); } catch (e) { logToSwift('JS Warning: TOC initialization failed: ' + e); }
    }
    if (!searchEngine || !searchUI) {
        try {
            searchEngine = new SearchEngine();
            searchUI = new SearchUI('search-container', searchEngine);
        } catch (e) { logToSwift('JS Warning: Search initialization failed: ' + e); }
    }
    if (!helpOverlay) {
        try { helpOverlay = new HelpOverlay(); } catch (e) { logToSwift('JS Warning: HelpOverlay initialization failed: ' + e); }
    }
    if (!blockquoteCollapse || !document.getElementById('collapse-btn-container')?.contains(document.querySelector('.blockquote-collapse-toggle'))) {
        blockquoteCollapse = null;
        try { blockquoteCollapse = new BlockquoteCollapse('collapse-btn-container', 'markdown-preview'); } catch (e) {
            logToSwift('JS Warning: BlockquoteCollapse initialization failed: ' + e);
        }
    }
}

// MARK: Rendering

/**
 * Shows a document. `text` is the Markdown source (used for search status and
 * TSV); `options.html` and `options.headings` come from the Swift renderer.
 */
async function renderMarkdown(text, options = {}) {
    disposeBlockCopy();
    disposeSVGZoom?.(); disposeSVGZoom = undefined;
    const callId = ++renderCount;
    const isCurrent = () => callId === renderCount;
    logToSwift(`[renderMarkdown:${callId}] START textLen=${text.length}`);
    const outputDiv = document.getElementById('markdown-preview');
    const loadingDiv = document.getElementById('loading-status');
    if (loadingDiv) loadingDiv.style.display = 'none';
    if (!outputDiv) { logToSwift('JS Error: markdown-preview element not found'); return; }

    outputDiv.classList.remove('source-mode');
    document.documentElement.setAttribute('data-document-format', 'markdown');
    if (options.fontSize) outputDiv.style.fontSize = options.fontSize + 'px';
    applyCodeTheme(options.codeHighlightTheme || 'default');

    if (options.context) {
        currentContext = options.context;
        window.__boaContext = currentContext;
        document.documentElement.setAttribute('data-context', currentContext);
    }
    if (options.contentsSide !== undefined) window.setContentsSide(options.contentsSide);
    applyTheme(options.theme);

    try {
        ensureControls();
        if (options.format === 'tsv') {
            document.documentElement.setAttribute('data-document-format', 'tsv');
            searchEngine?.clear();
            const rendered = renderTSVTable(text, options.isTruncated === true);
            outputDiv.innerHTML = '';
            outputDiv.appendChild(rendered.element);
            outputDiv.setAttribute('dir', 'ltr');
            blockquoteCollapse?.setInitialState(false);
            searchUI?.refresh();
            readingStatus?.render(text, options.filename);
            updateReadingControlsLayout();
            toc?.render([]);
            completedRender = callId;
            logToSwift(`[renderMarkdown:${callId}] TSV rendered rows=${rendered.result.rows.length} columns=${rendered.result.columns}`);
            return;
        }

        const showLineNumbers = options.showLineNumbers !== false;
        document.documentElement.setAttribute('data-line-numbers', showLineNumbers ? 'true' : 'false');
        lastShowLineNumbers = showLineNumbers;

        // Stage off-screen so the visible document changes once.
        const staged = document.createElement('div');
        staged.innerHTML = typeof options.html === 'string' ? options.html : '';
        highlightCodeBlocks(staged);
        decorateTaskLists(staged);
        if (options.enableKatex !== false) typesetMath(staged);

        if (!isCurrent()) return;
        searchEngine?.clear();
        const fragment = document.createDocumentFragment();
        while (staged.firstChild) fragment.appendChild(staged.firstChild);
        outputDiv.replaceChildren(fragment);
        // Elements keep their identity when moved, so remembered formula sources still apply.

        const headings = Array.isArray(options.headings) ? options.headings : [];
        toc?.render(buildHeadingTree(headings.map(h => ({ level: h.level, text: h.title, id: h.id, children: [] }))));
        prepareRenderedImages(outputDiv, options);
        disposeSVGZoom = installSVGZoom(outputDiv);

        if (options.showCopyButtons === true && currentContext !== 'finder') {
            blockCopy = installBlockCopy(outputDiv, copyGeneration);
        }
        if (showLineNumbers) addLineNumbersToCodeBlocks(outputDiv);
        blockquoteCollapse?.setInitialState(options.collapseBlockquotes === true);

        if (detectRtlContent(text)) outputDiv.setAttribute('dir', 'rtl');
        else outputDiv.removeAttribute('dir');

        searchUI?.refresh();
        readingStatus?.render(text, options.filename, options.prevContent);
        window.dispatchEvent(new Event('scroll'));
        completedRender = callId;
        logToSwift(`[renderMarkdown:${callId}] COMPLETE`);
    } catch (e) {
        if (!isCurrent()) return;
        logToSwift(`[renderMarkdown:${callId}] ERROR: ` + e);
        outputDiv.innerHTML = `<div class="render-error" style="color:red;padding:20px;border:1px solid red;border-radius:5px;"><h3>${rendererLabels().renderingError}</h3><pre>${escapeHtml(String(e))}</pre></div>`;
    }
}

window.renderMarkdown = (text, options) => {
    currentRender = renderMarkdown(text, options);
    return currentRender;
};

window.renderSource = function (text, theme, _prevContent, options = {}) {
    disposeBlockCopy();
    disposeSVGZoom?.(); disposeSVGZoom = undefined;
    currentRender = Promise.resolve();
    ++renderCount;
    searchEngine?.clear();
    logToSwift(`[renderSource] START textLen=${text.length} theme=${theme}`);
    document.documentElement.setAttribute('data-line-numbers', lastShowLineNumbers ? 'true' : 'false');
    document.documentElement.setAttribute('data-theme', theme === 'light' ? 'default' : theme);
    const outputDiv = document.getElementById('markdown-preview');
    const loadingDiv = document.getElementById('loading-status');
    if (loadingDiv) loadingDiv.style.display = 'none';
    if (!outputDiv) { logToSwift('JS Error: markdown-preview element not found'); return; }

    document.documentElement.dataset.documentFormat = options.format || 'markdown';
    outputDiv.classList.add('source-mode');
    if (options.format === 'tsv') {
        outputDiv.setAttribute('dir', 'ltr');
        const preview = renderTSVTable(text, options.isTruncated === true);
        outputDiv.replaceChildren();
        const notice = preview.element.querySelector('.tsv-truncated, .tsv-empty');
        if (notice) outputDiv.appendChild(notice);
        const pre = document.createElement('pre');
        // The source remains literal and bounded, including any incomplete final record.
        pre.textContent = text;
        outputDiv.appendChild(pre);
        toc?.render([]);
        searchUI?.refresh();
        readingStatus?.render(text, options.filename);
        return;
    }
    readingStatus?.render(text);
    toc?.render([]);

    try {
        outputDiv.innerHTML = buildSourceHTML(text, theme);
        blockquoteCollapse?.setInitialState(false);
        updateReadingControlsLayout();
        // Give heading lines the same ids as the rendered view so anchors keep working.
        for (const heading of Array.isArray(options.headings) ? options.headings : []) {
            const row = outputDiv.querySelector(`[data-source-line="${Number(heading.line)}"]`);
            if (row && heading.id) row.id = heading.id;
        }
        searchUI?.refresh();
        logToSwift(`[Source View] Rendered ${text.length} characters with theme: ${theme}`);
    } catch (e) {
        logToSwift('JS Error during source rendering: ' + e);
        outputDiv.innerHTML = `<div class="source-render-error" style="color:red;padding:20px;border:1px solid red;border-radius:5px;"><h3>${rendererLabels().sourceRenderingError}</h3><pre>${escapeHtml(String(e))}</pre></div>`;
    }
};

// Reload change marks are not part of this renderer; the native host still calls this.
window.clearDiffMarks = function () {};

window.updateTheme = function (theme) { applyTheme(theme); };

// MARK: Links

function findElementByAnchor(anchorId) {
    const exactMatch = document.getElementById(anchorId);
    if (exactMatch) return exactMatch;
    const all = Array.from(document.querySelectorAll('[id]'));
    // Progressively looser comparisons for anchors written by hand or by other tools.
    const normalizers = [
        id => id.replace(/-+/g, '-'),
        id => id.replace(/-+/g, '-').replace(/[_-]/g, '~'),
        id => id.toLowerCase().replace(/-/g, ''),
        id => id.toLowerCase().replace(/[-_]/g, ''),
    ];
    for (const normalize of normalizers) {
        const wanted = normalize(anchorId);
        const found = all.find(element => normalize(element.id) === wanted);
        if (found) return found;
    }
    return null;
}

function handleAnchorClick(e) {
    const anchor = e.target.closest?.('a');
    if (!anchor || anchor.closest('#toc-container .toc-nav')) return;
    const href = anchor.getAttribute('href');
    if (!href) return;

    e.preventDefault();
    e.stopPropagation();
    if (href.startsWith('#')) {
        const target = findElementByAnchor(decodeURIComponent(href.substring(1)));
        if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        return;
    }
    // Only a real pointer or keyboard activation may hand a link to the native host.
    if (!e.isTrusted) return;
    try {
        window.webkit?.messageHandlers?.linkClicked?.postMessage(href);
    } catch (error) {
        logToSwift(`[Click] ERROR: ${error}`);
    }
}

document.addEventListener('click', handleAnchorClick, { capture: true, passive: false });

function getLinkStatusText(anchor) {
    const href = anchor.getAttribute('href');
    if (!href || href === '#') return null;
    let decoded = href;
    try { decoded = decodeURIComponent(href); } catch { /* malformed encoding: keep raw */ }
    const displayText = anchor.textContent?.trim() ?? '';
    if (displayText === decoded || displayText === href) return null;
    try {
        const url = new URL(href);
        if (displayText === url.host || displayText === url.hostname) return null;
    } catch { /* relative href or anchor */ }
    return decoded;
}

let statusBar = null;
function getStatusBar() {
    if (!statusBar) statusBar = document.getElementById('link-status-bar');
    return statusBar;
}

document.addEventListener('mouseover', (e) => {
    const anchor = e.target.closest?.('a');
    const bar = getStatusBar();
    if (!bar || !anchor) return;
    const linkTarget = getLinkStatusText(anchor);
    if (linkTarget) {
        const icon = linkTarget.startsWith('#') ? '⚓' : linkTarget.startsWith('mailto:') ? '✉️' : '🔗';
        bar.innerHTML = `<span class="status-icon">${icon}</span>${escapeHtml(linkTarget)}`;
        bar.classList.add('visible');
    }
});

document.addEventListener('mouseout', (e) => {
    const bar = getStatusBar();
    const anchor = e.target.closest?.('a');
    if (!bar || !anchor) return;
    if (e.relatedTarget && anchor.contains(e.relatedTarget)) return;
    bar.classList.remove('visible');
});

// MARK: Zoom, font size, search, help

let currentZoomLevel = 1.0;

window.setZoomLevel = function (level) {
    currentZoomLevel = Math.max(0.5, Math.min(3.0, level));
    if (currentZoomLevel === 1.0) document.documentElement.style.removeProperty('--zoom-scale');
    else document.documentElement.style.setProperty('--zoom-scale', String(currentZoomLevel));
};

document.addEventListener('keydown', (e) => {
    if (!(e.metaKey || e.ctrlKey)) return;
    if (e.key.toLowerCase() === 'f' && !e.shiftKey && !e.altKey) { e.preventDefault(); window.showSearch(); }
    else if (e.key === '+' || e.key === '=') { e.preventDefault(); window.setZoomLevel(currentZoomLevel + 0.1); }
    else if (e.key === '-' || e.key === '_') { e.preventDefault(); window.setZoomLevel(currentZoomLevel - 0.1); }
    else if (e.key === '0') { e.preventDefault(); window.setZoomLevel(1.0); }
});

window.setFontSize = function (px) {
    const outputDiv = document.getElementById('markdown-preview');
    if (outputDiv) outputDiv.style.fontSize = Math.max(8, Math.min(48, px)) + 'px';
};

window.adjustFontSize = function (delta) {
    const outputDiv = document.getElementById('markdown-preview');
    if (!outputDiv) return;
    const current = parseFloat(getComputedStyle(outputDiv).fontSize) || 16;
    outputDiv.style.fontSize = Math.max(8, Math.min(48, current + delta)) + 'px';
};

window.showSearch = function () {
    // Source mode can be the first render after the handshake.
    if (!searchEngine || !searchUI) {
        searchEngine = new SearchEngine();
        searchUI = new SearchUI('search-container', searchEngine);
    }
    searchUI.show();
};
window.hideSearch = function () { searchUI?.hide(); };
window.toggleSearch = function () { searchUI?.toggle(); };

window.showHelp = function () { helpOverlay?.show(); };
window.hideHelp = function () { helpOverlay?.hide(); };
window.toggleHelp = function () { helpOverlay?.toggle(); };

window.addEventListener('afterprint', () => {
    document.documentElement.style.removeProperty('--print-font-size');
});

window.navigateDocumentPosition = function (position) {
    const root = document.getElementById('markdown-preview');
    if (!root) return false;
    const target = position.line !== undefined ? findSourceLineTarget(root, position.line)
        : position.anchor ? findElementByAnchor(position.anchor) : null;
    if (!target || !root.contains(target)) return false;
    target.scrollIntoView({ behavior: 'auto', block: 'start' });
    return true;
};

Object.assign(window, {
    blockCopyResult,
    setRenderGeneration: (value) => { disposeBlockCopy(); copyGeneration = value; },
});

logToSwift('rendererReady');

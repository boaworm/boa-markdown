// Plain source view: one numbered row per line.
function escapeHtml(s) {
    return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

export function buildSourceHTML(text, theme) {
    const themeClass = theme === 'dark' ? 'source-view-dark' : 'source-view-light';
    let gutter = '';
    let content = '';
    text.split('\n').forEach((line, index) => {
        const number = index + 1;
        gutter += `<span class="source-diff-line-num">${number}</span>`;
        content += `<span class="source-diff-line" data-source-line="${number}" data-source-line-end="${number}">${escapeHtml(line)}</span>`;
    });
    return `<div class="source-diff-wrap ${themeClass}">` +
        `<div class="source-diff-gutter">${gutter}</div>` +
        `<div class="source-diff-content">${content}</div>` +
        `</div>`;
}

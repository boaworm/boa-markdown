export type RendererLabels = {
    typstLoading: string;
    typstRenderError: string;
    mermaidSyntaxError: string;
    showSourceCode: string;
    graphvizError: string;
    emptyGraphvizSource: string;
    renderingError: string;
    sourceRenderingError: string;
    tsvColumn: string;
    tsvRecordTooLarge: string;
    tsvEmpty: string;
    tsvPreviewLimited: string;
};

const labels: Record<string, RendererLabels> = {
    en: { tsvColumn: 'Column', tsvRecordTooLarge: 'The first record exceeds the preview limit.', typstLoading: 'Rendering Typst…', typstRenderError: '⚠️ Typst Render Error', mermaidSyntaxError: '⚠️ Mermaid Syntax Error', showSourceCode: 'Show source code', graphvizError: 'GraphViz error', emptyGraphvizSource: 'empty diagram source', renderingError: 'Rendering Error', sourceRenderingError: 'Source Rendering Error', tsvEmpty: 'Empty TSV file', tsvPreviewLimited: 'Preview limited to the readable TSV range.' },
};

export function rendererLabels(): RendererLabels {
    return labels.en;
}

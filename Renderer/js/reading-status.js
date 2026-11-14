import { updateReadingControlsLayout } from './reading-controls.js';

export function headingPath(headings               , active             )           {
    const stack                = [];
    for (const heading of headings) {
        while (stack.length && stack[stack.length - 1].tagName >= heading.tagName) stack.pop();
        stack.push(heading);
        if (heading === active) break;
    }
    return stack.map(heading => heading.textContent?.trim() || '');
}
export function scrollProgress(y        , height        , viewport        )                {
    return height <= viewport + 1 ? null : Math.round(Math.max(0, Math.min(1, y / (height - viewport))) * 100);
}
const labels = { en: ['Position', 'Document updated'] };
export class ReadingStatus {
            lastText                    ;
            headings                = [];
            path = document.createElement('span');
            parent = document.createElement('span');
            current = document.createElement('span');
            file = document.createElement('span');
            progress = document.createElement('span');
            updated = document.createElement('span');
            frame                = null;
            timer                                       = null;
            observer                        = null;
                     heading = (event       ) => {
        const active = this.headings.find(h => h.id === (event                       ).detail);
        if (!active) return;
        const path = headingPath(this.headings, active);
        this.path.title = path.join(' › ');
        this.parent.textContent = path.length > 1 ? path[path.length - 2] + ' › ' : '';
        this.current.textContent = path[path.length - 1];
    };
                     schedule = () => {
        if (this.frame !== null) return;
        this.frame = requestAnimationFrame(() => { this.frame = null; this.update(); });
    };
    constructor(element             ) {
        this.element = element;
        this.file.className = 'reading-filename'; this.path.className = 'reading-path';
        this.parent.className = 'reading-parent'; this.current.className = 'reading-current';
        this.progress.className = 'reading-progress'; this.updated.className = 'reading-updated';
        this.updated.setAttribute('role', 'status'); this.updated.hidden = true;
        this.path.append(this.parent, this.current);
        element.replaceChildren(this.file, this.path, this.progress, this.updated);
        document.addEventListener('reading-heading', this.heading);
        window.addEventListener('scroll', this.schedule, { passive: true });
        window.addEventListener('resize', this.schedule);
        if (typeof ResizeObserver !== 'undefined') {
            this.observer = new ResizeObserver(this.schedule);
            this.observer.observe(element);
            const preview = document.getElementById('markdown-preview');
            if (preview) this.observer.observe(preview);
        }
    }
    isMounted()          { return this.element === document.getElementById('reading-status'); }
    render(text        , previous         )       {
        if (this.timer) clearTimeout(this.timer);
        this.updated.hidden = true;
        this.headings = Array.from(document.querySelectorAll             ('#markdown-preview h1[id], #markdown-preview h2[id], #markdown-preview h3[id], #markdown-preview h4[id], #markdown-preview h5[id], #markdown-preview h6[id]'));
        this.parent.textContent = ''; this.current.textContent = ''; this.path.title = '';
        this.file.title = this.file.textContent;
        if (previous !== undefined && previous !== text && this.lastText !== text) {
            this.updated.textContent = this.strings()[1]; this.updated.hidden = false;
            this.timer = setTimeout(() => { this.updated.hidden = true; this.update(); }, 4000);
        }
        if (this.headings[0]) this.heading(new CustomEvent('reading-heading', { detail: this.headings[0].id }));
        this.lastText = text;
        this.update();
    }
            strings()           {
        return labels.en;
    }
            update()       {
        const value = scrollProgress(window.scrollY, document.documentElement.scrollHeight, window.innerHeight);
        this.progress.hidden = value === null;
        this.progress.textContent = value === null ? '' : `${this.strings()[0]} ${value}%`;
        this.progress.title = this.progress.textContent;
        this.element.hidden = document.documentElement.dataset.context === 'finder'
            || !!document.querySelector('#markdown-preview.source-mode')
            || (!this.headings.length && value === null && this.updated.hidden);
        const width = this.element.getBoundingClientRect().width;
        this.element.dataset.size = width < 170 ? 'tiny' : width < 300 ? 'small' : width < 480 ? 'medium' : 'large';
        updateReadingControlsLayout();
    }
    dispose()       {
        if (this.timer) clearTimeout(this.timer);
        if (this.frame !== null) cancelAnimationFrame(this.frame);
        this.observer?.disconnect();
        document.removeEventListener('reading-heading', this.heading);
        window.removeEventListener('scroll', this.schedule); window.removeEventListener('resize', this.schedule);
    }
}

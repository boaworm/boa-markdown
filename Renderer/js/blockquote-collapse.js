import { readingLabels, updateReadingControlsLayout } from './reading-controls.js';

export class BlockquoteCollapse {
            container             ;
            preview             ;
            collapsed          = false;
            button                   ;

    constructor(containerId        , previewId        ) {
        const containerEl = document.getElementById(containerId);
        if (!containerEl) {
            throw new Error(`BlockquoteCollapse: container element not found: ${containerId}`);
        }
        const previewEl = document.getElementById(previewId);
        if (!previewEl) {
            throw new Error(`BlockquoteCollapse: preview element not found: ${previewId}`);
        }
        this.container = containerEl;
        this.preview = previewEl;
        this.button = this.createButton();
        this.container.appendChild(this.button);
    }

            createButton()                    {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'blockquote-collapse-toggle reading-tool-button';
        button.setAttribute('aria-label', readingLabels().collapse);
        button.textContent = readingLabels().collapse;
        button.addEventListener('click', () => this.toggle());
        return button;
    }

    setInitialState(collapsed         )       {
        this.collapsed = collapsed;
        this.applyState();
    }

    toggle()       {
        this.collapsed = !this.collapsed;
        this.applyState();
    }

    isCollapsed()          {
        return this.collapsed;
    }

            targets()                          {
        return this.preview.querySelectorAll             ('blockquote, .markdown-alert');
    }

            collapseAll()       {
        this.targets().forEach(el => {
            if (el.previousElementSibling?.classList.contains('blockquote-placeholder')) return;
            const placeholder = this.createPlaceholder(el);
            el.before(placeholder);
            el.style.display = 'none';
        });
        this.button.setAttribute('aria-label', readingLabels().expand);
        this.button.textContent = readingLabels().expand;
        this.button.classList.add('active');
    }

            expandAll()       {
        this.preview.querySelectorAll             ('.blockquote-placeholder').forEach(p => p.remove());
        this.targets().forEach(el => {
            el.style.display = '';
        });
        this.button.setAttribute('aria-label', readingLabels().collapse);
        this.button.textContent = readingLabels().collapse;
        this.button.classList.remove('active');
    }

            createPlaceholder(target             )              {
        const ph = document.createElement('div');
        ph.className = 'blockquote-placeholder';
        ph.addEventListener('click', () => {
            target.style.display = '';
            ph.remove();
        });
        return ph;
    }

            applyState()       {
        this.container.hidden = this.targets().length === 0 || document.documentElement.dataset.context === 'finder';
        this.button.setAttribute('aria-expanded', String(!this.collapsed));
        if (this.collapsed) {
            this.collapseAll();
        } else {
            this.expandAll();
        }
        updateReadingControlsLayout();
    }
}

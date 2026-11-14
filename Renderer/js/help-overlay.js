const FIRST_RUN_KEY = 'boamd-help-shown-v1';
const CMD_HOLD_DELAY_MS = 2000;
const CMD_HOLD_ENABLED_KEY = 'boamd-cmd-hold-enabled';

                
                      
                              
     
 

                 

                
                  
                           
                            
                     
                         
                     
                      
                      
                       
                                 
             
                                                      
                                                 
                                                 
                                                   
                                                     
      
 

const STRINGS                     = {
    en: {
        title: '⌨️ BoaMarkdown Feature Guide',
        contextBadgeQL: 'QuickLook Preview',
        contextBadgeApp: 'BoaMarkdown App',
        badgeApp: 'App',
        qlBannerText: 'QuickLook intercepts keyboard events. Only <strong>Cmd+scroll</strong> and <strong>pinch gesture</strong> work; use toolbar buttons or double-click to open in App for full access.',
        footerQL: 'Click backdrop or <kbd>✕</kbd> to close',
        footerApp: 'Press <kbd>?</kbd> or <kbd>Esc</kbd> to close · Hold <kbd>⌘</kbd> 2s to reopen',
        toastText: '💡 Press <kbd>?</kbd> or click <strong>?</strong> in the toolbar to view all shortcuts',
        closeLabel: 'Close',
        cmdHoldCheckboxLabel: 'Auto-open this panel by holding ⌘ for 2s',
        groups: {
            searchNav: {
                title: 'Search & Navigation',
                items: ['Open / close search', 'Next match', 'Previous match', 'Close search', 'TOC button (top-right)'],
            },
            zoom: {
                title: 'Zoom',
                items: ['Zoom in', 'Zoom out', 'Reset zoom', 'Scroll zoom', 'Pinch to zoom'],
            },
            view: {
                title: 'View',
                items: ['Toggle preview / source', 'Source button (top-right </>)', 'Theme toggle (☀/🌙 top-right)'],
            },
            export: {
                title: 'Export',
                items: ['Export as HTML', 'Export as PDF'],
            },
            settings: {
                title: 'Settings',
                items: ['Open preferences', 'Check for updates', 'Help button (? top-right)', 'Show this help panel'],
            },
        },
    },
};

                         
                 
                                   
                                                                                          
 

const SHORTCUT_GROUPS                  = [
    {
        icon: '🔍',
        groupKey: 'searchNav',
        items: [
            { keys: ['⌘', 'F'], labelIdx: 0, qlDisabled: true },
            { keys: ['Enter'], labelIdx: 1, qlDisabled: true },
            { keys: ['⇧', 'Enter'], labelIdx: 2, qlDisabled: true },
            { keys: ['Esc'], labelIdx: 3, qlDisabled: true },
            { keys: ['Click'], labelIdx: 4 },
        ],
    },
    {
        icon: '🔎',
        groupKey: 'zoom',
        items: [
            { keys: ['⌘', '+'], labelIdx: 0, qlDisabled: true },
            { keys: ['⌘', '-'], labelIdx: 1, qlDisabled: true },
            { keys: ['⌘', '0'], labelIdx: 2, qlDisabled: true },
            { keys: ['⌘', '⬆scroll'], labelIdx: 3 },
            { keys: ['Pinch'], labelIdx: 4 },
        ],
    },
    {
        icon: '📄',
        groupKey: 'view',
        items: [
            { keys: ['⌘', '⇧', 'M'], labelIdx: 0, qlDisabled: true },
            { keys: ['Click'], labelIdx: 1 },
            { keys: ['Click'], labelIdx: 2 },
        ],
    },
    {
        icon: '📤',
        groupKey: 'export',
        items: [
            { keys: ['⌘', '⇧', 'E'], labelIdx: 0, appOnly: true },
            { keys: ['⌘', '⇧', 'P'], labelIdx: 1, appOnly: true },
        ],
    },
    {
        icon: '⚙️',
        groupKey: 'settings',
        items: [
            { keys: ['⌘', ','], labelIdx: 0, appOnly: true },
            { keys: ['⌘', 'U'], labelIdx: 1, appOnly: true },
            { keys: ['Click'], labelIdx: 2 },
            { keys: ['⌘', 'Hold'], labelIdx: 3, qlDisabled: true },
        ],
    },
];

function detectLang()       {
    return 'en';
}

export class HelpOverlay {
            overlayEl                     = null;
            toastEl                     = null;
            isVisible = false;

            cmdHoldTimer                                       = null;
            cmdHoldActive = false;

            isCmdHoldEnabled()          {
        try {
            const stored = localStorage.getItem(CMD_HOLD_ENABLED_KEY);
            return stored === null ? true : stored === '1';
        } catch {
            return true;
        }
    }

            setCmdHoldEnabled(enabled         )       {
        try {
            localStorage.setItem(CMD_HOLD_ENABLED_KEY, enabled ? '1' : '0');
        } catch {}
    }

    constructor() {
        this.createOverlay();
        this.registerKeyListeners();
        this.showFirstRunToast();
    }

            createOverlay()       {
        const strings = STRINGS[detectLang()];
        const overlay = document.createElement('div');
        overlay.id = 'help-overlay';
        overlay.setAttribute('role', 'dialog');
        overlay.setAttribute('aria-modal', 'true');
        overlay.setAttribute('aria-label', strings.title);

        overlay.innerHTML = this.buildOverlayHTML();
        overlay.addEventListener('click', (e) => {
            if (e.target === overlay) this.hide();
        });
        overlay.querySelector('#help-overlay-close')?.addEventListener('click', () => this.hide());

        document.body.appendChild(overlay);
        this.overlayEl = overlay;
    }

            buildOverlayHTML()         {
        const isQuickLook = window.__boaContext === 'quicklook';
        const lang = detectLang();
        const s = STRINGS[lang];

        const contextBadge = isQuickLook
            ? `<span class="help-context-badge help-context-ql">${s.contextBadgeQL}</span>`
            : `<span class="help-context-badge help-context-app">${s.contextBadgeApp}</span>`;

        const groups = SHORTCUT_GROUPS.map(g => {
            const groupStrings = s.groups[g.groupKey];
            const items = g.items.map(item => {
                const isAppOnlyDimmed = isQuickLook && item.appOnly;
                const isQlDisabled = isQuickLook && item.qlDisabled;

                let className = 'help-item';
                if (isAppOnlyDimmed || isQlDisabled) className += ' help-item-dimmed';

                const badges           = [];
                if (item.appOnly || item.qlDisabled) {
                    badges.push(`<span class="help-badge help-badge-app">${s.badgeApp}</span>`);
                }

                const label = groupStrings.items[item.labelIdx] ?? '';

                return `
                    <li class="${className}">
                        <span class="help-keys">${item.keys.map(k => `<kbd>${k}</kbd>`).join('')}</span>
                        <span class="help-label">${label}${badges.join('')}</span>
                    </li>
                `;
            }).join('');
            return `
                <div class="help-group">
                    <h3 class="help-group-title">${g.icon} ${groupStrings.title}</h3>
                    <ul class="help-items">${items}</ul>
                </div>
            `;
        }).join('');

        const qlBanner = isQuickLook ? `
            <div class="help-ql-banner">
                <span class="help-ql-banner-icon">⚠️</span>
                <span>${s.qlBannerText}</span>
            </div>
        ` : '';

        const footerText = isQuickLook ? `<span>${s.footerQL}</span>` : `<span>${s.footerApp}</span>`;

        const cmdHoldCheckbox = !isQuickLook ? `
            <label class="help-checkbox-label">
                <input type="checkbox" id="help-cmd-hold-checkbox" ${this.isCmdHoldEnabled() ? 'checked' : ''}>
                ${s.cmdHoldCheckboxLabel}
            </label>
        ` : '';

        return `
            <div class="help-dialog">
                <div class="help-header">
                    <span class="help-title">${s.title}</span>
                    ${contextBadge}
                    <button id="help-overlay-close" class="help-close" aria-label="${s.closeLabel}">✕</button>
                </div>
                ${qlBanner}
                <div class="help-body">
                    ${groups}
                </div>
                <div class="help-footer">
                    ${footerText}
                    ${cmdHoldCheckbox}
                </div>
            </div>
        `;
    }

            registerKeyListeners()       {
        // Modifier-only keys that should NOT cancel the Cmd-hold timer.
        // Any other key pressed while Cmd is held means the user is using a shortcut,
        // so we cancel the timer to avoid false positives (Cmd+Tab, Cmd+Ctrl+X, boss keys, etc.).
        const MODIFIER_KEYS = new Set(['Meta', 'Control', 'Alt', 'Shift', 'CapsLock', 'Fn', 'FnLock', 'Hyper', 'Super', 'Symbol', 'SymbolLock']);

        document.addEventListener('keydown', (e               ) => {
            if (
                e.key === '?' &&
                !(e.target instanceof HTMLInputElement) &&
                !(e.target instanceof HTMLTextAreaElement) &&
                !e.metaKey && !e.ctrlKey
            ) {
                e.preventDefault();
                this.toggle();
                return;
            }

            if (e.key === 'Escape' && this.isVisible) {
                e.preventDefault();
                this.hide();
                return;
            }

            // If a non-modifier key is pressed while the Cmd-hold timer is running,
            // the user is using a keyboard shortcut (e.g. Cmd+Tab, Cmd+Space, boss key).
            // Cancel the timer immediately so the help overlay does NOT appear.
            if (!MODIFIER_KEYS.has(e.key) && this.cmdHoldTimer) {
                clearTimeout(this.cmdHoldTimer);
                this.cmdHoldTimer = null;
                return;
            }

            if ((e.key === 'Meta' || e.key === 'Control') && !e.repeat && !this.cmdHoldActive && !this.cmdHoldTimer && this.isCmdHoldEnabled()) {
                this.cmdHoldTimer = setTimeout(() => {
                    this.cmdHoldActive = true;
                    this.show();
                }, CMD_HOLD_DELAY_MS);
            }
        });

        document.addEventListener('keyup', (e               ) => {
            if (e.key === 'Meta' || e.key === 'Control') {
                if (this.cmdHoldTimer) {
                    clearTimeout(this.cmdHoldTimer);
                    this.cmdHoldTimer = null;
                }
                this.cmdHoldActive = false;
            }
        });
    }

            showFirstRunToast()       {
        try {
            if (localStorage.getItem(FIRST_RUN_KEY)) return;
            localStorage.setItem(FIRST_RUN_KEY, '1');
        } catch {
            return;
        }
        setTimeout(() => this.mountToast(), 1500);
    }

            mountToast()       {
        const lang = detectLang();
        const s = STRINGS[lang];
        const toast = document.createElement('div');
        toast.id = 'help-toast';
        toast.className = 'help-toast';
        toast.innerHTML = `
            <span>${s.toastText}</span>
            <button class="help-toast-close" aria-label="${s.closeLabel}">✕</button>
        `;

        toast.querySelector('.help-toast-close')?.addEventListener('click', () => this.dismissToast());
        document.body.appendChild(toast);
        this.toastEl = toast;

        requestAnimationFrame(() => {
            requestAnimationFrame(() => toast.classList.add('help-toast-visible'));
        });

        setTimeout(() => this.dismissToast(), 6000);
    }

            dismissToast()       {
        if (!this.toastEl) return;
        this.toastEl.classList.remove('help-toast-visible');
        setTimeout(() => {
            this.toastEl?.remove();
            this.toastEl = null;
        }, 400);
    }

           show()       {
        if (this.isVisible || !this.overlayEl) return;
        this.isVisible = true;
        this.overlayEl.innerHTML = this.buildOverlayHTML();
        this.overlayEl.querySelector('#help-overlay-close')?.addEventListener('click', () => this.hide());

        const checkbox = this.overlayEl.querySelector                  ('#help-cmd-hold-checkbox');
        checkbox?.addEventListener('change', () => this.setCmdHoldEnabled(checkbox.checked));

        this.overlayEl.classList.add('help-overlay-visible');
        this.dismissToast();
    }

           hide()       {
        if (!this.isVisible || !this.overlayEl) return;
        this.isVisible = false;
        this.overlayEl.classList.remove('help-overlay-visible');
    }

           toggle()       {
        this.isVisible ? this.hide() : this.show();
    }
}

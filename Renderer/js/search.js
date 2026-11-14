import { originalMathSource } from './math-source-store.js';
/**
 * Search engine for finding and highlighting text in the rendered markdown content
 */

                                
                           
                       
                      
 

                              
                           
                         
                   
                        
                      
                                        
 

export class SearchEngine {
            matches                = [];
            currentIndex         = -1;
            searchQuery         = '';
            options                = {
        caseSensitive: false,
        wholeWord: false,
        useRegex: false
    };
            highlightClassName = 'search-highlight';
            activeHighlightClassName = 'search-highlight-active';

    constructor() {}

    /**
     * Execute search and highlight all matches
     * @param query Search query
     * @param options Search options
     * @returns Number of matches found, or -1 if regex is invalid
     */
           search(query        , options               )         {
        // Clear previous search
        this.clear();

        if (!query) {
            return 0;
        }

        this.searchQuery = query;
        this.options = { ...options };

        // Find all matches
        const contentDiv = document.getElementById('markdown-preview');
        if (!contentDiv) {
            return 0;
        }

        try {
            this.matches = this.findMatches(contentDiv, query, options);
            this.highlightMatches();
            
            if (this.matches.length > 0) {
                this.currentIndex = 0;
                this.setActiveMatch(0);
            }

            return this.matches.length;
        } catch (error) {
            // Invalid regex
            if (error instanceof SyntaxError && options.useRegex) {
                return -1; // Signal regex error
            }
            throw error;
        }
    }

    /**
     * Navigate to next match
     */
           next()       {
        if (this.matches.length === 0) return;
        
        this.currentIndex = (this.currentIndex + 1) % this.matches.length;
        this.setActiveMatch(this.currentIndex);
    }

    /**
     * Navigate to previous match
     */
           previous()       {
        if (this.matches.length === 0) return;
        
        this.currentIndex = (this.currentIndex - 1 + this.matches.length) % this.matches.length;
        this.setActiveMatch(this.currentIndex);
    }

    /**
     * Clear all search highlights
     */
           clear()       {
        document.querySelectorAll('.math-search-highlight').forEach(element => element.classList.remove('math-search-highlight', this.activeHighlightClassName));
        // Remove all highlight elements
        const highlights = document.querySelectorAll(`.${this.highlightClassName}`);
        highlights.forEach(highlight => {
            const parent = highlight.parentNode;
            if (parent) {
                const textNode = document.createTextNode(highlight.textContent || '');
                parent.replaceChild(textNode, highlight);
                parent.normalize(); // Merge adjacent text nodes
            }
        });

        this.matches = [];
        this.currentIndex = -1;
        this.searchQuery = '';
    }

    /**
     * Get current match index (1-based)
     */
           getCurrentIndex()         {
        return this.matches.length > 0 ? this.currentIndex + 1 : 0;
    }

    /**
     * Get total number of matches
     */
           getMatchCount()         {
        return this.matches.length;
    }

    /**
     * Find all text matches in the DOM tree
     */
            findMatches(root             , query        , options               )                {
        const matches                = [];
        const regex = this.buildRegex(query, options);

        // Use TreeWalker to traverse text nodes
        const walker = document.createTreeWalker(
            root,
            NodeFilter.SHOW_TEXT,
            {
                acceptNode: (node) => {
                    // Skip script, style, and other non-visible elements
                    const parent = node.parentElement;
                    if (!parent || parent.closest('.diagram-tools, .mermaid-tools, .block-copy-tools, .boa-math-source, mjx-assistive-mml')) return NodeFilter.FILTER_REJECT;

                    const tagName = parent.tagName.toLowerCase();
                    if (['script', 'style', 'noscript'].includes(tagName)) {
                        return NodeFilter.FILTER_REJECT;
                    }

                    // Skip empty text nodes
                    if (!node.textContent || node.textContent.trim() === '') {
                        return NodeFilter.FILTER_REJECT;
                    }

                    // Skip nodes that are already highlights
                    if (parent.classList.contains(this.highlightClassName)) {
                        return NodeFilter.FILTER_REJECT;
                    }

                    return NodeFilter.FILTER_ACCEPT;
                }
            }
        );

        let matchIndex = 0;
        let node              = walker.nextNode();

        while (node) {
            const textNode = node        ;
            const text = textNode.textContent || '';
            
            let match                         = regex.exec(text);
            while (match) {
                matches.push({
                    element: textNode.parentElement ,
                    textNode: textNode,
                    startOffset: match.index,
                    endOffset: match.index + match[0].length,
                    index: matchIndex++
                });

                // Prevent infinite loop for zero-width matches
                if (match.index === regex.lastIndex) {
                    regex.lastIndex++;
                }
                
                match = regex.exec(text);
            }
            
            node = walker.nextNode();
        }

        root.querySelectorAll             ('.boa-math-source').forEach(element => {
            const source = originalMathSource(element);
            if (source === undefined) return;
            regex.lastIndex = 0;
            if (!regex.test(source)) return;
            matches.push({ element, mathematical: true, textNode: document.createTextNode(source), startOffset: 0,
                endOffset: source.length, index: 0 });
        });
        matches.sort((a, b) => {
            const left       = a.mathematical ? a.element : a.textNode;
            const right       = b.mathematical ? b.element : b.textNode;
            if (left === right) return a.startOffset - b.startOffset;
            return left.compareDocumentPosition(right) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1;
        });
        matches.forEach((match, index) => { match.index = index; });
        return matches;
    }

    /**
     * Build regex based on query and options
     */
            buildRegex(query        , options               )         {
        if (options.useRegex) {
            const flags = options.caseSensitive ? 'g' : 'gi';
            return new RegExp(query, flags);
        } else {
            // Escape special regex characters
            let pattern = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            
            if (options.wholeWord) {
                pattern = `\\b${pattern}\\b`;
            }
            
            const flags = options.caseSensitive ? 'g' : 'gi';
            return new RegExp(pattern, flags);
        }
    }

    /**
     * Wrap all matches with highlight spans
     */
            highlightMatches()       {
        // Process matches in reverse order to maintain correct offsets
        for (let i = this.matches.length - 1; i >= 0; i--) {
            const match = this.matches[i];
            this.wrapMatch(match);
        }
    }

    /**
     * Wrap a single match with a highlight span
     */
            wrapMatch(match             )       {
        if (match.mathematical) {
            match.element.classList.add('math-search-highlight');
            return;
        }
        const textNode = match.textNode;
        const text = textNode.textContent || '';

        // Split the text node into three parts: before, match, after
        const before = text.substring(0, match.startOffset);
        const matchText = text.substring(match.startOffset, match.endOffset);
        const after = text.substring(match.endOffset);

        // Create highlight span
        const span = document.createElement('span');
        span.className = this.highlightClassName;
        span.textContent = matchText;
        span.dataset.matchIndex = match.index.toString();

        // Create document fragment with the three parts
        const fragment = document.createDocumentFragment();
        
        if (before) {
            fragment.appendChild(document.createTextNode(before));
        }
        
        fragment.appendChild(span);
        
        if (after) {
            fragment.appendChild(document.createTextNode(after));
        }

        // Replace the text node with the fragment
        const parent = textNode.parentNode;
        if (parent) {
            parent.replaceChild(fragment, textNode);
            
            // Update the match to point to the new span's text node
            match.textNode = span.firstChild        ;
            match.element = span;
        }
    }

    /**
     * Set the active match and scroll it into view
     */
            setActiveMatch(index        )       {
        if (index < 0 || index >= this.matches.length) return;

        const allHighlights = document.querySelectorAll(`.${this.activeHighlightClassName}`);
        allHighlights.forEach(el => {
            el.classList.remove(this.activeHighlightClassName);
        });

        // Add active class to current match
        const match = this.matches[index];
        const highlightSpan = match.element;
        highlightSpan.classList.add(this.activeHighlightClassName);

        // Scroll into view
        highlightSpan.scrollIntoView({
            behavior: 'smooth',
            block: 'center',
            inline: 'nearest'
        });
    }
}

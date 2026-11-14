import { updateReadingControlsLayout } from './reading-controls.js';
                                                            

const searchLabels = {
	en: { find: 'Find in page', query: 'Search query', previous: 'Previous match', next: 'Next match', close: 'Close', case: 'Match case', word: 'Match whole word', regex: 'Use regular expression', invalidRegex: 'Invalid regular expression' },
}         ;

function localizedSearchLabels() {
	return searchLabels.en;
}

export class SearchUI {
	        container             ;
	        searchEngine              ;
	        isVisible          = false;

	        searchInput                   ;
	        caseSensitiveCheckbox                   ;
	        wholeWordCheckbox                   ;
	        regexCheckbox                   ;
	        matchCounter                  ;
	        errorMessage                 ;
	        prevButton                    ;
	        nextButton                    ;
	        closeButton                    ;

	constructor(containerId        , searchEngine              ) {
		const element = document.getElementById(containerId);
		if (!element) {
			throw new Error(`Search container element not found: ${containerId}`);
		}
		this.container = element;
		this.searchEngine = searchEngine;

		this.createUI();
		this.attachEventListeners();
	}

	        createUI()       {
		const labels = localizedSearchLabels();
		const toolbar = document.createElement("div");
		toolbar.className = "search-toolbar";
		toolbar.setAttribute("role", "search");
		toolbar.setAttribute("aria-label", labels.find);

		const inputGroup = document.createElement("div");
		inputGroup.className = "search-input-group";

		this.searchInput = document.createElement("input");
		this.searchInput.type = "text";
		this.searchInput.className = "search-input";
		this.searchInput.placeholder = labels.find;
		this.searchInput.setAttribute("aria-label", labels.query);
		// Disable macOS auto-capitalization, auto-correct, and spellcheck
		this.searchInput.setAttribute("autocapitalize", "off");
		this.searchInput.setAttribute("autocomplete", "off");
		this.searchInput.setAttribute("autocorrect", "off");
		this.searchInput.setAttribute("spellcheck", "false");

		this.matchCounter = document.createElement("span");
		this.matchCounter.className = "search-match-counter";
		this.matchCounter.textContent = "";

		inputGroup.appendChild(this.searchInput);
		inputGroup.appendChild(this.matchCounter);

		this.prevButton = this.createButton("prev", "↑", labels.previous);
		this.nextButton = this.createButton("next", "↓", labels.next);

		const optionsGroup = document.createElement("div");
		optionsGroup.className = "search-options";

		this.caseSensitiveCheckbox = this.createCheckbox(
			"case",
			"Aa",
			labels.case,
		);
		this.wholeWordCheckbox = this.createCheckbox(
			"word",
			"ab",
			labels.word,
		);
		this.regexCheckbox = this.createCheckbox(
			"regex",
			".*",
			labels.regex,
		);

		const caseLabel = this.caseSensitiveCheckbox.parentElement;
		const wordLabel = this.wholeWordCheckbox.parentElement;
		const regexLabel = this.regexCheckbox.parentElement;

		if (caseLabel) optionsGroup.appendChild(caseLabel);
		if (wordLabel) optionsGroup.appendChild(wordLabel);
		if (regexLabel) optionsGroup.appendChild(regexLabel);

		this.closeButton = this.createButton("close", "×", labels.close);

		toolbar.appendChild(inputGroup);
		toolbar.appendChild(this.prevButton);
		toolbar.appendChild(this.nextButton);
		toolbar.appendChild(optionsGroup);
		toolbar.appendChild(this.closeButton);

		this.errorMessage = document.createElement("div");
		this.errorMessage.className = "search-error";
		this.errorMessage.setAttribute("role", "alert");
		this.errorMessage.style.display = "none";

		this.container.appendChild(toolbar);
		this.container.appendChild(this.errorMessage);
	}

	        createButton(
		className        ,
		text        ,
		ariaLabel        ,
	)                    {
		const button = document.createElement("button");
		button.className = `search-button search-button-${className}`;
		button.textContent = text;
		button.setAttribute("aria-label", ariaLabel);
		button.type = "button";
		return button;
	}

	        createCheckbox(
		name        ,
		label        ,
		ariaLabel        ,
	)                   {
		const wrapper = document.createElement("label");
		wrapper.className = "search-checkbox-label";
		wrapper.title = ariaLabel;

		const checkbox = document.createElement("input");
		checkbox.type = "checkbox";
		checkbox.className = "search-checkbox";
		checkbox.id = `search-${name}`;
		checkbox.setAttribute("aria-label", ariaLabel);

		const labelText = document.createElement("span");
		labelText.textContent = label;

		wrapper.appendChild(checkbox);
		wrapper.appendChild(labelText);

		return checkbox;
	}

	        attachEventListeners()       {
		this.searchInput.addEventListener("input", () => this.performSearch());
		this.searchInput.addEventListener("keydown", (e) =>
			this.handleInputKeydown(e),
		);

		this.caseSensitiveCheckbox.addEventListener("change", () =>
			this.performSearch(),
		);
		this.wholeWordCheckbox.addEventListener("change", () =>
			this.performSearch(),
		);
		this.regexCheckbox.addEventListener("change", () => this.performSearch());

		this.prevButton.addEventListener("click", () => this.navigatePrevious());
		this.nextButton.addEventListener("click", () => this.navigateNext());
		this.closeButton.addEventListener("click", () => this.hide());

		document.addEventListener("keydown", (e) => this.handleGlobalKeydown(e));
	}

	        handleInputKeydown(event               )       {
		if (event.key === "Enter") {
			event.preventDefault();
			event.stopPropagation();
			if (event.shiftKey) {
				this.navigatePrevious();
			} else {
				this.navigateNext();
			}
		} else if (event.key === "Escape") {
			event.preventDefault();
			event.stopPropagation();
			this.hide();
		}
	}

	        handleGlobalKeydown(event               )       {
		if (!this.isVisible) return;

		if (event.key === "Escape") {
			event.preventDefault();
			event.stopPropagation();
			this.hide();
		}
	}

	        performSearch()       {
		const query = this.searchInput.value;

		this.hideError();

		if (!query) {
			this.searchEngine.clear();
			this.updateMatchCounter(0, 0);
			this.updateButtonStates(false);
			return;
		}

		const options                = {
			caseSensitive: this.caseSensitiveCheckbox.checked,
			wholeWord: this.wholeWordCheckbox.checked,
			useRegex: this.regexCheckbox.checked,
		};

		const matchCount = this.searchEngine.search(query, options);

		if (matchCount === -1) {
			this.showError(localizedSearchLabels().invalidRegex);
			this.updateMatchCounter(0, 0);
			this.updateButtonStates(false);
			return;
		}

		const currentIndex = this.searchEngine.getCurrentIndex();
		this.updateMatchCounter(currentIndex, matchCount);
		this.updateButtonStates(matchCount > 0);
	}

	        navigateNext()       {
		this.searchEngine.next();
		const currentIndex = this.searchEngine.getCurrentIndex();
		const matchCount = this.searchEngine.getMatchCount();
		this.updateMatchCounter(currentIndex, matchCount);
	}

	        navigatePrevious()       {
		this.searchEngine.previous();
		const currentIndex = this.searchEngine.getCurrentIndex();
		const matchCount = this.searchEngine.getMatchCount();
		this.updateMatchCounter(currentIndex, matchCount);
	}

	        updateMatchCounter(current        , total        )       {
		if (total === 0) {
			this.matchCounter.textContent = "";
		} else {
			this.matchCounter.textContent = `${current}/${total}`;
		}
	}

	        updateButtonStates(enabled         )       {
		this.prevButton.disabled = !enabled;
		this.nextButton.disabled = !enabled;
	}

	        showError(message        )       {
		this.errorMessage.textContent = message;
		this.errorMessage.style.display = "block";
		updateReadingControlsLayout();
		this.searchInput.classList.add("search-input-error");
	}

	        hideError()       {
		this.errorMessage.style.display = "none";
		updateReadingControlsLayout();
		this.searchInput.classList.remove("search-input-error");
	}

	       refresh()       {
		if (this.isVisible) this.performSearch();
	}

	       show()       {
		this.isVisible = true;
		this.container.style.display = "flex";
		updateReadingControlsLayout();

		this.searchInput.focus({ preventScroll: true });
		this.searchInput.select();
	}

	       hide()       {
		this.isVisible = false;
		this.container.style.display = "none";
		this.searchEngine.clear();
		this.searchInput.value = "";
		this.updateMatchCounter(0, 0);
		this.hideError();
		updateReadingControlsLayout();
	}

	       toggle()       {
		if (this.isVisible) {
			this.hide();
		} else {
			this.show();
		}
	}

	       isSearchVisible()          {
		return this.isVisible;
	}
}

SOURCE := cv.md
TEMPLATE := templates/CV.template.tex
xp ?= 5
verbose ?= 0
OUTPUT_PDF := cv-xp-$(xp).pdf

.PHONY: doctor validate icons test pdf check ci clean

doctor:
	@./scripts/doctor.sh "$(SOURCE)" "$(TEMPLATE)"

validate:
	@./scripts/validate-cv.sh --input "$(SOURCE)"

icons:
	@./scripts/ensure-icons.sh

test:
	@./tests/render-cv.sh

pdf: validate icons
	@TMP_DIR="$$(mktemp -d)"; \
	trap 'rm -rf "$$TMP_DIR"' EXIT; \
	./scripts/render-cv.sh --input "$(SOURCE)" --output "$$TMP_DIR/cv.tex" --detailed-count "$(xp)"; \
	mkdir -p "$$TMP_DIR/texmf-var"; \
	if [ "$(verbose)" = "1" ]; then \
	  TEXMFVAR="$$TMP_DIR/texmf-var" lualatex -interaction=nonstopmode -halt-on-error -output-directory="$$TMP_DIR" "$$TMP_DIR/cv.tex"; \
	  TEXMFVAR="$$TMP_DIR/texmf-var" lualatex -interaction=nonstopmode -halt-on-error -output-directory="$$TMP_DIR" "$$TMP_DIR/cv.tex"; \
	else \
	  TEXMFVAR="$$TMP_DIR/texmf-var" lualatex -interaction=nonstopmode -halt-on-error -output-directory="$$TMP_DIR" "$$TMP_DIR/cv.tex" >"$$TMP_DIR/lualatex.pass1.log" 2>&1 || { \
	    echo "LaTeX pass 1 failed. Tail of $$TMP_DIR/lualatex.pass1.log:" >&2; \
	    tail -n 80 "$$TMP_DIR/lualatex.pass1.log" >&2; \
	    exit 1; \
	  }; \
	  TEXMFVAR="$$TMP_DIR/texmf-var" lualatex -interaction=nonstopmode -halt-on-error -output-directory="$$TMP_DIR" "$$TMP_DIR/cv.tex" >"$$TMP_DIR/lualatex.pass2.log" 2>&1 || { \
	    echo "LaTeX pass 2 failed. Tail of $$TMP_DIR/lualatex.pass2.log:" >&2; \
	    tail -n 80 "$$TMP_DIR/lualatex.pass2.log" >&2; \
	    exit 1; \
	  }; \
	fi; \
	cp "$$TMP_DIR/cv.pdf" "$(OUTPUT_PDF)"; \
	echo "Built $(OUTPUT_PDF)"

check: pdf
	@TMP_TEXT="$$(mktemp)"; \
	trap 'rm -f "$$TMP_TEXT"' EXIT; \
	if [ "$(xp)" = "full" ]; then \
	  ALLOW_MULTIPAGE=1 ./scripts/check-pdf.sh "$(OUTPUT_PDF)" "$$TMP_TEXT"; \
	else \
	  ./scripts/check-pdf.sh "$(OUTPUT_PDF)" "$$TMP_TEXT"; \
	fi

ci: doctor check

clean:
	@rm -f cv-xp-*.pdf

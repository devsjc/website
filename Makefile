SOURCES := $(shell find posts -mindepth 2 -name "*.typ")
POSTS := $(addprefix dist/, $(notdir $(SOURCES:.typ=.html)))

.PHONY: bundle
bundle: dist/index.html $(POSTS)

.PHONY: clean
clean:
	@rm -rf dist

.PHONY: dist
dist:
	@mkdir -p dist
	@cp style.css dist/

dist/%.html: posts/*/%.typ | dist
	@typst compile --features html --format html --root ../.. "$<" "$@.tmp"
	$(eval TITLE := $(shell grep 'head:' "$<" | head -n 1 | cut -d'"' -f2))
	@echo "<!DOCTYPE html><html lang='en'><head>" > $@
	@echo "<meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'>" >> $@
	@echo "<title>$(TITLE)</title><link rel='stylesheet' href='style.css'>" >> $@
	@sed -n '/<style/,/<\/style>/p' "$@.tmp" >> $@
	@echo "</head><body class='post'><main>" >> $@
	@sed -n '/<header>/,/<\/header>/p' index.html >> $@
	@echo "<section><article>" >> $@
	@sed -n '/<body/,/<\/body>/p' "$@.tmp" | sed '1d;$$d' >> $@
	@echo "</article></section></main></body></html>" >> $@
	@rm -f "$@.tmp"

dist/index.html: index.html $(SOURCES) | dist
	@rm -f dist/blog_list.tmp
	@for file in $(SOURCES); do \
		title=$$(grep 'head:' "$$file" | head -n 1 | cut -d'"' -f2); \
		date=$$(grep 'date:' "$$file" | head -n 1 | cut -d'"' -f2); \
		bname=$$(basename "$$file" .typ); \
		echo "<li><h1><a href='$$bname.html'>$$title</a></h1><time>$$date</time></li>" >> dist/blog_list.tmp; \
	done
	@sed -e '/<!-- BLOG_LIST_PLACEHOLDER -->/r dist/blog_list.tmp' -e '/<!-- BLOG_LIST_PLACEHOLDER -->/d' index.html > $@
	@rm -f dist/blog_list.tmp

.PHONY: serve
serve: bundle
	@uv run python -m http.server 8000 -d dist


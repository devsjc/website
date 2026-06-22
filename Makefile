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
	@cp SelectMonoItalic.woff2 dist

dist/%.html: posts/*/%.typ | dist
	@typst compile --features html --format html --root ../.. "$<" "$@.tmp"
	$(eval TITLE := $(shell grep 'head:' "$<" | head -n 1 | cut -d'"' -f2))
	@sed -n '1,/<\/header>/p' index.html | sed "s|<title>.*</title>|<title>$(TITLE)</title>|" | sed "s|<body[^>]*>|<body class="post">|" > $@
	@echo "<section><article>" >> $@
	@sed -n '/<body/,/<\/body>/p' "$@.tmp" | sed '1d;$$d' >> $@
	@echo "</article></section></main></body></html>" >> $@
	@rm -f "$@.tmp"

dist/index.html: index.html $(SOURCES) | dist
	@rm -f dist/blog_list.tmp dist/blog_list_sorted.tmp
	@for file in $(SOURCES); do \
		title=$$(grep 'head:' "$$file" | head -n 1 | cut -d'"' -f2); \
		date=$$(grep 'date:' "$$file" | head -n 1 | cut -d'"' -f2); \
		bname=$$(basename "$$file" .typ); \
		fmt_date=$$(uv run python -c "from datetime import datetime; print(datetime.strptime('$$date', '%Y-%m-%d').strftime('%d %b'))"); \
		echo "$$date|<li><time datetime='$$date'>$$fmt_date</time><a href='$$bname.html'>$$title</a></li>" >> dist/blog_list.tmp; \
	done
	@sort -r dist/blog_list.tmp | cut -d'|' -f2 > dist/blog_list_sorted.tmp
	@sed -e '/<!-- BLOG_LIST_PLACEHOLDER -->/r dist/blog_list_sorted.tmp' -e '/<!-- BLOG_LIST_PLACEHOLDER -->/d' index.html > $@
	@rm -f dist/blog_list.tmp dist/blog_list_sorted.tmp

.PHONY: serve
serve: clean bundle
	@uv run python -m http.server 8000 -d dist


.PHONY: clean
clean:
	@rm -rf dist

.PHONY: bundle
bundle: clean
	@mkdir -p dist
	@cp -r static dist/
	@cp index.html dist/
	@cp robots.txt dist/
	@cp static/assets/favicon.ico dist/

.PHONY: serve
serve: bundle
	@cd dist && uv run python -m http.server


.PHONY: clean
clean:
	@rm -rf dist

.PHONY: bundle
bundle: clean
	@mkdir -p dist
	@cp -r static dist/
	@cp index.html dist/


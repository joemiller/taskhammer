test:
	echo TODO

deps-docs: ## install dependencies for building documentation into .tmp/
	pip install --user -r https://raw.githubusercontent.com/Hammerspoon/hammerspoon/master/requirements.txt
	rm -rf .tmp
	mkdir .tmp
	curl -sL https://github.com/Hammerspoon/hammerspoon/tarball/master \
		| tar -C .tmp --strip-components=1 -xvzf - '*/scripts/docs'

build-zip: ## generate ./Spoons/TaskHammer.spoon.zip
	cd Source && \
		zip -r ../Spoons/TaskHammer.spoon.zip TaskHammer.spoon

build-docs:: build-spoon-docs
build-docs:: build-repo-docs

build-spoon-docs: ## generate ./Source/TaskHammer.spoon/docs.json
	.tmp/scripts/docs/bin/build_docs.py \
		--templates .tmp/scripts/docs/templates \
		--json \
		--standalone \
		--validate \
		--output_dir ./Source/TaskHammer.spoon \
		./Source/TaskHammer.spoon

build-repo-docs: ## generate the ./docs directory to make this repo compatible with SpoonInstall
	mkdir ./docs-tmp
	.tmp/scripts/docs/bin/build_docs.py \
		--templates .tmp/scripts/docs/templates \
		--json \
		--html \
		--standalone \
		--debug \
		--output_dir ./docs-tmp \
		./Source
	rm -rf -- ./docs
	mv ./docs-tmp ./docs

todo:
	@grep \
		--exclude-dir=vendor \
		--exclude-dir=dist \
		--exclude-dir=Attic \
		--text \
		--color \
		-nRo -E 'TODO:.*' .

.PHONY: test deps-docs build-spoon-docs build-repo-docs build-zip
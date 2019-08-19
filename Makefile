GITHUB_ORG := joemiller
GITHUB_REPO := taskhammer

lint: ## run luacheck linter
	luacheck Source/TaskHammer.spoon/*.lua

test: ## run tests
	echo "TODO: implement unit tests"

build-zip: ## generate ./Spoons/TaskHammer.spoon.zip
	cd Source && \
		zip -r ../Spoons/TaskHammer.spoon.zip TaskHammer.spoon

deps-docs: ## install dependencies for building documentation into .tmp/
	pip install --user -r https://raw.githubusercontent.com/Hammerspoon/hammerspoon/master/requirements.txt
	rm -rf .tmp
	mkdir .tmp
	curl -sL https://github.com/Hammerspoon/hammerspoon/tarball/master \
		| tar \
			-C .tmp \
			--strip-components=1 \
			-xzf -

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
		--output_dir ./docs-tmp \
		./Source
	rm -rf -- ./docs
	mv ./docs-tmp ./docs

ci-ssh-key: ## helper task for creating a SSH key to use on CircleCI to push to github
	ssh-keygen -t rsa -b 4096 -m PEM -N "" -f circle-ssh-key
	# ssh-keygen -E md5 -lf "circle-ssh-key" | awk '{print $2}' | sed 's/^....//'
	@echo "Next steps:"
	@echo "1. 'cat circle-ci-key.pub' | pbcopy'. Add pub-key to github with write access: https://github.com/$(GITHUB_ORG)/$(GITHUB_REPO)/settings/keys/new"
	@echo "2. 'cat circle-ci-key' | pbcopy'. Add private-key to circleci with hostname 'github.com': https://circleci.com/gh/$(GITHUB_ORG)/$(GITHUB_REPO)/edit#ssh"
	@echo "3. Add '- add_ssh_keys' step to the 'release' job in .circleci/config.yml"

todo:
	@grep \
		--exclude-dir=vendor \
		--exclude-dir=dist \
		--exclude-dir=Attic \
		--text \
		--color \
		-nRo -E 'TODO:.*' .

.PHONY: test deps-docs build-spoon-docs build-repo-docs build-zip
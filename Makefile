# Lint all scripts in the repository using shellcheck.
.PHONY: lint
lint:
	@set -e ;\
	for file in $$(find . -type f -name '*.sh') ; do \
		shellcheck -S warning $$file ;\
	done ;\
	echo "Success!"



# Dotfiles repo tasks. The integration test mirrors CI exactly (ADR-0009).
.PHONY: integration-test lint secrets hooks

# Enable the repo git hooks once per clone (warn-level gitleaks pre-commit, ADR-0007).
hooks:
	git config core.hooksPath .githooks
	@echo "git hooks enabled (.githooks): pre-commit runs gitleaks in warn mode."

# Full isolated installation in a fresh container (same as CI).
integration-test:
	docker build -t dotfiles-it -f Dockerfile .

# Static shell lint (advisory).
lint:
	find . -path ./.git -prune -o -name '*.sh' -print | xargs -r shellcheck -s bash -e SC1091

# Secret scan (ADR-0007 level 1).
secrets:
	docker run --rm -v "$$PWD:/repo" zricethezav/gitleaks:latest detect --source=/repo --redact --no-banner

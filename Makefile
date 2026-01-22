# Blaze Makefile
#
# Usage:
#   make atoms          # Validate and render atoms
#   make validate-atoms # Validate atoms.jsonl only
#   make render-roadmap # Render roadmap from atoms
#   make build          # Build Swift project
#   make test           # Run Swift tests

.PHONY: atoms validate-atoms render-roadmap build test clean help

# Default target
help:
	@echo "Blaze Makefile"
	@echo ""
	@echo "Atom Management:"
	@echo "  make atoms          - Validate and render atoms (run before commit)"
	@echo "  make validate-atoms - Validate atoms.jsonl against v2 schema"
	@echo "  make render-roadmap - Render feature-roadmap.md from atoms"
	@echo ""
	@echo "Development:"
	@echo "  make build          - Build Swift project"
	@echo "  make test           - Run Swift tests"
	@echo "  make clean          - Clean build artifacts"
	@echo ""

# Atom management
validate-atoms:
	@echo "==> Validating atoms.jsonl..."
	python3 scripts/validate_atoms.py docs/atoms/atoms.jsonl --schema v2

render-roadmap:
	@echo "==> Rendering roadmap..."
	python3 scripts/render_atoms_roadmap.py --input docs/atoms/atoms.jsonl --output docs/roadmap/feature-roadmap.md

atoms: validate-atoms render-roadmap
	@echo "==> Atoms validated and roadmap rendered"

# Development
build:
	@echo "==> Building Blaze..."
	cd Blaze && swift build

test:
	@echo "==> Running tests..."
	cd Blaze && swift test

clean:
	@echo "==> Cleaning..."
	cd Blaze && swift package clean
	rm -rf Blaze/.build

# CI helper - check if rendered roadmap matches committed version
check-roadmap:
	@echo "==> Checking roadmap is up-to-date..."
	@python3 scripts/render_atoms_roadmap.py --input docs/atoms/atoms.jsonl --output /tmp/roadmap-check.md
	@diff -q docs/roadmap/feature-roadmap.md /tmp/roadmap-check.md || \
		(echo "ERROR: Roadmap is out of date. Run 'make atoms' and commit." && exit 1)
	@echo "OK: Roadmap is up-to-date"

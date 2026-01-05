#!/usr/bin/env bash

# Validation Script for Cloudflare DNS Updater
# Runs ShellCheck and shfmt checks

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_ROOT="$DIR/.."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_tool() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo -e "${YELLOW}Warning: $1 is not installed. Skipping $2 check.${NC}"
		return 1
	fi
	return 0
}

echo -e "${GREEN}Starting validation...${NC}"

# 1. ShellCheck (Static Analysis & Security)
if check_tool "shellcheck" "Static Analysis"; then
	echo "Running ShellCheck..."
	if shellcheck "$PROJECT_ROOT"/*.sh "$PROJECT_ROOT"/src/*.sh; then
		echo -e "${GREEN}✔ ShellCheck passed!${NC}"
	else
		echo -e "${RED}✘ ShellCheck found issues.${NC}"
		EXIT_CODE=1
	fi
fi

# 2. Syntax Check (Bash -n)
echo "Running syntax check (bash -n)..."
syntax_errors=0
for file in "$PROJECT_ROOT"/*.sh "$PROJECT_ROOT"/src/*.sh; do
	if ! bash -n "$file"; then
		echo -e "${RED}✘ Syntax error in $file${NC}"
		syntax_errors=$((syntax_errors + 1))
	fi
done

if [[ $syntax_errors -eq 0 ]]; then
	echo -e "${GREEN}✔ Syntax check passed!${NC}"
else
	EXIT_CODE=1
fi

# 3. shfmt (Formatting check)
if check_tool "shfmt" "Formatting"; then
	echo "Running shfmt check..."
	if shfmt -d "$PROJECT_ROOT"; then
		echo -e "${GREEN}✔ Formatting is correct!${NC}"
	else
		echo -e "${YELLOW}⚠ Formatting issues found. Run 'shfmt -w .' to fix.${NC}"
		# We don't fail the build for formatting locally unless preferred
	fi
fi

exit ${EXIT_CODE:-0}

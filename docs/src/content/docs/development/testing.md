---
title: Testing & Validation
description: Run the unit test suite and the validation tooling.
---

## Unit tests

Tests are written with [bashunit](https://bashunit.com) and live in `tests/`, one file per `src/` module with fixtures under `tests/fixtures/`.

```bash
# One-time setup: installs a pinned, checksum-verified bashunit into lib/
./tools/install-bashunit.sh

# Whole suite, parallel
./lib/bashunit --parallel tests/

# One file, or filter by name
./lib/bashunit tests/config_test.sh
./lib/bashunit tests/ --filter "cache_lookup"
```

Tests are plain Bash functions named `test_*`. Network access is never required: external commands and the `http_request`/`http_get` helpers are replaced with `bashunit::mock` and `bashunit::spy`.

```bash
function test_public_ipv4_from_first_service() {
	bashunit::mock http_get fake_http_get_first_service_ok
	assert_same "192.0.2.55" "$(get_public_ipv4)"
}
```

## Validation suite

```bash
./tools/validate.sh
```

Runs, in order: ShellCheck (static analysis), `bash -n` (syntax), shfmt (formatting), yamllint (YAML), actionlint (GitHub workflows) and the unit tests. Tools that are not installed are skipped with a warning.

## Continuous integration

Every push and pull request runs two workflows:

- **Lint & Validation** — `tools/validate.sh` with all tools installed (actionlint is pinned and checksum-verified).
- **Tests** — the bashunit suite in parallel, with a JUnit report uploaded as an artifact.

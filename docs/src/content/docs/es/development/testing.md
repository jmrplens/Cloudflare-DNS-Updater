---
title: Tests y validación
description: Ejecuta la batería de tests unitarios y las herramientas de validación.
---

## Tests unitarios

Los tests están escritos con [bashunit](https://bashunit.com) y viven en `tests/`, un fichero por módulo de `src/` con fixtures en `tests/fixtures/`.

```bash
# Preparación (una vez): instala en lib/ una versión fija de bashunit con checksum verificado
./tools/install-bashunit.sh

# Toda la batería, en paralelo
./lib/bashunit --parallel tests/

# Un fichero, o filtrar por nombre
./lib/bashunit tests/config_test.sh
./lib/bashunit tests/ --filter "cache_lookup"
```

Los tests son funciones Bash normales llamadas `test_*`. Nunca necesitan red: los comandos externos y los helpers `http_request`/`http_get` se sustituyen con `bashunit::mock` y `bashunit::spy`.

```bash
function test_public_ipv4_from_first_service() {
	bashunit::mock http_get fake_http_get_first_service_ok
	assert_same "192.0.2.55" "$(get_public_ipv4)"
}
```

## Suite de validación

```bash
./tools/validate.sh
```

Ejecuta, en orden: ShellCheck (análisis estático), `bash -n` (sintaxis), shfmt (formato), yamllint (YAML), actionlint (workflows de GitHub) y los tests unitarios. Las herramientas no instaladas se omiten con un aviso.

## Integración continua

Cada push y pull request ejecuta dos workflows:

- **Lint & Validation** — `tools/validate.sh` con todas las herramientas instaladas (actionlint pineado y verificado con checksum).
- **Tests** — la batería de bashunit en paralelo, con informe JUnit como artefacto.

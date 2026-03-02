set no-exit-message := true

test-args := env("TEST_ARGS", "")

[private]
default:
    @just --list --unsorted --justfile {{ justfile() }}

# services

# run the generator
[group("Services")]
generate:
    @python3 -m generator

# run linters with autofix
[group("Linting")]
lint:
    ruff format . && ruff check --fix .

# run linters (check only)
[group("Linting")]
lint-check:
    ruff format --check . && ruff check .

# run tests
[group("Testing")]
test *args:
    pytest generator/tests/ {{ trim(test-args + " " + args) }}

# run ci checks (without tests)
[group("CI")]
ci-lint: lint-check

# run ci checks
[group("CI")]
ci *args: ci-lint (test args)

# build the demo wheel
[group("Demo")]
build-demo:
    @python3 generator/demo/build.py

# serve the demo
[group("Demo")]
serve-demo: build-demo
    @python3 -m http.server --directory generator/demo -b 127.0.0.1 8080

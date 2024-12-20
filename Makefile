all: ci

lint:
	ruff check

checkformat:
	ruff format --check

format:
	ruff format

test:
	pytest generator/tests/ ${ARGS}

generate:
	@python3 -m generator

ci: checkformat lint test

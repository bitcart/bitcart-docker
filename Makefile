all: ci

lint:
	flake8

checkformat:
	black --check .
	isort --check .

format:
	black .
	isort .

test:
	pytest generator/tests/ ${ARGS}

generate:
	python3 -m generator

ci: checkformat lint test
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
	true

ci: checkformat lint test
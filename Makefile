.PHONY: install run test check help

install:
	mix setup

run:
	mix phx.server

test:
	mix test

# The whole gate. Matches AGENTS.md; if the two ever disagree, this one is wrong.
check:
	mix format --check-formatted
	mix test
	mix credo --strict

help:
	@echo "Available commands:"
	@echo "  install  - Fetch dependencies and build assets"
	@echo "  run      - Start the Phoenix server on :4000"
	@echo "  test     - Run the test suite"
	@echo "  check    - Run the full gate: format, test, credo --strict"

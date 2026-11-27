.PHONY: hooks check test

# Install heartwood's own git hooks: the commit gate and the push guard.
hooks:
	guardrails/hooks/install

# Everything CI runs, for each package.
check:
	cd guardrails && mix precommit

test:
	cd guardrails && mix test

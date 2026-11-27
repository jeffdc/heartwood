.PHONY: hooks done-checks test

# Install heartwood's own git hooks: the commit gate and the push guard.
hooks:
	guardrails/hooks/install

# Everything CI requires, for each package: precommit (format, compile with
# warnings as errors, credo --strict, unused deps, tests), Dialyzer, and the
# security audits. Work isn't finished until this passes.
done-checks:
	cd guardrails && mix precommit && mix dialyzer && mix hex.audit && mix deps.audit

test:
	cd guardrails && mix test

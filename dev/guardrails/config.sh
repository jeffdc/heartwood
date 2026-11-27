# Heartwood's own guardrail settings, read by its git hooks and review scripts
# (guardrails/hooks/, guardrails/bin/). An app keeps the same file, with its
# own values. Sourced by sh and bash: assignments only.

# Names the reuse review's folder (<git dir>/heartwood-review) and the push
# guard's override (HEARTWOOD_PUSH_MAIN=1).
HEARTWOOD_APP=heartwood

# Where heartwood_guardrails is, from the repository's root. An app leaves it
# unset: deps/heartwood_guardrails/guardrails.
HEARTWOOD_HOME=guardrails

# Paths a commit may touch without a reuse review: a directory ends in /,
# anything else is one file. AGENTS.md and CLAUDE.md are always reviewed.
HEARTWOOD_PROSE="docs/ README.md guardrails/README.md guardrails/CHANGELOG.md"

# Where a new file needs the reviewer's justification.
HEARTWOOD_LIB="guardrails/lib/"

# This repository's questions for the reviewer, added to the packet.
HEARTWOOD_CHECKLIST=dev/guardrails/checklist.md

# The architecture review (mix heartwood.architecture, run from guardrails/):
# the architecture docs and this repository's questions are the defaults,
# docs/architecture/ and dev/guardrails/architecture.md. Modules are a level
# deeper than an app's (lib/heartwood/guardrails/<module>), so the graph
# folds at four path segments.
HEARTWOOD_GRAPH_DEPTH=4

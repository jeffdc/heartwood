# Architecture reviews

One entry per periodic architecture review, newest first. Jeff runs `mix heartwood.architecture` from `guardrails/` and gives its packet to several models; their reports are kept outside the repository (`<git common dir>/heartwood-architecture/<run>/`). He combines them into one entry here: a finding several models raise independently carries more weight. Each finding becomes a fix, an accepted exception with its reason, or a rule adopted into [rules.md](rules.md).

Committing an entry here starts the next review's commit range.

Template:

```
## YYYY-MM-DD: <run>, by <models>

- **Proposed rules:** …
- **Rules to automate:** …
- **Violations:** …
- **Rules to retire:** …
- **Docs out of date:** …
- **What became of each:** fix, exception (why) or rule (ID).
```

No reviews yet.

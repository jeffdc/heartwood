# Architecture reviewer instructions

These are the instructions for the periodic architecture review. Jeff runs it every so often, each time with several models for a mix of opinions, and combines their reports into one entry in the repository's `reviews.md`. Any agent or model can be the reviewer, so long as it starts with fresh context: not an author's conversation, plan or summary.

You review the whole repository against its architecture docs, not one change. The docs, in the packet, describe the system as built, its rules (each with its check, or "manual", and its baseline of known violations), Jeff's decisions and the past reviews. Your job is to find what they miss.

Your input is this packet: these instructions, the repository's own questions, how to record your report, and the evidence every run starts from: the commits since the last review, the dependencies between contexts (from `mix xref`), every ratchet's counts against its baseline, the pinned heartwood version, and the architecture docs. The packet is where you start, not where you stop: read the code as far as you need to confirm what you report.

## Your questions, in order

1. **Where is a new rule needed?** Look for a pattern in the code that no rule covers and that would do harm if it spread: a mistake made more than once, a boundary crossed, a convention kept only by habit, a dependency between contexts the docs don't explain. For each: the pattern, where it occurs, why it matters, and how it could be checked (a ratchet pattern, a test, a Credo check, a CI step), or why it needs judgement.
2. **Which manual rules could be automated, and how?** For each rule whose check is manual or partial, say whether a check could hold it, of which kind, and what exactly it would count or assert, concretely enough to build from.
3. **Violations of the rules that need judgement:** where the code breaks a manual rule beyond its recorded baseline.
4. **Rules worth retiring:** a rule that nothing could break any more, that a later decision contradicts, or whose cost outweighs what it prevents.
5. **Where the docs no longer match the code:** something the architecture docs describe that isn't so (a context, a table, a dependency, a process, a check), or something built that they don't mention. The dependencies and the commits since the last review are the places to start.
6. **The repository's questions:** answer each.

A ratchet's count over or under its baseline already fails the tests, so don't report it. But a large count, one concentrated in a few files, or one the baseline review didn't explain can point to a rule.

Only report what you've confirmed in the code, with paths and the evidence. A lead you couldn't confirm goes under "Not confirmed", with what would settle it. Don't report style, naming, formatting or test gaps that existing checks cover. Fewer findings with strong evidence are worth more than many thin ones: findings several models raise independently carry the most weight.

## Your report

Write it in this shape; you hand it to the recording script, so it needs no file of its own:

```
## Proposed rules

- **<short name>**: <the pattern>. Where: `path:line`, `path:line`. Why it matters: <one or two sentences>. Check: <how it could be checked, or "judgement", and why>.

## Rules to automate

- **<rule ID>**: <the check: its kind, and what it counts or asserts>. Evidence: <why it would hold the rule, with paths>.

## Violations

- **<rule ID>** `path:line`: <what breaks the rule, beyond its baseline>.

## Rules to retire

- **<rule ID>**: <why>.

## Docs out of date

- `<doc>`, <section>: it says <…>; the code <…> (`path`).

## The repository's questions

- **<the question>**: <the answer, with paths>.

## Not confirmed

- <the lead, and what would settle it>.
```

Write "None." under a heading with nothing in it.

## Recording it

Record your report as the packet's "Recording your report" section says, with your model's name or ID (for example `claude-opus-5-5`). The script refuses an empty report and a second report from the same model for the same run: if it refuses, say so and stop. Use the shell only for git's read commands, searching and reading files, `mix xref`, and the recording script. Never edit, stage or commit anything.

Your final message: your report.

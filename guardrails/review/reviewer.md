# Reuse reviewer instructions

These are the instructions for the reviewer in the commit routine ("Before you commit" in the repository's AGENTS.md). Any agent or model can be the reviewer, so long as it starts with fresh context: not the author's conversation, plan or summary. A different model from the author's is better still.

You review one staged change before it is committed. You have no stake in the plan that produced it. The author's account isn't evidence: read the code.

Your input is this packet. It holds these instructions, the repository's own checklist, how to record your verdict, the staged tree's hash, the files, the new files under the code directories, every new public definition (pulled from the diff), and the full diff. Read all of it. If you can't, list the parts you didn't read in your report and give **block**: an unread part can't pass. The author then splits the change.

## Your questions, in order

1. **What in this change already exists in the codebase?** For each new public function, component, module and LiveView in the packet, and for each new block of logic in the diff, search the codebase for code that already does the same job: the same query, search, mapping, decision, component or mechanic, even when written differently. Look where the repository's checklist says, and in the modules the change calls. A duplicate is code the change could have called or extended instead of writing.
2. **Is each new file justified?** For each file the packet lists under "New files", name the existing modules you searched for one that does its job, and say why none fits. If one fits, that's a **duplicate**.
3. **Does a replacement leave its old code in place?** When the change builds something that replaces existing code (a component, page, module, function or path), the old one must be deleted in this same change. "Kept for now" is a finding.
4. **The repository's checklist:** answer each question it adds.

Only report what you've confirmed in the code, with paths. Don't report style, naming or test gaps; other checks cover those.

## Your report

Write it in this shape; you hand it to the recording script, so it needs no file of its own:

```
## Findings

- **duplicate** `lib/new_place.ex:40` `new_fun/2` does what `Existing.fun/2` (`lib/existing.ex:112`) does: <one sentence>. Call or extend it.
- **replacement left** `MyApp.Old` is replaced by `MyApp.New` and still exists.
- **checklist** <a finding for one of the checklist's questions, named by it>.
- **unread** <the parts of the packet you didn't read>.
- **note** <anything worth the author's attention that doesn't block>.

## New files

- `lib/my_app/new_thing.ex`: searched <modules>; none fits because <reason>.

## Verdict

pass | block
```

Write "No findings." under Findings when there are none, and "None." under New files when the packet lists none.

**block** when there is any **duplicate**, **replacement left** or **unread** finding, or a **checklist** finding the checklist says blocks. Otherwise **pass**, with any other findings listed for the author.

## Recording it

Record your verdict as the packet's "Recording your verdict" section says. The script refuses an empty report, and refuses when the staging changed after the packet was made: then say so and stop, and the author makes a new packet. Use the shell only for git's read commands, searching, and the recording script. Never edit, stage or commit anything.

Your final message: the verdict and the findings, as in the report.

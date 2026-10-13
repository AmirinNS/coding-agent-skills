# Skill Updates: design-critique DESIGN.md overwrite guard

## Overview

`design-critique` ends a run by writing a `DESIGN.md` that becomes the binding design system
for the product. The skill did not say what to do when the project already has one, so a
critique run could silently replace a `DESIGN.md` the rest of the design chain still follows.
Phase 7 item 2 now requires showing the differences and asking before anything is replaced.
This is the same rule `design-study` already applies when it writes `DESIGN.md` from an
existing product, so both skills that write the file now behave the same way.

## The change

One sentence added to Phase 7 item 2 of `skills/design-critique/SKILL.md`:

> If a DESIGN.md already exists, show the differences and ask before replacing anything.

Nothing else in the skill changed.

## Usage

When a project already has a `DESIGN.md` (repo root, or `docs/` for projects that keep docs
there) and a critique run reaches Phase 7:

1. Compare the proposed `DESIGN.md` against the existing one.
2. Show the user the differences.
3. Ask before replacing anything.

A project with no `DESIGN.md` still gets one written from the shared
`design-md-template.md` with no extra prompt, exactly as before.

## Notes

- The intro shortcuts already told the skill to read an existing `DESIGN.md` and treat it as
  the starting point, so this closes the gap between reading the file and overwriting it.
- `design-study` Step 6 carries the identical sentence. Keep the two in sync if either
  wording changes.

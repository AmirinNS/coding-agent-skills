# UI/UX workflows

## Choose a skill

| Request | Skill | Result |
| --- | --- | --- |
| “Review this checkout for usability problems” | `$design-critique` | Prioritized findings with an observation, user impact, proposed fix, and repeatable check. |
| “Show me three ways to redesign this checkout” | `$design-critique` | Design directions to compare. Capture the approved direction in `DESIGN.md` when establishing the design system. |
| “Apply this design in the app” | `$frontend-design` | Production UI that follows the approved prototype, existing components, and `DESIGN.md`. |

The [Design Critique skill](../skills/design-critique/SKILL.md) links to the [focused UX checks](../skills/design-critique/references/focused-checks.md) and the [redesign workflow](../skills/design-critique/references/redesign.md). If the project already has a `DESIGN.md`, review the proposed differences and confirm before replacing it.

## Look up a design pattern during implementation

The [Frontend Design skill](../skills/frontend-design/SKILL.md) can consult the bundled UI UX Pro Max lookup when a task needs a specific pattern or a candidate visual direction. Run a domain lookup for a focused question, use stack search for a supported framework, or generate a candidate design system when the project needs a direction. The approved design and project conventions govern the build.

From the repository root, this command looks up a validation pattern:

```sh
python3 -B skills/frontend-design/vendor/ui-ux-pro-max/scripts/search.py \
  "error summary validation" --domain ux -n 1
```

The lookup uses Python 3 and resolves its catalogs within the copied skill. The [lookup guide](../skills/frontend-design/references/ui-ux-pro-max.md) includes commands for other working directories, the pinned upstream revision, and the bundled license.

## Research watchlists

The spreadsheets contain direct Facebook links and filterable topics for the examples that informed the focused checks.

- [Marcelo Design X](../research_notes/ui-ux/marcelo-design-x-ui-ux-watchlist.xlsx)
- [UIUXMaestro](../research_notes/ui-ux/uiuxmaestro-ui-ux-watchlist.xlsx)
- [Design with me](../research_notes/ui-ux/design-with-me-ui-ux-watchlist.xlsx)

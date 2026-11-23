# UI UX Pro Max lookup

Use the bundled lookup when the task needs a starting design direction or a specific pattern. Locate `vendor/ui-ux-pro-max/scripts/search.py` relative to the loaded `frontend-design/SKILL.md`. Run the script by absolute path from any working directory.

## Choose a lookup

- **Visual direction.** When the project has neither an existing design system nor an approved prototype and needs a direction, use `--design-system` to generate a candidate. Evaluate it against the product, audience, and existing constraints. Record adopted choices through the usual `DESIGN.md` workflow.
- **UX pattern.** Use a short, focused query with an explicit domain, such as `--domain ux` for form validation or keyboard interactions.
- **Stack-specific pattern.** Use `--stack` with the framework detected in the project when that stack is listed in `--help`. For Bootstrap, use general UX guidance and the project's Bootstrap components.

Check that returned guidance applies to the task, platform, and framework version. Use the output as a reference and implement to the approved prototype and `DESIGN.md`. If a lookup is unavailable or irrelevant, continue with the project's design system and the shared design references.

## Run the search

Replace `SKILL_DIR` with the absolute path to the folder containing the loaded `frontend-design/SKILL.md`. Use `python3` on macOS or Linux, or `py -3` on Windows when available. These commands print results to standard output.

```text
python3 -B "SKILL_DIR/vendor/ui-ux-pro-max/scripts/search.py" "error summary validation" --domain ux -n 3
python3 -B "SKILL_DIR/vendor/ui-ux-pro-max/scripts/search.py" "ecommerce retail storefront" --design-system --format markdown
python3 -B "SKILL_DIR/vendor/ui-ux-pro-max/scripts/search.py" "form input labels" --stack html-tailwind -n 3
```

## Bundled source

The Python modules and catalogs are copied from the [upstream commit](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/tree/2de1134dc4d1cfe112934611ae5803ae17a1bd7e). The [upstream license](../vendor/ui-ux-pro-max/LICENSE) and catalog provenance files are included with the bundle. Update the modules and catalogs together when changing the pinned revision.

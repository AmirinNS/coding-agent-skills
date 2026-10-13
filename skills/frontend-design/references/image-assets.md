# Generated image assets

Claude Code cannot create raster images. When a prototype or build needs one (hero photo,
illustration, empty-state art, app icon, texture), delegate it with `delegate-work-codex`.
Use `delegate-work-agy` if Codex is unavailable or its `image_generation` feature is off.
Do not generate images for wireframes. Use gray boxes labeled with the intended content.

## Brief fields
- Purpose and where it appears (screen, component, slot size).
- Exact output path and file name, e.g. `design/<feature>/assets/hero.png`.
- Size and aspect ratio, format (PNG or WebP), transparent background or not.
- Style tied to DESIGN.md tokens: palette hex values, mood, illustration or photo.
- Number of variants, and light and dark versions if the product supports both.
- Exclusions: no text in the image, no real brand logos or characters, no real people's faces.

## Review
1. Confirm each file exists at the given path.
2. Open it with Read and check it against the brief and DESIGN.md.
3. Resume the same thread with specific corrections, at most 2 rounds.
4. Save the final prompt next to the asset (e.g. `hero.prompt.md`) so it can be regenerated.

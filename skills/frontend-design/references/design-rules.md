# Design Rules

Shared by `frontend-design` and `prototype-ui`. Apply to wireframes, prototypes, and production code.

**Typography**
- One family (max two: display + body). A defined type scale, e.g. 32/24/20/16/14/12 — no sizes outside it.
- 3–4 sizes per screen. Hierarchy via size *and* weight, not color alone.
- Body line-height 1.4–1.6; line length 45–75 characters on web.
- Tabular numerals (`font-variant-numeric: tabular-nums`) wherever numbers are compared or update.
- Native iOS/Android or app-like mobile web: system fonts (SF Pro / Roboto) are a correct choice — distinctiveness then comes from color, layout, imagery, iconography and copy. Web marketing pages: a characterful font *that fits the chosen direction*.

**Color**
- Everything as CSS variables / tokens; no hard-coded hex in components.
- Roughly 60/30/10: dominant neutral, secondary surface, one accent. The accent marks the primary action and key states — don't spend it on decoration.
- Semantic colors (positive, negative, warning) are tokens, so they can follow locale conventions.
- WCAG AA: 4.5:1 for body text, 3:1 for large text and UI components, in light and dark mode. Never color alone for meaning.

**Spacing & layout**
- 4/8pt spacing scale; no arbitrary values.
- Consistent margins (16–20px mobile, wider on desktop) and padding.
- One focal point and one primary action per screen, matching the core job. Group with space before reaching for borders.
- Asymmetry, overlap, grid-breaking only when the direction calls for it and hierarchy stays clear.

**Components**
- One radius scale, one elevation scale, one icon set. Same component = same look everywhere.
- Touch targets ≥44×44pt (iOS) / 48×48dp (Android); ≥40px on web.

**Motion**
- Purposeful: confirm actions, show relationships, smooth state changes. 150–300ms for UI transitions.
- Product UI shouldn't re-animate on every view; one orchestrated entrance is fine on marketing pages.
- Respect `prefers-reduced-motion`.

**Backgrounds & detail**
- Texture, gradients, grain, glow and decorative borders only when they belong to the chosen direction. If you can't say what an effect does for the user in one sentence, remove it.

**Intensity is a dial, not a default**
- Product UI (apps, dashboards, settings, forms, checkout): restraint. Clarity and speed beat atmosphere.
- Marketing / landing / portfolio / game menus: more room for expressive type, motion, texture — if the direction calls for it.

**Don't fall into defaults — old or new**
- Classic AI look: purple/blue gradients on white, gradient text, centered hero + three identical icon cards, cards inside cards, emoji icons, buzzword copy ("seamless", "effortless", "unlock").
- Newer "trying-to-look-designed" look, unless the user chose it: warm cream background + high-contrast serif headline + grain overlay + staggered fade-ins + oversized numbers, regardless of context.
- Distinctive means *fits this product, these users and this person's taste*, not *unusual*.
- **Consistency over novelty**: within one product every screen uses the same system. Variety belongs in exploration, not between screens.

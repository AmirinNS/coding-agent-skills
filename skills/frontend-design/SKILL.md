---
name: frontend-design
description: "Implement distinctive, production-grade frontend interfaces with high design quality. ONLY for frontend features involving UI, pages, or components — do NOT trigger for backend-only work. Use after the plan is reviewed and approved. Triggers: 'build the frontend', 'implement the UI', 'build this page', 'create the component', 'implement the design'. Do NOT trigger on: API endpoints, database changes, pipeline logic, or backend-only features."
---

# Frontend Design

This skill implements **frontend-only** features with distinctive, production-grade aesthetics that avoid generic "AI slop." Only use when the feature involves UI work (pages, components, styles, layouts). For backend-only features, skip this skill and implement directly using CLAUDE.md guidelines.

It sits between plan review and implementation review in the workflow:

```
Planning → Review Plan (5x) → **Frontend Design (implement)** → Review Implementation (2x) → Create Docs → Commit
```

> **Note:** This is a design implementation skill. The CLAUDE.md simplicity rules apply to engineering logic (data flow, state, API calls). Aesthetic code (animations, layouts, visual effects) follows the design guidelines below — complexity here serves the user experience, not the architecture.

## Step 1: Read the Plan and Review Log

Before writing any code:
1. Read the approved plan file in `plans/` — understand the goal, scope, and affected files.
2. Read the **review log** at the bottom of the plan — understand what changed during review and why. Don't re-introduce things that were cut.
3. Read existing code that will be modified — match patterns, understand conventions.

If no plan exists, ask: "Is there an approved plan for this feature?"

## Step 2: Design Thinking

Before coding, understand the context and commit to a BOLD aesthetic direction:
- **Purpose**: What problem does this interface solve? Who uses it?
- **Tone**: Pick an extreme: brutally minimal, maximalist chaos, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel, industrial/utilitarian, etc. There are so many flavors to choose from. Use these for inspiration but design one that is true to the aesthetic direction.
- **Constraints**: Technical requirements (framework, performance, accessibility).
- **Differentiation**: What makes this UNFORGETTABLE? What's the one thing someone will remember?

**CRITICAL**: Choose a clear conceptual direction and execute it with precision. Bold maximalism and refined minimalism both work — the key is intentionality, not intensity.

## Step 3: Implement

Build working code (HTML/CSS/JS, React, Vue, etc.) that is:
- Production-grade and functional
- Visually striking and memorable
- Cohesive with a clear aesthetic point-of-view
- Meticulously refined in every detail

Follow the plan's approach steps and affected files. Don't add scope beyond what was approved.

### Frontend Aesthetics Guidelines

Focus on:
- **Typography**: Choose fonts that are beautiful, unique, and interesting. Avoid generic fonts like Arial and Inter; opt instead for distinctive choices that elevate the frontend's aesthetics — unexpected, characterful font choices. Pair a distinctive display font with a refined body font.
- **Color & Theme**: Commit to a cohesive aesthetic. Use CSS variables for consistency. Dominant colors with sharp accents outperform timid, evenly-distributed palettes.
- **Motion**: Use animations for effects and micro-interactions. Prioritize CSS-only solutions for HTML. Use Motion library for React when available. Focus on high-impact moments: one well-orchestrated page load with staggered reveals (animation-delay) creates more delight than scattered micro-interactions. Use scroll-triggering and hover states that surprise.
- **Spatial Composition**: Unexpected layouts. Asymmetry. Overlap. Diagonal flow. Grid-breaking elements. Generous negative space OR controlled density.
- **Backgrounds & Visual Details**: Create atmosphere and depth rather than defaulting to solid colors. Add contextual effects and textures that match the overall aesthetic. Apply creative forms like gradient meshes, noise textures, geometric patterns, layered transparencies, dramatic shadows, decorative borders, custom cursors, and grain overlays.

NEVER use generic AI-generated aesthetics like overused font families (Inter, Roboto, Arial, system fonts), cliched color schemes (particularly purple gradients on white backgrounds), predictable layouts and component patterns, and cookie-cutter design that lacks context-specific character.

Interpret creatively and make unexpected choices that feel genuinely designed for the context. No design should be the same. Vary between light and dark themes, different fonts, different aesthetics. NEVER converge on common choices (Space Grotesk, for example) across generations.

**IMPORTANT**: Match implementation complexity to the aesthetic vision. Maximalist designs need elaborate code with extensive animations and effects. Minimalist or refined designs need restraint, precision, and careful attention to spacing, typography, and subtle details. Elegance comes from executing the vision well.

## Step 4: Verify

After implementation, check before handing off to review:
- [ ] Renders correctly in browser — no broken layouts or missing assets
- [ ] Responsive — works on mobile, tablet, and desktop viewports
- [ ] Interactive elements work — buttons, links, hover states, animations trigger correctly
- [ ] Matches the plan's acceptance criteria
- [ ] No console errors or warnings
- [ ] Accessibility basics — keyboard navigation, sufficient contrast, semantic HTML

## Rules
- Read the plan and review log before writing any code.
- Follow the plan's scope — don't add pages, components, or features that weren't approved.
- Aesthetic complexity is encouraged. Engineering complexity follows CLAUDE.md (keep it simple).
- Push for extraordinary creative work. Don't hold back — show what can truly be created when thinking outside the box and committing fully to a distinctive vision.
- If the plan doesn't specify a design direction, propose one to the user before implementing.

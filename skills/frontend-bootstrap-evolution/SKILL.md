---
name: frontend-bootstrap-evolution
description: "Implement high-end, production-grade interfaces using Bootstrap 5, heavily customized to achieve modern, 'un-bootstrapped' aesthetics. ONLY for projects that use Bootstrap 5 as their CSS framework. Triggers: 'build with bootstrap', 'bootstrap component', 'style this bootstrap', 'upgrade the bootstrap UI', 'make this not look like bootstrap'. Do NOT trigger when the project uses Tailwind, plain CSS, or other frameworks."
---

# Frontend Bootstrap Evolution

This skill implements distinctive frontend interfaces using **Bootstrap 5** as the foundation, while intentionally breaking away from its default "component-library" look. The goal is to produce code that feels custom-designed, leveraging Bootstrap's grid and utilities without sacrificing artistic soul.

## Input

The user asks to build or restyle a frontend component, page, or layout using Bootstrap 5. They may provide:
- A component to build ("create a pricing card with Bootstrap")
- An existing Bootstrap UI to upgrade ("make this dashboard not look like Bootstrap")
- A design direction ("glassmorphism nav using Bootstrap")

If the project doesn't use Bootstrap 5, suggest using the `frontend-design` skill instead.

## Step 1: Read Context

Before coding:
1. If a plan exists in `plans/`, read it — understand scope and affected files.
2. Read existing code to understand current Bootstrap usage, custom overrides, and CSS variables already in place.
3. Don't introduce conflicting styles — extend what's there.

## Step 2: Design Thinking

Commit to a direction that disguises the Bootstrap "skeleton":

* **The "Anti-Bootstrap" Rule**: If it looks like a default Bootstrap card or button, it's a failure. Modify border-radii, shadows, and padding to move toward **Material's** depth or **Tailwind's** clean, utility-first precision.
* **Tone**: Use Bootstrap for the heavy lifting (Modals, Grids, Navs) but skin it with a specific vibe: *Glassmorphism, Neumorphism, Ultra-Minimalist, or High-Contrast Brand.*
* **Differentiation**: Use "Utility Injection" — add custom CSS classes to override Bootstrap defaults (e.g., replacing `.btn-primary` logic with custom floating-action-button styles).

## Step 3: Implement

Deliver **Bootstrap 5 HTML** structure accompanied by a **Custom CSS block** that transforms the base classes into something unrecognizable and high-end.

### Typography
* **System Font Defiance**: Replace the default stack with characterful pairings (e.g., a serif for headings like *Playfair Display* and a modern sans like *Outfit* for body).
* **Fluid Type**: Use `clamp()` for font sizes so the "Bootstrap responsiveness" feels smooth rather than stepped.

### Elevated Surface & Depth
* **Soft Shadows**: Replace Bootstrap's `.shadow` classes with multi-layered, colored shadows (Tailwind style) to create real depth.
  * Example: `box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);`
* **Surface Logic**: Use semi-transparent backgrounds with `backdrop-filter: blur()` to create modern "Glass" layers over Bootstrap containers.

### Motion & Micro-interactions
* **Transition Overrides**: Bootstrap transitions are often 0.15s. Slow them down to 0.3s or 0.4s with `cubic-bezier` curves for a more "luxury" feel.
* **Hover States**: Don't just change the background color. Add subtle lifts (`transform: translateY(-4px)`) and glow effects.

### Layout Breaking
* **Gutter Control**: Use Bootstrap's `g-0` or custom gutter variables to create "full-bleed" sections or overlapping elements that break the standard 12-column visual boredom.

### Implementation Details
* **CSS Variables**: Always use `:root` variables for colors and spacing to ensure the entire Bootstrap suite (Buttons, Alerts, Cards) updates cohesively.
* **HTML Structure**: Use Bootstrap 5's utility classes (e.g., `rounded-pill`, `border-0`, `p-lg-5`) to move away from rigid components and toward a "Tailwind-like" bespoke construction.
* **No "AI Slop"**: Avoid the "Purple Gradient Dashboard" trope. Experiment with brutalist monochrome, earthy organic tones, or high-fashion editorial layouts.

## Step 4: Verify

After implementation, check:
- [ ] Renders correctly — no broken Bootstrap grid or missing components
- [ ] Responsive — Bootstrap breakpoints work with custom overrides
- [ ] Custom CSS doesn't break other Bootstrap components on the page
- [ ] Interactive elements work — modals, dropdowns, tooltips still function after restyling
- [ ] No console errors or missing dependencies

## Rules
- If it looks like default Bootstrap, it's not done. Every component must be visually transformed.
- Extend Bootstrap, don't fight it. Use its utilities and grid — override the aesthetics, not the structure.
- Always deliver both the HTML structure and the custom CSS block together.
- Match existing CSS variable patterns in the project. Don't create a parallel theming system.
- Aesthetic complexity is encouraged. Engineering complexity follows CLAUDE.md (keep it simple).

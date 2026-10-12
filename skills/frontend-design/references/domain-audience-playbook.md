# Domain & Audience Playbook

Shared by `frontend-design` and `prototype-ui`.

Defaults, not laws. The user's taste can override them, but when a preference conflicts with a domain's core need (trust, legible numbers, safety), say so once and offer a version that keeps both.

**By domain**
- **Banking / personal finance**: Trust and calm. Balances and key numbers prominent, tabular numerals, clear transaction states (pending/complete/failed), explicit review-and-confirm for money movement, security cues (masked account numbers, biometric prompts). Avoid: gimmicks, decorative motion, meaning by red/green alone.
- **Trading / investing / crypto**: Density and speed. Real-time updates without layout shift, gains/losses with sign and arrow as well as color, dark mode for long sessions, fast but reviewable order entry, fees and risk visible. Avoid: animating every price tick, cramped order buttons, hiding costs.
- **CRM / B2B SaaS / admin**: Scan-ability. Tables, filters, search, bulk actions, keyboard shortcuts, compact density option, neutral palette with one accent, empty states that teach. Avoid: marketing-style heroes inside the app, cards where a table works better.
- **Healthcare / wellness**: Calm and reassuring, plain language, larger text, high contrast, privacy cues. Avoid: alarming red unless urgent, jargon.
- **E-commerce / marketplace**: Imagery leads, clear price and buy button, trust signals (reviews, returns, delivery), short checkout. Avoid: clutter around the buy button, dark patterns.
- **Education / kids**: Friendly and encouraging, big targets, simple navigation, visible progress and rewards. Avoid: small text, dense menus.
- **Social / lifestyle / consumer**: Brand personality, expressive type and color, content-first, delightful motion. Avoid: personality that hurts readability.
- **Productivity / tools**: Speed, focus, keyboard-first, minimal chrome. Avoid: decoration competing with the user's content.
- **Government / utilities / insurance**: Accessibility first, plain language, step-by-step forms, conventional patterns. Avoid: novelty that confuses.
- **Games**: UI matches the art style, readable game state, minimal HUD, strong feedback. Avoid: generic app-style UI on top of stylized art.
- **Not listed?** Ask: what must users trust, understand, or do fastest here? Design around that.

**By audience**
- **Age**: Older users: body text 17–19px/pt+, high contrast, text labels over icon-only buttons, fewer hidden gestures. Teens/young adults: more expressive style and motion. Kids: big targets, minimal text.
- **Expertise**: Novices: guidance, progressive disclosure, fewer options per screen. Pros: density, shortcuts, customization, less hand-holding.
- **Context**: On the go / one-handed: key actions in thumb reach, large targets. Outdoors: strong contrast. Long desk sessions: dark mode option, low eye strain. Presenting or shared screens: larger type.
- **Frequency**: Daily power users: efficiency over discoverability. Occasional users: obviousness over efficiency.
- **Locale & culture**: Text expansion (German runs ~30% longer than English), right-to-left languages (Arabic, Hebrew), local number/date/currency formats via `Intl`. Color meanings differ: in China and South Korea, stock gains are shown in red and losses in green or blue.
- **Accessibility & devices**: Color-blind safe, screen-reader labels, font scaling / Dynamic Type; low-end phones or slow networks → lighter assets and fewer effects.

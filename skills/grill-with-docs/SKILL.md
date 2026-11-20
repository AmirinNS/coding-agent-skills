---
name: grill-with-docs
description: Run a structured design interview that resolves open decisions in dependency order, records agreed domain terms in GLOSSARY.md, and offers ADRs for significant trade-offs. Use when the user explicitly invokes grill-with-docs or asks to be grilled on a plan or design while documenting decisions.
license: MIT
disable-model-invocation: true
---

# Grill with Docs

Run this workflow only at the user's explicit request. Interview the user until you reach a shared understanding of the plan or design. Record agreed domain terms and architecture decisions as they come up. Adapted from Matt Pocock's `grill-with-docs`. See [LICENSE](LICENSE).

## Run the interview

1. Read the plan or design and inspect the relevant code, glossary, and existing decisions. Map the open decisions and which answers each depends on.
2. Ask every in-scope question whose prerequisites are settled in the current round. Number each question and give a recommended answer with its main trade-off. Phrase it so a yes accepts the recommendation. Hold dependent questions until their prerequisites are settled.
3. Verify facts in the code, docs, or environment before asking the user to decide. If an authorized subagent can research a fact independently, give it the lookup in a fresh context and ask the unaffected questions while it works. Otherwise, investigate directly. Surface contradictions between the user's description and the code for the user to resolve.
4. Wait for the user's answers, record agreements, and use those answers to determine the next round. Revisit earlier decisions when a later answer changes a premise. Keep unanswered decisions open.

Use this format for each round:

```md
**Q1. Partial cancellations**

Should a customer be able to cancel individual items before shipment?

**Recommendation** Yes. This lets customers remove one item without placing a new order, and the system can calculate the refund from the cancelled items.

---

**Q2. Next independent decision**

...
```

When all in-scope decisions are resolved, summarize what was agreed and ask the user to confirm the shared understanding. Wait for confirmation before any implementation. The interview itself covers only design discussion and the glossary and ADR updates described below.

## Record domain terms during the interview

- Read `GLOSSARY-MAP.md` at the repository root if present. Use it to locate the affected context's `GLOSSARY.md`. Ask which context applies if the plan and code leave it unclear. Use the root `GLOSSARY.md` for a single-context repository, creating it when the first term is agreed.
- Call out conflicts with existing definitions. Propose a canonical term when the user uses a vague or overloaded word. Test domain boundaries with concrete scenarios, such as whether an order can be partially cancelled after one item ships.
- Update the relevant glossary as soon as the user settles a term. Use one or two sentences to define each project-specific concept. Keep implementation details and decisions in their own docs. List misleading synonyms under `_Avoid_` and group terms when natural clusters emerge.

```md
# Ordering

This context tracks customer orders from placement through delivery.

## Language

**Order**

A customer's request to purchase one or more items.

_Avoid_ Purchase, transaction

**Invoice**

A request for payment sent to a customer after delivery.

_Avoid_ Bill, payment request
```

In a multi-context repository, the root map can list context glossaries and how they relate:

```md
# Glossary Map

## Contexts

- [Ordering](./src/ordering/GLOSSARY.md) receives and tracks customer orders.
- [Fulfillment](./src/fulfillment/GLOSSARY.md) manages picking and shipping.

## Relationships

- Ordering sends `OrderPlaced` events to Fulfillment to start picking.
```

## Offer ADRs when the rationale will matter later

Offer an architecture decision record only when all three conditions apply:

1. Reversing the decision would have a meaningful cost.
2. The choice would surprise a future reader without its context.
3. The user chose between real alternatives for specific reasons.

Look for significant architectural, integration, technology, or ownership decisions. Record constraints and rejected alternatives when they explain a choice the code alone would leave unclear.

When the user accepts the offer, write the ADR during the interview. Use root `docs/adr/` for system-wide decisions and the context's `docs/adr/` for decisions local to that context. Create the directory when needed. Follow an established ADR convention if the repository has one. Otherwise, use numbered filenames such as `0001-event-sourced-orders.md`. Find the highest existing number in the target directory and increment it, starting at `0001`.

Use a short title and one to three sentences covering the context, choice, and reason. Include status, alternatives, or consequences only if they help a future reader understand or revisit the decision.

# Focused checks and source examples

## Web accessibility

Use the project's required standard. When checking WCAG 2.2 AA, verify the applicable criteria and exceptions in the standard.

- Measure text on its rendered background. Check 4.5:1 for regular text and 3:1 for eligible large text. For controls and informative graphics, check the parts needed to identify them or their state against adjacent colors. The applicable non-text threshold is 3:1. [WCAG 2.2 contrast criteria](https://www.w3.org/TR/WCAG22/#contrast-minimum)
- Test a vertically scrolling flow at an effective width of 320 CSS pixels. Check for clipped labels or actions, loss of information, and two-direction scrolling. Apply the exception for content that needs a two-dimensional layout. [WCAG 2.2 reflow](https://www.w3.org/TR/WCAG22/#reflow)
- Check small or crowded pointer targets. WCAG 2.2 AA specifies 24 × 24 CSS pixels, with exceptions including adequate target spacing. Apply any larger target sizes required by the project or platform. [WCAG 2.2 target size](https://www.w3.org/TR/WCAG22/#target-size-minimum)
- Follow the task with a keyboard. Check that interactive controls are reachable, focus is visible and follows a meaningful order, and sticky elements or overlays leave the focused control visible. [WCAG 2.2 navigability](https://www.w3.org/TR/WCAG22/#navigable)

## Media-heavy pages

Measure loading, responsiveness, and visual stability when a change affects them. Compare the same route and conditions before and after. If a hero uses video or 3D, check whether the headline and primary action are available while the asset loads and whether a simpler experience works on narrower or slower devices. Label lab results and real-user measurements accordingly. [Core Web Vitals](https://web.dev/articles/vitals)

## Marcelo Design X examples

These links illustrate design decisions from the reel review. Use the example that fits the current task, then verify the proposed change in the user's own interface.

| Design question | What to check | Example |
| --- | --- | --- |
| Does the screen show more than the user needs for this decision? | Keep essential summaries and actions visible. Put optional detail behind a clear label. | [Trading app before and after](https://www.facebook.com/reel/1811094272941207) |
| Can someone scan the screen quickly? | Use smaller gaps within a group and larger gaps between groups. Check that a label reads as part of the right field or section. | [Spacing in app design](https://www.facebook.com/reel/1230404855209733) |
| Does the important element stand out and remain readable? | Review emphasis and contrast on the actual surface. Use color consistently for meaning and actions. | [Contrast and hierarchy](https://www.facebook.com/reel/2108228882930598), [Color as communication](https://www.facebook.com/reel/1046344960970130) |
| Can the page introduce the offer in a different way? | Compare hero structures while keeping the offer, relevant proof, and next action clear. | [Hero section alternatives](https://www.facebook.com/reel/1592471092414137) |
| Can the effect survive a narrower screen? | Check the mobile layout with the effect on and off. Verify that the content order and actions still work. | [Responsive 3D website example](https://www.facebook.com/reel/542869618268360) |
| What should be settled before adding polish? | Use a wireframe to check hierarchy and task order before investing in imagery and motion. | [Wireframe and final design](https://www.facebook.com/reel/1279394123710776) |

## UIUXMaestro examples

| Design question | What to check | Example |
| --- | --- | --- |
| Can users tell which action advances the task? | Compare the emphasis of the primary and supporting buttons in the same state. Give equally important choices equal styling. | [Primary button hierarchy](https://www.facebook.com/reel/2404609423693117) |
| Do the typography and icons stay readable with real content? | Use the longest labels and a wrapped line. Check line height, letter spacing, and how each icon aligns with its label. | [Line height and letter spacing](https://www.facebook.com/reel/1320838464456434), [Icon and text alignment](https://www.facebook.com/reel/1970583733802425) |
| Can users recover from invalid input? | Submit once with an invalid field. Check that the user can identify the field and correction and that other entries remain intact. | [Form input comparison](https://www.facebook.com/photo/?fbid=122246808692071299) |
| Do users know where they are in a multistep task? | Advance one stage, go back, and continue. Verify that the visible step tracks progress and prior entries are preserved. | [Stepper examples](https://www.facebook.com/photo/?fbid=122250547922071299) |
| Does the confirmation explain what happened? | Complete the action and check that the feedback names the result and presents a next action when one is needed. | [Confirmation comparison](https://www.facebook.com/photo/?fbid=122313156740071299) |
| Are frequent actions easy to reach and select? | Try primary and adjacent actions on a narrow touch screen. Check actual hit areas and the space between them. | [Fitts’s law in UI design](https://www.facebook.com/photo/?fbid=122259333344071299) |
| Where should the layout change? | Resize until real content wraps, collides, or loses its reading order. Test the task on both sides of the breakpoint. | [Choosing breakpoints](https://www.facebook.com/reel/3871993666455938), [Responsive layouts in Figma](https://www.facebook.com/reel/782358787347861) |

## Design with me examples

| Design question | What to check | Example |
| --- | --- | --- |
| Can users tell an initial load from a refresh? | Slow down each request. Check that the skeleton reserves space for the first load. On refresh, check that usable content stays visible and the interface indicates when the update starts and finishes. | [Loading skeletons](https://www.facebook.com/reel/1433235305267252), [Data refresh animation](https://www.facebook.com/reel/1322533259310277) |
| Is the result clear with reduced motion? | Complete the action with reduced motion enabled. Check that the final message states what happened and remains available long enough to read. | [Order confirmation transition](https://www.facebook.com/reel/4426622614148870) |
| Does a toggle communicate its state? | Switch it on and off with touch and keyboard where supported. Check that the control's visible and accessible states agree, including while the transition runs. | [Toggle animation](https://www.facebook.com/reel/1852250255769083) |
| Can users identify the current destination? | Navigate between destinations and check that the active label stays identifiable after the indicator moves and with reduced motion enabled. | [Navigation bar animation](https://www.facebook.com/reel/2759027474454300) |
| Can users read changing data? | Check that labels, values, and the trend are legible during updates and in the final chart with reduced motion enabled. | [Line chart animation](https://www.facebook.com/reel/2081503856090913) |
| Can users control a moving carousel? | Find the previous and next controls, move between items, and check that the current item is identifiable. Repeat with keyboard or touch where supported. | [Carousel in Figma](https://www.facebook.com/reel/1772696830598270) |

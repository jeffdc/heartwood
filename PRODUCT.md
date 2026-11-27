# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Heartwood has no users of its own: its components are seen by the users of the two apps that depend on it, described in each app's PRODUCT.md.

- **Oak Compendium** (`~/dev/oaks/PRODUCT.md`): oak identifiers, mostly iNaturalist identifiers, at a desk beside an observation or in the field on a phone; and researchers who need sourced taxonomy.
- **Gallformers** (`~/dev/gallformers/PRODUCT.md`): naturalists identifying a gall from what they can see, volunteer curators cataloging galls from the literature, and researchers who cite it.

Its developers are Jeff and the agents working in either app; anything here has to fit both apps without knowing which one it is in.

## Product Purpose

Code shared by Oak Compendium and Gallformers, so that what both apps need is built once: `heartwood_ui` (function components with their hooks and CSS: the photo viewer, then the fragment-and-reader) and `heartwood_guardrails` (the checks both apps hold their code to). Success: both apps show the same component behaving the same way, each in its own design system, and a fix lands in both.

## Positioning

The two apps are sister projects by the same author with the same toolchain and the same commitments to sourced facts and credited images; heartwood holds only what is the same in both.

## Operating Context

- Components are Phoenix function components with colocated hooks and CSS, used from two Phoenix LiveView apps.
- Each app themes a component with one adapter block mapping its design tokens onto the component's own custom properties. The visual authority is each app's design system: oaks' `DESIGN.md`, gallformers' `docs/design-system/`. Heartwood has no visual identity of its own; its defaults are neutral.

## Capabilities and Constraints

- App-free: nothing specific to one app (its modules, paths, tokens, names or rules) outside test fixtures. What differs per app is an attribute, a slot or a custom property.
- Components use their own class prefix in plain CSS in `@layer components`, reading only their own custom properties, each with a neutral default; no Tailwind utilities in their markup; `class` for layout only; English labels as attributes with defaults.
- Photos come from iNaturalist and contributors under their own licenses. Every photo shows its credit: creator, license and source, and all rights reserved where it applies.
- Photo sets: one, none, or many; often 10 to 30 for a taxon. People both glance at a set and inspect one or two photos closely to check a feature.

## Brand Commitments

None of heartwood's own. Each app's name, voice and brand stay in that app.

## Evidence on Hand

- The photo viewer exists twice: Oak Compendium's `OaksWeb.PhotoViewer` (the app-free fork) and Gallformers' `photo_viewer/1`.
- No photos of heartwood's own; preview content is labelled as such.

## Product Principles

- Same behaviour, each app's look: a component behaves identically in both apps and takes its appearance from the app's design system.
- Credit is content: attribution and licensing are part of what a photo component shows, never fine print.
- Built for both scenes: a desk with a large screen, and a phone in the field with one hand and poor signal.

## Accessibility & Inclusion

WCAG 2.2 AA, in light and dark themes, with keyboard, screen reader and touch all first-class.

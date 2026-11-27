# Changelog

Every release that changes `heartwood_ui`, newest first. An entry that needs something from an app has "Upgrade:" steps. Versions are heartwood's tags (`v0.y.z`, one series for every package); while it's 0.x, a minor version needs action from an app and a patch is a drop-in.

## v0.2.0 (2026-11-27)

The first release: the photo viewer, `Heartwood.UI.PhotoViewer.photo_viewer/1`, from Oak Compendium's `OaksWeb.PhotoViewer` (itself a fork of Gallformers' `photo_viewer/1`), unified for both apps and redesigned with Jeff (2026-11-27). Its hook and CSS are LiveView colocated assets.

What changed from Oak Compendium's viewer:

- A filmstrip replaces the paged rail: no step buttons; thumbnails cut off at the right edge when more follow; the strip keeps the current one away from its edges. It sits directly under the stage, before the caption.
- The position ("2 / 10") is on the photo's upper right, not in the footer.
- The full view pans and zooms.
- `labels` replaces `empty`, and every word is a label. An `:actions` slot puts the app's links in the footer or the empty view.
- The layout follows the component's own width (a container query at 22rem), not the window's; the empty view no longer hides on phones.
- The stage fits its photo (`contain`) by default.
- Custom properties: `--pv-stage-ratio-narrow` and `--pv-visible-narrow` are gone; the wide layout is `--pv-stage-ratio-wide` and `--pv-visible-wide`. New: `--pv-frame-border`, the radii, the `font` shorthands (`--pv-cap-font`, `--pv-credit-font`, `--pv-meta-font`), `--pv-cap-ink`, `--pv-current`, `--pv-badge`, `--pv-badge-ink`, `--pv-dialog-border`. The README lists them all.

What changed from Gallformers' viewer, beyond the above: no arrows on the stage; the stage is sized by a ratio, not a fixed height; the empty view is the shared one, with the app's links in `:actions`; `on_change` is optional, so nothing is pushed unless asked; photo maps take atom keys only.

Upgrade:

- Tailwind 4.2.3 or later, and LiveView 1.2.
- Add the dependency, the hooks to `app.js`, the CSS to `app.css`, and `NODE_PATH` to the Tailwind and esbuild profiles, as the [README](README.md) says under "Using it in an app".
- Write the app's adapter block (the README lists the properties) and a wrapper that maps the app's images to photo maps and passes the adapter's class.
- Oak Compendium: `<.species_photos>` calls `Heartwood.UI.PhotoViewer.photo_viewer/1` with `class="oc-photos"`. In `.oc-photos`, keep the token mappings, add `--pv-frame-border: 1px solid var(--color-rule)` (the stage's and thumbnails' rule) and a paper `--pv-badge`; its ratios are the defaults. To keep hiding the empty view on phones, add that to `.oc-photos` with a media query. Delete `OaksWeb.PhotoViewer`, `assets/js/photo_viewer.js`, the `pv-` block in `components.css`, and the tests that moved here.
- Gallformers: a wrapper passes "Add images" (no photos) or "Edit photos" to `:actions` for an admin; a `.gf-` adapter block maps its tokens (an example is in `dev/preview.css`); the no-op `gallery_index_changed` handlers can go. Delete `photo_viewer/1`, its hook and their tests.

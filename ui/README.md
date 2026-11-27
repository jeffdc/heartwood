# heartwood_ui

Function components, with their hooks and CSS, shared by Oak Compendium and Gallformers. Each component takes the app's design system through its own custom properties: an app themes it with one adapter block and wraps it in its own component for what is the app's alone.

So far there is one component, the photo viewer (`Heartwood.UI.PhotoViewer`). The fragment-and-reader comes next.

## Using it in an app

### The dependency

A runtime dependency from GitHub, pinned to a release tag, with `sparse:` so only this folder is fetched (Mix checks it out at `deps/heartwood_ui/ui`):

```elixir
{:heartwood_ui, github: "jeffdc/heartwood", sparse: "ui", tag: "v0.2.0"}
```

With heartwood checked out locally, a `path:` dependency on `<checkout>/ui` takes its place; the apps switch with `HEARTWOOD_PATH` (see the root README).

It needs Phoenix LiveView 1.2 and Tailwind 4.2.3 or later, and the app compiles with LiveView's compiler (`compilers: [:phoenix_live_view] ++ Mix.compilers()`), as Phoenix 1.8 apps do.

### Its hooks and CSS

The components' hooks and CSS are LiveView colocated assets: they live in the components' templates, and LiveView writes them to `_build/$MIX_ENV/phoenix-colocated/heartwood_ui/` when the package compiles, however it was fetched. The app imports them from there:

- In `app.js`, the hooks, merged into the app's own:

  ```javascript
  import {hooks as heartwoodHooks} from "phoenix-colocated/heartwood_ui"
  const Hooks = {...colocatedHooks, ...heartwoodHooks, /* the app's own */}
  ```

- In `app.css`, after the app's own components:

  ```css
  @import "phoenix-colocated/heartwood_ui/colocated.css";
  ```

- Tailwind and esbuild have to find `phoenix-colocated/`, so both profiles in `config/config.exs` set `NODE_PATH` to the deps and build paths:

  ```elixir
  env: %{"NODE_PATH" => Enum.join([Path.expand("../deps", __DIR__), Mix.Project.build_path()], ":")}
  ```

The files are written when the package compiles, so `mix compile` runs before `mix assets.deploy` (in the Dockerfile and any release alias). The CSS is plain CSS in `@layer components`, so the app's own unlayered rules and utilities win over it.

### Theming: the adapter block

A component reads only its own custom properties (`--pv-*` for the photo viewer), each with a neutral default. The app writes one block that maps its tokens onto them, and passes that block's class to the component, usually from its own wrapper:

```css
.app-photos {
  --pv-ink: var(--app-ink);
  --pv-ground: var(--app-surface-2);
  --pv-focus: var(--app-focus);
  /* … */
}
```

The preview's `dev/preview.css` has both apps' blocks as examples.

A token that changes with the app's theme (dark mode, density) changes the component with it. Style the component only through its custom properties; its `pv-` classes are internal and may change in any release.

## The photo viewer

```heex
<Heartwood.UI.PhotoViewer.photo_viewer id="species-photos" label="Quercus montana" photos={@photos} class="app-photos">
  <:actions :if={@admin}><.link href={@edit}>Edit photos</.link></:actions>
</Heartwood.UI.PhotoViewer.photo_viewer>
```

### What it does

People glance at a set of photos and then look closely at one or two to check a feature, at a desk or on a phone in the field. The viewer is built for both.

- **The stage** shows the current photo whole (by default), at the ratio the theme sets, with its position ("2 / 10") in its upper right. There are no arrows on the photo.
- **The filmstrip**, directly under the stage, shows `--pv-visible` thumbnails whole and part of the next one, so a longer set shows that it runs on. The strip keeps the current thumbnail a whole thumbnail away from either edge: choosing the last one in view brings the next ones in, a view at a time. Trackpads and touch scroll it too.
- **The caption and credit** of the current photo come next: creator, license (linked when it has a link) and source. An all-rights-reserved photo puts © before the creator and the license, in bold, on its own line. The strip sits between the photo and its caption, so it never moves when captions differ in length.
- **The footer** has Details, then the `:actions` slot.
- **Moving**: a thumbnail, the Left and Right keys while focus is in the viewer, or a horizontal swipe on the photo. Moves wrap.
- **The full view** opens on a click on the photo: the photo as large as the screen allows, with its caption and credit, its position, previous and next arrows (wrapping), and pan and zoom. It zooms with the wheel or a trackpad pinch, a pinch on a touch screen, a double-click or double-tap, the `+`, `-` and `0` keys, and its zoom buttons (zoom out, zoom in, Fit); once zoomed in, dragging pans, never past the photo's edges. A swipe at the fitted size moves; a move goes back to the fitted size. Its photo, `full`, loads when it's first shown.
- **The details dialog** lists the photo's record: its position, caption, creator, license, attribution, source, uploader and who last changed it, the empty ones left out.
- **Dialogs** close with Escape, Close or a click outside, and focus goes back to what opened them. The page behind holds still.
- **One photo** has no filmstrip and no position. **No photos** shows the `empty` label and the `:actions` slot.
- **Its own width**, not the window's, sets its layout: a container query switches to `--pv-stage-ratio-wide` and `--pv-visible-wide` from 22rem (352px) up, and the details dialog stacks its rows when it is narrow.
- **When the photos change**, the viewer starts again at the first.

### Attributes

| Attribute | | |
|---|---|---|
| `id` | required | The viewer's id; its parts' ids start with it. |
| `photos` | required | A list of maps with atom keys (below). |
| `label` | required | What the photos show, for the alt text and the labels ("Photos of Quercus montana"). |
| `labels` | `%{}` | Words to replace, by key (below). |
| `on_change` | `nil` | An event pushed on every move, with `%{"index" => i}`. |
| `class` | `nil` | The app's adapter class, and layout. |
| `:actions` slot | | The app's own links or buttons: in the footer after Details, or in the empty view. |

A photo's keys: `src` (required, the stage's image, a medium size), `thumb` (the filmstrip's, small; defaults to `src`), `full` (the full view's; defaults to `src`), `alt` (defaults to the `alt` label), `caption`, `creator`, `license`, `licenselink`, `sourcelink`, `source_label` (the source link's words; defaults to the `source` label), `reserved` (true for all rights reserved), `attribution`, `uploader` and `lastchangedby` (in the details when given). A blank value counts as missing.

### Labels

`Heartwood.UI.PhotoViewer.default_labels/0` lists them all. `{n}`, `{count}`, `{label}` and `{alt}` are filled in where the defaults use them.

| Key | Default |
|---|---|
| `empty` | No photos yet. |
| `region` | Photos of {label} |
| `alt` | Photo {n} of {label} |
| `photo` | Photo {n} of {count} |
| `open` | {alt}, full size |
| `full_view` | Photos of {label}, full size |
| `details`, `details_title` | Details, Photo details |
| `close`, `previous`, `next` | Close, Previous photo, Next photo |
| `zoom_in`, `zoom_out`, `fit` | Zoom in, Zoom out, Fit |
| `source` | Source |
| `row_photo`, `row_caption`, `row_creator`, `row_license`, `row_attribution`, `row_source`, `row_uploader`, `row_last_changed_by` | Photo, Caption, Creator, License, Attribution, Source, Uploader, Last changed by |

### Custom properties

| Property | Default | What it sets |
|---|---|---|
| `--pv-ink`, `--pv-ink-2`, `--pv-ink-3` | `#1a1a1a`, `#404040`, `#5e5e5e` | Text: primary, the credit, the footer and empty view |
| `--pv-ground` | `#efefef` | Behind a photo, a thumbnail and the empty view |
| `--pv-paper` | `#ffffff` | The details dialog |
| `--pv-rule`, `--pv-rule-strong` | 15% black, ink | The details' rows, and the rule under its title |
| `--pv-link`, `--pv-focus` | inherited, `#1a62c9` | Links, and the focus outline |
| `--pv-current` | `--pv-ink` | The current thumbnail's outline |
| `--pv-frame-border` | none | A border on the stage and the thumbnails |
| `--pv-radius`, `--pv-thumb-radius` | `0px`, `--pv-radius` | Corners of the stage and empty view, and of the thumbnails |
| `--pv-control-radius`, `--pv-badge-radius`, `--pv-dialog-radius` | `0px` | Corners of buttons, the position and the details dialog |
| `--pv-dialog-border` | `2px solid` ink | The details dialog's border |
| `--pv-stage-ratio`, `--pv-stage-ratio-wide` | `4 / 5`, `4 / 3` | The stage's shape, narrow and from 22rem |
| `--pv-visible`, `--pv-visible-wide` | `5`, `6` | Whole thumbnails in the strip, narrow and from 22rem |
| `--pv-gap` | `4px` | Between the stage, the strip and the thumbnails |
| `--pv-fit` | `contain` | How the stage fits its photo (`cover` crops it) |
| `--pv-frame-font`, `--pv-read-font`, `--pv-title-font` | system sans, Georgia, `--pv-read-font` | Families: labels and credits, captions and details' values, the details' title |
| `--pv-cap-font`, `--pv-credit-font`, `--pv-meta-font` | 15px read, 13px frame, 13px frame 600 | `font` shorthands: the caption, the credit, the position and footer |
| `--pv-cap-ink` | inherited | The caption's colour |
| `--pv-badge`, `--pv-badge-ink` | 90% white, ink | The position on the photo |
| `--pv-lightbox`, `--pv-lightbox-ink` | `#111111`, `#f5f5f5` | The full view |
| `--pv-backdrop` | 60% black | Behind the details dialog |

### Contract

A change to any of these gets an entry in [CHANGELOG.md](CHANGELOG.md), with "Upgrade:" steps when an app has to do something:

- What an app imports: `phoenix-colocated/heartwood_ui` (its `hooks` export) and `phoenix-colocated/heartwood_ui/colocated.css`, and what they need (LiveView, Tailwind, `NODE_PATH`).
- Each component's module and function, its attributes and slots and their defaults, and the photo map's keys.
- The labels' keys, their defaults and their placeholders.
- The events a component pushes and their payloads (`on_change`).
- The custom properties, their defaults and what each sets; the width at which the container query switches.
- The behaviour described under "What it does": what moves and how, what the full view and details show, the states for one photo and none.

The `pv-` classes, the `data-*` attributes and the hook's name are internal: an app never targets them.

## Working on it

Run everything in heartwood's Nix dev shell, from `ui/`.

- **The preview**: `mix dev`, then http://localhost:4300 (or `PORT`). One page shows each component in every state, neutral or themed as Oak Compendium and Gallformers theme it (their adapter blocks are fixtures in `dev/preview.css`), at the widths the apps give it. Its photos are Oak Compendium's, at their own URLs; `PREVIEW_PHOTOS=local` uses generated photos instead.
- **The tests**: `mix test` for the server-rendered markup; `npm ci` once (and `npx playwright install chromium`), then `npm test` for the browser tests, which start the preview with its generated photos and need no network. Node and npm are for these tests only; the apps don't need them.
- `make done-checks`, from the root, runs everything CI does.

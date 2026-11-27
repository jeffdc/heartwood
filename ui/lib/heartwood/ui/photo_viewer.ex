defmodule Heartwood.UI.PhotoViewer do
  @moduledoc """
  The photo viewer: a set of photos, one on the stage at a time, a
  filmstrip of the rest, each photo's caption and credit, a full view with
  pan and zoom, and a details dialog.

  It is self-contained. Its markup uses only its own `pv-` classes, its
  script is the colocated `.PhotoViewer` hook, and its styles are the
  colocated `<style>` block below, in `@layer components`, reading only
  `--pv-*` custom properties, each with a neutral default. An app themes it
  with one adapter block that maps its tokens onto those properties, and
  passes it a class naming that block. The README lists the properties.
  """
  use Phoenix.Component

  @default_labels %{
    empty: "No photos yet.",
    region: "Photos of {label}",
    alt: "Photo {n} of {label}",
    photo: "Photo {n} of {count}",
    open: "{alt}, full size",
    full_view: "Photos of {label}, full size",
    details: "Details",
    details_title: "Photo details",
    close: "Close",
    previous: "Previous photo",
    next: "Next photo",
    zoom_in: "Zoom in",
    zoom_out: "Zoom out",
    fit: "Fit",
    source: "Source",
    row_photo: "Photo",
    row_caption: "Caption",
    row_creator: "Creator",
    row_license: "License",
    row_attribution: "Attribution",
    row_source: "Source",
    row_uploader: "Uploader",
    row_last_changed_by: "Last changed by"
  }

  @doc """
  The default labels: every word the viewer shows or announces. Pass
  `labels` with any of these keys to change them; `{n}`, `{count}`,
  `{label}` and `{alt}` are filled in where they appear in the defaults.
  """
  def default_labels, do: @default_labels

  @doc """
  Renders a set of photos.

  The stage shows the current photo whole, at the ratio the theme sets,
  with its position ("2 / 10") in its upper right. Directly under it is a
  filmstrip of every photo, cut off at the right edge when there are more
  than fit; the strip keeps the current photo away from its edges. Then
  the photo's caption and credit (creator, license, source), and a footer
  with Details and the `:actions` slot.

  The server renders every photo's slide, caption, full-size figure and
  details; the hook shows the current one. Thumbnails, the Left and Right
  keys (while focus is in the viewer, its dialogs included) and a
  horizontal swipe on the photo move between photos, and moves wrap.
  Clicking the photo opens the full view: the photo as large as the screen
  allows with its caption and credit, previous and next arrows, and pan and
  zoom (pinch, wheel, double-click or double-tap, the `+`, `-` and `0`
  keys, and dragging once zoomed in). The full-size image loads when it is
  first shown. Escape, Close or a click outside closes a dialog, and focus
  returns to what opened it. With `on_change`, every move pushes that event
  with `%{"index" => i}`. When the photos change, the viewer starts again
  at the first.

  With one photo there is no filmstrip and no position; with none, the
  `empty` label and the `:actions` slot.

  `photos` are maps with atom keys:

    * `src` (required): the stage image, a medium size
    * `thumb`: the filmstrip image, a small size (defaults to `src`)
    * `full`: the full view's image (defaults to `src`)
    * `alt` (defaults to the `alt` label: "Photo n of <label>")
    * `caption`, `creator`, `license`, `licenselink`
    * `sourcelink` and `source_label`: where the photo comes from, and the
      link's words (defaults to the `source` label)
    * `reserved`: all rights reserved: the creator is marked © and the
      license set on its own line in bold
    * `attribution`, `uploader`, `lastchangedby`: shown in the details
      when given

  ## Examples

      <.photo_viewer id="photos" label="Quercus montana" class="my-photos" photos={[
        %{src: medium, thumb: small, full: large, creator: "janedoe",
          license: "CC-BY", sourcelink: "https://www.inaturalist.org/observations/1",
          source_label: "iNaturalist observation"}
      ]}>
        <:actions><a href="/photos/edit">Edit photos</a></:actions>
      </.photo_viewer>
  """
  attr :id, :string, required: true
  attr :photos, :list, required: true
  attr :label, :string, required: true, doc: "what the photos show, for alt text and labels"
  attr :labels, :map, default: %{}, doc: "words to replace, by key (see `default_labels/0`)"
  attr :on_change, :string, default: nil, doc: "an event pushed with the index on every move"
  attr :class, :any, default: nil, doc: "the app's adapter class, and layout"

  slot :actions, doc: "the app's own links or buttons: in the footer, or in the empty view"

  def photo_viewer(assigns) do
    photos = assigns.photos
    labels = Map.merge(@default_labels, assigns.labels)

    assigns =
      assign(assigns,
        labels: labels,
        indexed: Enum.with_index(photos),
        count: length(photos),
        # A new id for new photos: LiveView replaces the ignored element
        # and the hook starts again on the new set.
        key: :erlang.phash2(photos)
      )

    ~H"""
    <style :type={Heartwood.UI.ColocatedCSS}>
      @layer components {
        .pv {
          container: pv / inline-size;
          color: var(--pv-ink, #1a1a1a);
        }
        .pv-in,
        .pv-empty {
          --_ratio: var(--pv-stage-ratio, 4 / 5);
          --_visible: var(--pv-visible, 5);
          --_gap: var(--pv-gap, 4px);
          --_radius: var(--pv-radius, 0px);
          --_thumb-radius: var(--pv-thumb-radius, var(--_radius));
          --_frame-font: var(--pv-frame-font, system-ui, sans-serif);
          --_read-font: var(--pv-read-font, Georgia, serif);
          --_cap-font: var(--pv-cap-font, 400 15px/1.45 var(--_read-font));
          --_credit-font: var(--pv-credit-font, 500 13px/1.45 var(--_frame-font));
          --_meta-font: var(--pv-meta-font, 600 13px/1.35 var(--_frame-font));
        }
        @container pv (min-width: 22rem) {
          .pv-in {
            --_ratio: var(--pv-stage-ratio-wide, 4 / 3);
            --_visible: var(--pv-visible-wide, 6);
          }
        }
        .pv [hidden] { display: none !important; }
        .pv :focus-visible {
          outline: 3px solid var(--pv-focus, #1a62c9);
          outline-offset: 2px;
        }
        .pv a {
          color: var(--pv-link, inherit);
          text-decoration-line: underline;
          text-decoration-thickness: 1px;
          text-underline-offset: 3px;
        }
        .pv a:hover { text-decoration-thickness: 2px; }

        .pv-empty {
          display: flex;
          flex-wrap: wrap;
          align-items: baseline;
          justify-content: space-between;
          gap: 8px 16px;
          padding: 14px 16px;
          background: var(--pv-ground, #efefef);
          border-radius: var(--_radius);
          font: var(--_meta-font);
          color: var(--pv-ink-3, #5e5e5e);
        }
        .pv-empty p { margin: 0; }

        .pv-stage { position: relative; }
        .pv-frame {
          display: block;
          width: 100%;
          aspect-ratio: var(--_ratio);
          padding: 0;
          overflow: hidden;
          background: var(--pv-ground, #efefef);
          border: var(--pv-frame-border, 0);
          border-radius: var(--_radius);
          cursor: zoom-in;
          touch-action: pan-y pinch-zoom;
        }
        .pv-frame img {
          display: block;
          width: 100%;
          height: 100%;
          object-fit: var(--pv-fit, contain);
        }
        .pv-badge {
          position: absolute;
          top: 8px;
          right: 8px;
          padding: 3px 7px;
          background: var(--pv-badge, rgb(255 255 255 / 0.9));
          color: var(--pv-badge-ink, #1a1a1a);
          border-radius: var(--pv-badge-radius, 0px);
          font: var(--_meta-font);
          font-variant-numeric: lining-nums tabular-nums;
          pointer-events: none;
        }

        /* The filmstrip: --pv-visible thumbnails whole and a part of the
           next, so a longer set shows it runs on. */
        .pv-strip {
          display: grid;
          grid-auto-flow: column;
          grid-auto-columns: calc((100% - var(--_visible) * var(--_gap)) / (var(--_visible) + 0.4));
          gap: var(--_gap);
          margin: var(--_gap) 0 0;
          padding: 0;
          list-style: none;
          overflow-x: auto;
          scroll-behavior: smooth;
          scrollbar-width: none;
          overscroll-behavior-x: contain;
        }
        .pv-strip::-webkit-scrollbar { display: none; }
        .pv-thumb {
          display: block;
          width: 100%;
          aspect-ratio: 1;
          padding: 0;
          overflow: hidden;
          background: var(--pv-ground, #efefef);
          border: var(--pv-frame-border, 0);
          border-radius: var(--_thumb-radius);
          cursor: pointer;
        }
        .pv-thumb img {
          display: block;
          width: 100%;
          height: 100%;
          object-fit: cover;
        }
        .pv-thumb[aria-current="true"] {
          outline: 2px solid var(--pv-current, var(--pv-ink, #1a1a1a));
          outline-offset: -2px;
        }
        .pv-thumb[aria-current="true"] img { opacity: 0.85; }
        .pv .pv-thumb:focus-visible { outline-width: 3px; outline-offset: -3px; }

        .pv-cap {
          margin: 10px 0 0;
          font: var(--_cap-font);
          color: var(--pv-cap-ink, inherit);
        }
        .pv-credit {
          margin: 4px 0 0;
          font: var(--_credit-font);
          color: var(--pv-ink-2, #404040);
        }
        .pv-credit b { font-weight: 700; color: var(--pv-ink, #1a1a1a); }
        .pv-credit a { white-space: nowrap; }
        /* The separator ends the item before it, so a wrapped line never
           starts with one. */
        .pv-credit > span:not(:last-of-type)::after { content: " ·"; }
        .pv-reserved {
          display: block;
          font-weight: 700;
          color: var(--pv-ink, #1a1a1a);
        }
        .pv-text > div > :first-child { margin-top: 10px; }

        .pv-foot {
          display: flex;
          flex-wrap: wrap;
          align-items: baseline;
          justify-content: flex-end;
          gap: 4px 16px;
          margin-top: 8px;
          font: var(--_meta-font);
          color: var(--pv-ink-3, #5e5e5e);
        }
        .pv-link {
          padding: 0;
          border: 0;
          background: none;
          font: inherit;
          color: var(--pv-link, inherit);
          text-decoration: underline;
          text-underline-offset: 3px;
          cursor: pointer;
        }
        .pv-link:hover { text-decoration-thickness: 2px; }

        /* Dialogs: the full view and the details. The page behind one
           holds still. */
        :root:has(.pv dialog[open]) { overflow: hidden; }
        .pv dialog::backdrop { background: var(--pv-backdrop, rgb(0 0 0 / 0.6)); }
        .pv-icon {
          position: relative;
          display: grid;
          place-items: center;
          width: 40px;
          height: 40px;
          padding: 0;
          background: none;
          border: 0;
          color: inherit;
          cursor: pointer;
        }
        .pv-icon:disabled { opacity: 0.4; cursor: default; }
        .pv-close::before,
        .pv-close::after,
        .pv-minus::before,
        .pv-plus::before,
        .pv-plus::after {
          content: "";
          position: absolute;
          top: 50%;
          left: 50%;
          width: 18px;
          height: 2px;
          background: currentColor;
          transform: translate(-50%, -50%);
        }
        .pv-close::before { transform: translate(-50%, -50%) rotate(45deg); width: 20px; }
        .pv-close::after { transform: translate(-50%, -50%) rotate(-45deg); width: 20px; }
        .pv-plus::after { transform: translate(-50%, -50%) rotate(90deg); }
        .pv-fit {
          padding: 6px 10px;
          background: none;
          border: 1px solid currentColor;
          border-radius: var(--pv-control-radius, 0px);
          color: inherit;
          font: var(--_meta-font);
          cursor: pointer;
        }
        .pv-fit:disabled { opacity: 0.4; cursor: default; }

        .pv-lightbox {
          width: 100%;
          height: 100%;
          max-width: none;
          max-height: none;
          margin: 0;
          padding: 0;
          border: 0;
          background: var(--pv-lightbox, #111111);
          color: var(--pv-lightbox-ink, #f5f5f5);
        }
        .pv-lightbox[open] { display: flex; flex-direction: column; }
        .pv-lightbox .pv-cap,
        .pv-lightbox .pv-credit,
        .pv-lightbox .pv-credit b,
        .pv-lightbox .pv-reserved { color: inherit; }
        .pv-lightbox a { color: inherit; }
        .pv-lb-bar {
          flex: none;
          display: flex;
          align-items: center;
          gap: 4px;
          padding: 8px 8px 8px 16px;
          font: var(--_meta-font);
          font-variant-numeric: lining-nums tabular-nums;
        }
        .pv-lb-bar .pv-count { margin-right: auto; }
        .pv-lb-stage {
          position: relative;
          flex: 1;
          min-height: 0;
          display: flex;
          padding: 0 16px 16px;
        }
        .pv-lb-figure {
          flex: 1;
          min-width: 0;
          min-height: 0;
          margin: 0;
          display: flex;
          flex-direction: column;
          align-items: center;
          gap: 8px;
        }
        .pv-lb-view {
          position: relative;
          flex: 1;
          min-height: 0;
          width: 100%;
          overflow: hidden;
          touch-action: none;
          cursor: zoom-in;
        }
        .pv-lb-view[data-zoomed] { cursor: grab; }
        .pv-lb-view[data-dragging] { cursor: grabbing; }
        .pv-lb-view img {
          position: absolute;
          inset: 0;
          width: 100%;
          height: 100%;
          object-fit: contain;
          transform-origin: 0 0;
          user-select: none;
          -webkit-user-drag: none;
        }
        .pv-lb-figure figcaption { max-width: 45rem; text-align: center; }
        .pv-lb-figure .pv-cap,
        .pv-lb-figure .pv-credit { margin-top: 0; }
        .pv-lb-step {
          position: absolute;
          top: 50%;
          display: grid;
          place-items: center;
          width: 44px;
          height: 64px;
          padding: 0;
          border: 0;
          border-radius: var(--pv-control-radius, 0px);
          background: color-mix(in srgb, var(--pv-lightbox, #111111) 60%, transparent);
          color: inherit;
          cursor: pointer;
          transform: translateY(-50%);
        }
        .pv-lb-step:hover { background: var(--pv-lightbox, #111111); }
        .pv-lb-prev { left: 8px; }
        .pv-lb-next { right: 8px; }
        .pv-lb-step::before {
          content: "";
          width: 12px;
          height: 12px;
          border-top: 2px solid currentColor;
          border-right: 2px solid currentColor;
        }
        .pv-lb-prev::before { transform: rotate(-135deg); margin-left: 6px; }
        .pv-lb-next::before { transform: rotate(45deg); margin-right: 6px; }

        .pv-details {
          container: pv-details / inline-size;
          width: min(34rem, calc(100% - 24px));
          max-width: none;
          max-height: calc(100% - 24px);
          margin: auto;
          padding: 0;
          background: var(--pv-paper, #ffffff);
          color: var(--pv-ink, #1a1a1a);
          border: var(--pv-dialog-border, 2px solid var(--pv-ink, #1a1a1a));
          border-radius: var(--pv-dialog-radius, 0px);
        }
        .pv-details[open] { display: flex; flex-direction: column; }
        .pv-details-title {
          flex: none;
          margin: 0 32px;
          padding: 24px 0 12px;
          font: 600 26px/1.15 var(--pv-title-font, var(--_read-font));
          border-bottom: 2px solid var(--pv-rule-strong, #1a1a1a);
        }
        .pv-details-body {
          flex: 0 1 auto;
          min-height: 0;
          overflow-y: auto;
          padding: 4px 32px 16px;
        }
        .pv-details dl { margin: 0; font: 14px/1.45 var(--_frame-font); }
        .pv-details dl > div {
          display: grid;
          grid-template-columns: 8.5rem minmax(0, 1fr);
          align-items: baseline;
          gap: 4px 24px;
          padding: 12px 0;
          border-bottom: 1px solid var(--pv-rule, rgb(0 0 0 / 0.15));
        }
        .pv-details dt { font-weight: 700; }
        .pv-details dd {
          margin: 0;
          font: 400 16px/1.5 var(--_read-font);
          overflow-wrap: anywhere;
        }
        .pv-details-actions {
          flex: none;
          display: flex;
          justify-content: flex-end;
          margin: 0 32px;
          padding: 16px 0 24px;
        }
        .pv-button {
          padding: 10px 13px;
          background: transparent;
          border: 1.5px solid currentColor;
          border-radius: var(--pv-control-radius, 0px);
          font: 700 14px/1 var(--_frame-font);
          color: var(--pv-ink, #1a1a1a);
          cursor: pointer;
        }
        .pv-button:hover { background: var(--pv-ink, #1a1a1a); color: var(--pv-paper, #ffffff); }
        @container pv-details (max-width: 30rem) {
          .pv-details-title,
          .pv-details-actions { margin-left: 16px; margin-right: 16px; }
          .pv-details-body { padding-left: 16px; padding-right: 16px; }
          .pv-details dl > div { grid-template-columns: minmax(0, 1fr); }
        }

        @media (prefers-reduced-motion: reduce) {
          .pv-strip { scroll-behavior: auto; }
        }
      }
    </style>
    <div id={@id} class={["pv", @class]}>
      <div :if={@count == 0} class="pv-empty">
        <p>{@labels.empty}</p>
        {render_slot(@actions)}
      </div>
      <div
        :if={@count > 0}
        id={"#{@id}-#{@key}"}
        class="pv-in"
        phx-hook=".PhotoViewer"
        phx-update="ignore"
        role="region"
        aria-roledescription="carousel"
        aria-label={label(@labels, :region, label: @label)}
        data-count={@count}
        data-event={@on_change}
      >
        <div class="pv-stage">
          <div
            :for={{photo, i} <- @indexed}
            data-slide={i}
            hidden={i != 0}
            role="group"
            aria-label={@count > 1 && label(@labels, :photo, n: i + 1, count: @count)}
          >
            <button
              type="button"
              class="pv-frame"
              data-open
              aria-label={label(@labels, :open, alt: alt(photo, i, @labels, @label))}
              aria-describedby={"#{@id}-text-#{i}"}
            >
              <img
                src={field(photo, :src)}
                alt={alt(photo, i, @labels, @label)}
                loading={if i == 0, do: "eager", else: "lazy"}
                draggable="false"
              />
            </button>
          </div>
          <span :if={@count > 1} class="pv-badge" data-counter>1 / {@count}</span>
        </div>

        <ol :if={@count > 1} class="pv-strip" data-thumbs>
          <li :for={{photo, i} <- @indexed}>
            <button
              type="button"
              class="pv-thumb"
              data-go={i}
              aria-current={to_string(i == 0)}
              aria-label={label(@labels, :photo, n: i + 1, count: @count)}
            >
              <img src={field(photo, :thumb) || field(photo, :src)} alt="" loading="lazy" />
            </button>
          </li>
        </ol>

        <div class="pv-text">
          <div :for={{photo, i} <- @indexed} id={"#{@id}-text-#{i}"} data-caption={i} hidden={i != 0}>
            <p :if={field(photo, :caption)} class="pv-cap">{field(photo, :caption)}</p>
            <.credit photo={photo} labels={@labels} />
          </div>
        </div>

        <div class="pv-foot">
          <button type="button" class="pv-link" data-open-details>{@labels.details}</button>
          {render_slot(@actions)}
        </div>

        <dialog
          class="pv-lightbox"
          data-lightbox
          aria-label={label(@labels, :full_view, label: @label)}
        >
          <div class="pv-lb-bar">
            <span class="pv-count"><span :if={@count > 1} data-counter>1 / {@count}</span></span>
            <button
              type="button"
              class="pv-icon pv-minus"
              data-zoom="out"
              aria-label={@labels.zoom_out}
              disabled
            />
            <button type="button" class="pv-icon pv-plus" data-zoom="in" aria-label={@labels.zoom_in} />
            <button type="button" class="pv-fit" data-zoom="fit" disabled>{@labels.fit}</button>
            <button type="button" class="pv-icon pv-close" data-close aria-label={@labels.close} />
          </div>
          <div class="pv-lb-stage">
            <figure
              :for={{photo, i} <- @indexed}
              class="pv-lb-figure"
              data-full={i}
              hidden={i != 0}
            >
              <div class="pv-lb-view" data-view>
                <img
                  data-src={field(photo, :full) || field(photo, :src)}
                  alt={alt(photo, i, @labels, @label)}
                  draggable="false"
                />
              </div>
              <figcaption>
                <p :if={field(photo, :caption)} class="pv-cap">{field(photo, :caption)}</p>
                <.credit photo={photo} labels={@labels} />
              </figcaption>
            </figure>
            <button
              :if={@count > 1}
              type="button"
              class="pv-lb-step pv-lb-prev"
              data-prev
              aria-label={@labels.previous}
            />
            <button
              :if={@count > 1}
              type="button"
              class="pv-lb-step pv-lb-next"
              data-next
              aria-label={@labels.next}
            />
          </div>
        </dialog>

        <dialog class="pv-details" data-details aria-labelledby={"#{@id}-details-title"}>
          <h2 id={"#{@id}-details-title"} class="pv-details-title">{@labels.details_title}</h2>
          <div class="pv-details-body">
            <dl :for={{photo, i} <- @indexed} data-info={i} hidden={i != 0}>
              <div :if={@count > 1}>
                <dt>{@labels.row_photo}</dt>
                <dd>{label(@labels, :photo, n: i + 1, count: @count)}</dd>
              </div>
              <div :for={{row, value} <- details(photo, @labels)}>
                <dt>{row}</dt>
                <dd>{value}</dd>
              </div>
            </dl>
          </div>
          <div class="pv-details-actions">
            <button type="button" class="pv-button" data-close autofocus>{@labels.close}</button>
          </div>
        </dialog>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".PhotoViewer">
      // The server renders every photo's slide, caption, full-size figure
      // and details; this shows the current one. Moves wrap: thumbnails,
      // the full view's arrows, Left/Right keys (while focus is in the
      // viewer, its dialogs included) and a horizontal swipe on a photo at
      // its fitted size. The filmstrip keeps the current thumbnail away
      // from its edges. The full view pans and zooms (wheel, pinch,
      // double-click or double-tap, + - 0, dragging once zoomed) and loads
      // a photo (data-src) when it is first shown; a move goes back to the
      // fitted size. With data-event, each move pushes that event with
      // {index}. Escape closes an open dialog wherever focus is; a click on
      // a dialog's backdrop closes it too, and closing returns focus to
      // what opened it.

      const SWIPE = 40 // px
      const TAP = 300 // ms between the taps of a double tap
      const MAX_ZOOM = 4
      const STEP = 1.5 // a zoom key or button

      export default {
        mounted() {
          this.index = 0
          this.count = parseInt(this.el.dataset.count || "0", 10)
          this.strip = this.el.querySelector("[data-thumbs]")
          this.lightbox = this.el.querySelector("[data-lightbox]")
          this.opener = null
          this.zoom = {s: 1, x: 0, y: 0}
          this.pointers = new Map()

          this.onClick = (e) => {
            const dialog = e.target.closest("dialog")
            if (dialog && e.target === dialog) return dialog.close() // its backdrop
            const target = e.target.closest("[data-prev], [data-next], [data-go], [data-open], [data-open-details], [data-close], [data-zoom]")
            if (!target || !this.el.contains(target)) return
            if (target.matches("[data-prev]")) this.go(this.index - 1)
            else if (target.matches("[data-next]")) this.go(this.index + 1)
            else if (target.matches("[data-go]")) this.go(parseInt(target.dataset.go, 10))
            else if (target.matches("[data-open]")) this.open("[data-lightbox]", target)
            else if (target.matches("[data-open-details]")) this.open("[data-details]", target)
            else if (target.matches("[data-close]")) target.closest("dialog")?.close()
            else if (target.matches("[data-zoom]")) this.zoomKey(target.dataset.zoom)
          }

          this.onKey = (e) => {
            if (e.altKey || e.ctrlKey || e.metaKey) return
            const full = this.lightbox?.open
            if (full && ["+", "=", "-", "0"].includes(e.key)) {
              e.preventDefault()
              return this.zoomKey(e.key === "-" ? "out" : e.key === "0" ? "fit" : "in")
            }
            if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return
            if (e.shiftKey) return
            e.preventDefault()
            const dir = e.key === "ArrowRight" ? 1 : -1
            if (full && this.zoom.s > 1) return this.panBy(-dir * 0.1)
            this.go(this.index + dir)
          }

          // A swipe on the stage photo moves.
          this.onPointerDown = (e) => {
            if (!e.isPrimary || !e.target.closest("[data-open]")) return
            this.swipeFrom = {x: e.clientX, y: e.clientY}
          }

          this.onPointerUp = (e) => {
            if (!this.swipeFrom) return
            const dx = e.clientX - this.swipeFrom.x
            const dy = e.clientY - this.swipeFrom.y
            this.swipeFrom = null
            if (Math.abs(dx) >= SWIPE && Math.abs(dx) > Math.abs(dy)) {
              this.swiped = true
              setTimeout(() => { this.swiped = false }, 0) // a swipe ends in at most one click
              this.go(dx < 0 ? this.index + 1 : this.index - 1)
            }
          }

          this.onPointerCancel = () => { this.swipeFrom = null }

          // A swipe ends with a click on the photo; it must not also open it.
          this.onClickCapture = (e) => {
            if (this.swiped) {
              this.swiped = false
              e.stopPropagation()
              e.preventDefault()
            }
          }

          this.onEscape = (e) => {
            if (e.key !== "Escape") return
            const open = this.el.querySelector("dialog[open]")
            if (open) {
              e.preventDefault()
              open.close()
            }
          }

          // The stage photo that opened a dialog may be hidden by now:
          // return to the one shown.
          this.onClose = (e) => {
            if (e.target === this.lightbox) this.resetZoom()
            let opener = this.opener
            if (opener?.closest("[data-slide]")) opener = this.el.querySelector(`[data-slide="${this.index}"] [data-open]`)
            if (opener && document.contains(opener)) opener.focus({preventScroll: true})
            this.opener = null
          }

          this.el.addEventListener("click", this.onClickCapture, true)
          this.el.addEventListener("click", this.onClick)
          this.el.addEventListener("keydown", this.onKey)
          this.el.addEventListener("pointerdown", this.onPointerDown)
          this.el.addEventListener("pointerup", this.onPointerUp)
          this.el.addEventListener("pointercancel", this.onPointerCancel)
          window.addEventListener("keydown", this.onEscape)
          this.el.querySelectorAll("dialog").forEach(d => d.addEventListener("close", this.onClose))
          this.mountZoom()
        },

        destroyed() {
          window.removeEventListener("keydown", this.onEscape)
        },

        go(index) {
          if (this.count < 2) return
          const wasOn = document.activeElement?.closest("[data-slide], [data-full], [data-info], [data-caption], [data-go]")
          this.index = (index + this.count) % this.count
          const i = String(this.index)

          for (const attr of ["data-slide", "data-caption", "data-full", "data-info"]) {
            this.el.querySelectorAll(`[${attr}]`).forEach(e => { e.hidden = e.getAttribute(attr) !== i })
          }

          this.el.querySelectorAll("[data-go]").forEach(b => b.setAttribute("aria-current", String(b.dataset.go === i)))
          this.el.querySelectorAll("[data-counter]").forEach(c => { c.textContent = `${this.index + 1} / ${this.count}` })
          this.keepInView(this.el.querySelector(`[data-go="${i}"]`)?.parentElement)
          this.resetZoom()

          // Focus follows the move from a thumbnail or the stage photo, and
          // leaves a photo that is now hidden (a link in its caption or
          // details) for its dialog's Close.
          if (wasOn?.matches("[data-go]")) this.el.querySelector(`[data-go="${i}"]`)?.focus({preventScroll: true})
          else if (wasOn?.matches("[data-slide]")) this.el.querySelector(`[data-slide="${i}"] [data-open]`)?.focus({preventScroll: true})
          else if (wasOn?.hidden) wasOn.closest("dialog")?.querySelector("[data-close]")?.focus()

          if (this.lightbox?.open) this.loadFull()
          if (this.el.dataset.event) this.pushEvent(this.el.dataset.event, {index: this.index})
        },

        // Scroll the strip, not the page. The current thumbnail stays a
        // whole thumbnail away from either edge: reaching the last one in
        // view brings the next ones in, a view at a time.
        keepInView(li) {
          const s = this.strip
          if (!li || !s) return
          const step = li.offsetWidth + parseFloat(getComputedStyle(s).columnGap || "0")
          const l = li.offsetLeft - s.offsetLeft
          const r = l + li.offsetWidth
          if (l - step < s.scrollLeft) s.scrollLeft = r + step - s.clientWidth
          else if (r + step > s.scrollLeft + s.clientWidth) s.scrollLeft = l - step
        },

        // The full-size photo is loaded only when it is shown.
        loadFull() {
          const img = this.el.querySelector(`[data-full="${this.index}"] img[data-src]`)
          if (img && !img.getAttribute("src")) img.setAttribute("src", img.dataset.src)
        },

        open(selector, opener) {
          const dialog = this.el.querySelector(selector)
          if (!dialog || dialog.open) return
          this.opener = opener
          dialog.showModal()
          if (dialog === this.lightbox) this.loadFull()
        },

        // -- Pan and zoom in the full view --

        view() {
          return this.el.querySelector(`[data-full="${this.index}"] [data-view]`)
        },

        mountZoom() {
          if (!this.lightbox) return
          const stage = this.lightbox

          stage.addEventListener("wheel", (e) => {
            const view = e.target.closest("[data-view]")
            if (!view) return
            e.preventDefault()
            const k = e.ctrlKey ? 0.01 : 0.002 // a pinch on a trackpad comes as ctrl+wheel
            this.zoomAt(this.point(view, e), this.zoom.s * Math.exp(-e.deltaY * k))
          }, {passive: false})

          stage.addEventListener("dblclick", (e) => {
            const view = e.target.closest("[data-view]")
            if (!view || e.pointerType === "touch") return
            this.toggleZoom(this.point(view, e))
          })

          stage.addEventListener("pointerdown", (e) => {
            const view = e.target.closest("[data-view]")
            if (!view) return
            view.setPointerCapture(e.pointerId)
            this.pointers.set(e.pointerId, {x: e.clientX, y: e.clientY})
            if (this.pointers.size === 1) this.gesture = {x: e.clientX, y: e.clientY, t: e.timeStamp, moved: false}
            if (this.pointers.size === 2) this.pinch = this.pinchState(view)
          })

          stage.addEventListener("pointermove", (e) => {
            const last = this.pointers.get(e.pointerId)
            if (!last) return
            const view = e.target.closest("[data-view]") || this.view()
            this.pointers.set(e.pointerId, {x: e.clientX, y: e.clientY})
            if (this.pointers.size === 2 && this.pinch) {
              const now = this.pinchState(view)
              this.zoomAt(now.mid, this.pinch.s * now.dist / this.pinch.dist)
              if (this.gesture) this.gesture.moved = true
            } else if (this.pointers.size === 1 && this.zoom.s > 1) {
              view.setAttribute("data-dragging", "")
              this.zoom.x += e.clientX - last.x
              this.zoom.y += e.clientY - last.y
              this.applyZoom()
              if (this.gesture) this.gesture.moved = true
            }
          })

          const up = (e) => {
            if (!this.pointers.has(e.pointerId)) return
            this.pointers.delete(e.pointerId)
            this.view()?.removeAttribute("data-dragging")
            if (this.pointers.size < 2) this.pinch = null
            const g = this.gesture
            if (this.pointers.size > 0 || !g || e.type === "pointercancel") return
            this.gesture = null
            const dx = e.clientX - g.x
            const dy = e.clientY - g.y
            if (g.moved) return
            if (this.zoom.s === 1 && Math.abs(dx) >= SWIPE && Math.abs(dx) > Math.abs(dy)) {
              return this.go(dx < 0 ? this.index + 1 : this.index - 1)
            }
            // A double tap on a touch screen: dblclick is not reliable there.
            if (e.pointerType === "touch" && Math.abs(dx) < 10 && Math.abs(dy) < 10) {
              if (this.lastTap && e.timeStamp - this.lastTap < TAP) {
                this.lastTap = null
                this.toggleZoom(this.point(this.view(), e))
              } else {
                this.lastTap = e.timeStamp
              }
            }
          }
          stage.addEventListener("pointerup", up)
          stage.addEventListener("pointercancel", up)
        },

        point(view, e) {
          const r = view.getBoundingClientRect()
          return {x: e.clientX - r.left, y: e.clientY - r.top}
        },

        pinchState(view) {
          const [a, b] = [...this.pointers.values()]
          const r = view.getBoundingClientRect()
          return {
            s: this.zoom.s,
            dist: Math.hypot(a.x - b.x, a.y - b.y) || 1,
            mid: {x: (a.x + b.x) / 2 - r.left, y: (a.y + b.y) / 2 - r.top}
          }
        },

        toggleZoom(p) {
          if (this.zoom.s > 1) this.resetZoom()
          else this.zoomAt(p, 2.5)
        },

        zoomKey(kind) {
          const view = this.view()
          if (!view) return
          const c = {x: view.clientWidth / 2, y: view.clientHeight / 2}
          if (kind === "fit") this.resetZoom()
          else this.zoomAt(c, this.zoom.s * (kind === "in" ? STEP : 1 / STEP))
        },

        // Zoom to scale s, keeping point p (in the view's box) where it is.
        zoomAt(p, s) {
          s = Math.min(MAX_ZOOM, Math.max(1, s))
          const z = this.zoom
          z.x = p.x - (p.x - z.x) * (s / z.s)
          z.y = p.y - (p.y - z.y) * (s / z.s)
          z.s = s
          this.applyZoom()
        },

        panBy(fraction) {
          const view = this.view()
          if (!view) return
          this.zoom.x += fraction * view.clientWidth
          this.applyZoom()
        },

        resetZoom() {
          this.zoom = {s: 1, x: 0, y: 0}
          this.el.querySelectorAll("[data-view] img").forEach(img => { img.style.transform = "" })
          this.el.querySelectorAll("[data-view]").forEach(v => v.removeAttribute("data-zoomed"))
          this.zoomButtons()
        },

        // Keep the photo over the view: no panning past its edges, and a
        // photo smaller than the view stays centred.
        applyZoom() {
          const view = this.view()
          const img = view?.querySelector("img")
          if (!img) return
          const z = this.zoom
          const w = view.clientWidth, h = view.clientHeight
          const nw = img.naturalWidth || w, nh = img.naturalHeight || h
          const fit = Math.min(w / nw, h / nh)
          const cw = nw * fit, ch = nh * fit
          const ox = (w - cw) / 2, oy = (h - ch) / 2
          const clamp = (pos, size, content, offset) => {
            const scaled = content * z.s
            if (scaled <= size) return (size - scaled) / 2 - offset * z.s
            return Math.min(-offset * z.s, Math.max(size - (offset + content) * z.s, pos))
          }
          z.x = clamp(z.x, w, cw, ox)
          z.y = clamp(z.y, h, ch, oy)
          if (z.s === 1) { z.x = 0; z.y = 0 }
          img.style.transform = z.s === 1 ? "" : `translate(${z.x}px, ${z.y}px) scale(${z.s})`
          view.toggleAttribute("data-zoomed", z.s > 1)
          this.zoomButtons()
        },

        zoomButtons() {
          const s = this.zoom.s
          this.el.querySelectorAll("[data-zoom='out'], [data-zoom='fit']").forEach(b => { b.disabled = s <= 1 })
          this.el.querySelectorAll("[data-zoom='in']").forEach(b => { b.disabled = s >= MAX_ZOOM })
        }
      }
    </script>
    """
  end

  attr :photo, :map, required: true
  attr :labels, :map, required: true

  # The credit line: creator, license, source link. All rights reserved
  # puts © before the creator and the license, in bold, on its own line.
  defp credit(assigns) do
    assigns = assign(assigns, reserved: Map.get(assigns.photo, :reserved, false) == true)

    ~H"""
    <p class="pv-credit">
      <span :if={field(@photo, :creator)}>
        {if @reserved, do: "© "}<b>{field(@photo, :creator)}</b>
      </span>
      <span :if={!@reserved && field(@photo, :license)}><.license photo={@photo} /></span>
      <span :if={field(@photo, :sourcelink)}>
        <a href={field(@photo, :sourcelink)} target="_blank" rel="noopener noreferrer">
          {field(@photo, :source_label) || @labels.source}
        </a>
      </span>
      <strong :if={@reserved && field(@photo, :license)} class="pv-reserved">
        {field(@photo, :license)}
      </strong>
    </p>
    """
  end

  attr :photo, :map, required: true

  defp license(assigns) do
    ~H"""
    <a
      :if={field(@photo, :licenselink)}
      href={field(@photo, :licenselink)}
      target="_blank"
      rel="noopener noreferrer"
    >{field(@photo, :license)}</a><span :if={!field(@photo, :licenselink)}>{field(@photo, :license)}</span>
    """
  end

  # The details dialog's rows for one photo, the empty ones left out.
  defp details(photo, labels) do
    [
      {labels.row_caption, field(photo, :caption)},
      {labels.row_creator, field(photo, :creator)},
      {labels.row_license, field(photo, :license) && license(%{photo: photo})},
      {labels.row_attribution, field(photo, :attribution)},
      {labels.row_source, field(photo, :sourcelink) && source_link(%{photo: photo})},
      {labels.row_uploader, field(photo, :uploader)},
      {labels.row_last_changed_by, field(photo, :lastchangedby)}
    ]
    |> Enum.filter(fn {_row, value} -> value end)
  end

  attr :photo, :map, required: true

  defp source_link(assigns) do
    ~H"""
    <a href={field(@photo, :sourcelink)} target="_blank" rel="noopener noreferrer">
      {field(@photo, :source_label) || field(@photo, :sourcelink)}
    </a>
    """
  end

  # A photo's text field; blank is nil.
  defp field(photo, key) do
    case Map.get(photo, key) do
      value when value in [nil, ""] -> nil
      value -> to_string(value)
    end
  end

  defp alt(photo, i, labels, label),
    do: field(photo, :alt) || label(labels, :alt, n: i + 1, label: label)

  # A label with its {placeholders} filled in.
  defp label(labels, key, bindings) do
    Enum.reduce(bindings, Map.fetch!(labels, key), fn {name, value}, text ->
      String.replace(text, "{#{name}}", to_string(value))
    end)
  end
end

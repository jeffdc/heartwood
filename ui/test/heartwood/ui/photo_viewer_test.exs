defmodule Heartwood.UI.PhotoViewerTest do
  # The server-rendered markup. What needs a browser (the hook, layout, pan
  # and zoom) is in test/browser, run against the preview.
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias Heartwood.UI.PhotoViewer

  @hook "Heartwood.UI.PhotoViewer.PhotoViewer"

  defp photo(n, attrs \\ %{}) do
    Map.merge(
      %{
        src: "/p#{n}_medium.jpg",
        thumb: "/p#{n}_small.jpg",
        full: "/p#{n}_large.jpg",
        creator: "janedoe - Jane Doe",
        license: "CC-BY-NC",
        licenselink: "https://creativecommons.org/licenses/by-nc/4.0/",
        sourcelink: "https://www.inaturalist.org/observations/#{n}",
        source_label: "iNaturalist observation"
      },
      attrs
    )
  end

  defp viewer(photos, opts \\ %{}) do
    assigns = Map.merge(%{photos: photos, labels: %{}, on_change: nil}, opts)

    rendered_to_string(~H"""
    <PhotoViewer.photo_viewer
      id="pv"
      label="Quercus montana"
      photos={@photos}
      labels={@labels}
      on_change={@on_change}
    />
    """)
  end

  defp parse(html), do: LazyHTML.from_fragment(html)
  defp count(doc, selector), do: doc |> LazyHTML.query(selector) |> Enum.count()

  defp text(doc, selector),
    do: doc |> LazyHTML.query(selector) |> LazyHTML.text() |> String.trim()

  defp texts(doc, selector),
    do: doc |> LazyHTML.query(selector) |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))

  describe "with no photos" do
    test "reads the empty label, with no hook, strip or dialogs" do
      doc = parse(viewer([]))

      assert text(doc, ".pv-empty") == "No photos yet."
      assert count(doc, "[phx-hook]") == 0
      assert count(doc, "[data-thumbs]") == 0
      assert count(doc, "dialog") == 0
    end

    test "shows the actions" do
      assigns = %{}

      doc =
        parse(
          rendered_to_string(~H"""
          <PhotoViewer.photo_viewer id="pv" label="Q" photos={[]}>
            <:actions><a href="/add">Add images</a></:actions>
          </PhotoViewer.photo_viewer>
          """)
        )

      assert text(doc, ".pv-empty a[href='/add']") == "Add images"
    end
  end

  describe "with one photo" do
    test "shows the photo and its credit, with no strip or position" do
      doc = parse(viewer([photo(1, %{caption: "Bark of a mature tree"})]))

      assert count(doc, "[phx-hook='#{@hook}'][phx-update=ignore][data-count='1']") == 1
      assert count(doc, "[data-slide]") == 1
      assert count(doc, "[data-slide='0']:not([hidden]) img[src='/p1_medium.jpg']") == 1
      assert text(doc, "[data-caption='0'] .pv-cap") == "Bark of a mature tree"
      assert count(doc, "[data-thumbs]") == 0
      assert count(doc, "[data-counter]") == 0
      assert count(doc, "[data-lightbox] [data-prev]") == 0
      assert count(doc, "[data-open-details]") == 1
      assert count(doc, ".pv-empty") == 0
    end
  end

  describe "with many photos" do
    setup do
      %{doc: parse(viewer(Enum.map(1..12, &photo/1)))}
    end

    test "renders every photo's slide, caption, full-size figure and details, the first shown",
         %{doc: doc} do
      assert count(doc, "[phx-hook='#{@hook}'][data-count='12']") == 1

      for attr <- ~w(data-slide data-caption data-full data-info) do
        assert count(doc, "[#{attr}]") == 12
        assert count(doc, "[#{attr}]:not([hidden])") == 1
        assert count(doc, "[#{attr}='0']:not([hidden])") == 1
      end
    end

    test "puts the filmstrip between the stage and the caption", %{doc: doc} do
      assert doc |> LazyHTML.query(".pv-in > *") |> Enum.map(&LazyHTML.attribute(&1, "class")) ==
               [
                 ["pv-stage"],
                 ["pv-strip"],
                 ["pv-text"],
                 ["pv-foot"],
                 ["pv-lightbox"],
                 ["pv-details"]
               ]
    end

    test "uses each size where it belongs", %{doc: doc} do
      assert count(doc, "[data-slide='4'] [data-open] img[src='/p5_medium.jpg']") == 1
      assert count(doc, "[data-go='4'] img[src='/p5_small.jpg']") == 1
      # The full size is loaded only when it is shown.
      assert count(doc, "[data-full='4'] img[data-src='/p5_large.jpg']:not([src])") == 1
    end

    test "has the filmstrip and the position the hook drives", %{doc: doc} do
      assert count(doc, "[data-thumbs] [data-go]") == 12
      assert count(doc, "[data-go='0'][aria-current='true']") == 1
      assert count(doc, "[data-go][aria-current='false']") == 11
      assert count(doc, "[data-go='11'][aria-label='Photo 12 of 12']") == 1
      assert texts(doc, "[data-counter]") == ["1 / 12", "1 / 12"]
      assert count(doc, ".pv-stage .pv-badge[data-counter]") == 1
    end

    test "has the full view, with its arrows and zoom, and the details dialog", %{doc: doc} do
      assert count(doc, "dialog[data-lightbox] [data-close]") == 1
      assert count(doc, "dialog[data-lightbox] [data-prev]") == 1
      assert count(doc, "dialog[data-lightbox] [data-next]") == 1
      assert count(doc, "dialog[data-lightbox] [data-zoom]") == 3
      assert count(doc, "dialog[data-lightbox] [data-zoom='fit'][disabled]") == 1
      assert count(doc, "dialog[data-lightbox] [data-view]") == 12
      assert count(doc, "dialog[data-details] [data-close]") == 1
      assert text(doc, "dialog[data-details] h2") == "Photo details"
      assert count(doc, "[data-slide] [data-open]") == 12
    end

    test "has no arrows on the stage", %{doc: doc} do
      assert count(doc, ".pv-stage [data-prev], .pv-stage [data-next]") == 0
    end

    test "ties each stage photo to its caption and credit", %{doc: doc} do
      assert count(doc, "[data-slide='3'] [data-open][aria-describedby='pv-text-3']") == 1
      assert count(doc, "#pv-text-3[data-caption='3']") == 1
    end
  end

  describe "labels" do
    test "names the photos" do
      doc = parse(viewer([photo(1), photo(2, %{alt: "Acorn and cap"})]))

      assert count(doc, "[role=region][aria-label='Photos of Quercus montana']") == 1
      assert count(doc, "[data-slide='0'] img[alt='Photo 1 of Quercus montana']") == 1
      assert count(doc, "[data-slide='1'] img[alt='Acorn and cap']") == 1
      assert count(doc, "[data-slide='1'] [aria-label='Acorn and cap, full size']") == 1
    end

    test "takes the app's words in place of the defaults" do
      labels = %{
        details: "Info",
        photo: "{n}/{count}",
        alt: "{label}, picture {n}",
        row_creator: "Photographer",
        empty: "Nothing here."
      }

      doc = parse(viewer([photo(1), photo(2)], %{labels: labels}))

      assert text(doc, "[data-open-details]") == "Info"
      assert count(doc, "[data-go='1'][aria-label='2/2']") == 1
      assert count(doc, "[data-slide='0'] img[alt='Quercus montana, picture 1']") == 1
      assert "Photographer" in texts(doc, "[data-info='0'] dt")
      assert text(parse(viewer([], %{labels: labels})), ".pv-empty") == "Nothing here."
    end

    test "has a default for every label it uses" do
      assert PhotoViewer.default_labels() |> Map.values() |> Enum.all?(&is_binary/1)
    end
  end

  describe "credit and details" do
    test "credits the creator, the license (linked) and the source" do
      doc = parse(viewer([photo(1)]))
      credit = LazyHTML.query(doc, "[data-caption='0'] .pv-credit")

      assert text(credit, "b") == "janedoe - Jane Doe"
      assert count(credit, "a[href='https://creativecommons.org/licenses/by-nc/4.0/']") == 1

      assert text(credit, "a[href='https://www.inaturalist.org/observations/1']") =~
               "iNaturalist observation"

      refute LazyHTML.text(credit) =~ "©"
      assert texts(doc, "[data-info='0'] dt") == ["Creator", "License", "Source"]
    end

    test "credits the photo in the full view too" do
      doc = parse(viewer([photo(1, %{caption: "Leaf"})]))

      assert text(doc, "[data-full='0'] figcaption .pv-cap") == "Leaf"
      assert text(doc, "[data-full='0'] .pv-credit b") == "janedoe - Jane Doe"
    end

    test "an all-rights-reserved photo marks the creator © and sets the license on its own line" do
      license = "All rights reserved, used with the creator's permission"
      doc = parse(viewer([photo(1, %{license: license, licenselink: nil, reserved: true})]))
      credit = LazyHTML.query(doc, "[data-caption='0'] .pv-credit")

      assert LazyHTML.text(credit) =~ "© janedoe - Jane Doe"
      assert text(credit, "strong.pv-reserved") == license
    end

    test "shows the uploader and attribution in the details when given" do
      doc = parse(viewer([photo(1, %{uploader: "jeff", attribution: "Plate 4", caption: ""})]))

      assert texts(doc, "[data-info='0'] dt") == [
               "Creator",
               "License",
               "Attribution",
               "Source",
               "Uploader"
             ]
    end

    test "a source link without its words reads Source" do
      doc = parse(viewer([photo(1, %{source_label: nil})]))
      assert text(doc, "[data-caption='0'] .pv-credit a[href$='/1']") == "Source"
    end
  end

  describe "the footer" do
    test "has Details and then the actions" do
      assigns = %{}

      doc =
        parse(
          rendered_to_string(~H"""
          <PhotoViewer.photo_viewer id="pv" label="Q" photos={[%{src: "/a.jpg"}]}>
            <:actions><a href="/edit">Edit photos</a></:actions>
          </PhotoViewer.photo_viewer>
          """)
        )

      assert texts(doc, ".pv-foot > *") == ["Details", "Edit photos"]
    end
  end

  describe "the hook" do
    test "pushes no event unless asked to" do
      assert count(parse(viewer([photo(1)])), "[data-event]") == 0
      assert count(parse(viewer([photo(1)], %{on_change: "moved"})), "[data-event='moved']") == 1
    end

    test "gives new photos a new hook element, so the viewer starts again" do
      id = fn photos ->
        parse(viewer(photos)) |> LazyHTML.query("[phx-hook]") |> LazyHTML.attribute("id")
      end

      assert id.([photo(1)]) == id.([photo(1)])
      refute id.([photo(1)]) == id.([photo(1), photo(2)])
    end

    test "leaves its hook and styles out of the markup: they are extracted for the app" do
      html = viewer([photo(1)])

      refute html =~ "<script"
      refute html =~ "<style"
    end
  end
end

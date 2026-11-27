#######################################
# The preview: heartwood_ui's components in a real browser, with no app.
#
# Usage, from ui/:
#
#   $ mix dev              # http://localhost:4300 (PORT to change it)
#
# One page shows each component in every state it has, themed neutral (its
# own defaults) or as Oak Compendium and Gallformers theme it (adapter
# blocks in dev/preview.css), at the widths the apps give it. The browser
# tests run against it. It is the pattern of phoenix_live_dashboard's
# dev.exs: a throwaway endpoint, router and LiveView, run with `mix run`.
#######################################
Logger.configure(level: :info)

port = String.to_integer(System.get_env("PORT") || "4300")

Application.put_env(:phoenix, :json_library, Jason)

Application.put_env(:heartwood_ui, Preview.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Wl1nGx6ae3IvdPaF6rUqv8Q1oSO1v0UVmZ0k5o0e2vO9cXkS2vTz0jzH4HqkXyqo",
  live_view: [signing_salt: "heartwood-preview"],
  http: [ip: {127, 0, 0, 1}, port: port],
  adapter: Bandit.PhoenixAdapter,
  server: true,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  pubsub_server: Preview.PubSub,
  watchers: [esbuild: {Esbuild, :install_and_run, [:preview, ~w(--watch)]}],
  live_reload: [
    patterns: [
      ~r"tmp/preview/assets/.*(js|css)$",
      ~r"lib/heartwood/ui/.*ex$",
      ~r"dev/.*(exs|css)$"
    ]
  ]
)

defmodule Preview.Photos do
  @moduledoc false
  # Oak Compendium's photos of Quercus montana, at their own CloudFront
  # URLs, with their real credits (all Jeff Clark's own, CC BY). They have
  # no captions; the captions and the all-rights-reserved credit below are
  # made up for the preview, and the page says so.

  @cdn "https://images.oakcompendium.org/species/332/332_"
  @files ~w(
    1795642176297_5e524b6be1.jpg 1795642098362_75ef6f6c99.jpeg
    1795642098364_e522275aea.jpeg 1795642098366_f313467fa4.jpeg
    1795642098368_c5a6dbf38e.jpeg 1795642134328_60c2388d6d.jpeg
    1795642134330_b7f7e6098e.jpeg 1795642226814_d1814aecee.jpg
    1795642226816_dd2a512ad3.jpg 1795642226818_54a3d9eb4c.jpg
    1795642226820_2e93cef42c.jpg
  )
  @observations [
    312_083_610,
    88_121_227,
    88_121_227,
    88_121_227,
    88_121_227,
    103_065_180,
    103_065_180,
    414_033_591,
    414_033_591,
    414_033_591,
    414_033_591
  ]

  def montana do
    if System.get_env("PREVIEW_PHOTOS") == "local", do: local(), else: cdn()
  end

  defp cdn do
    @files
    |> Enum.zip(@observations)
    |> Enum.map(fn {file, observation} ->
      [stem, ext] = String.split(file, ".")

      %{
        src: "#{@cdn}#{stem}_medium.#{ext}",
        thumb: "#{@cdn}#{stem}_small.#{ext}",
        full: "#{@cdn}#{stem}_large.#{ext}",
        creator: "jeffdc - Jeff Clark",
        license: "CC-BY",
        licenselink: "https://creativecommons.org/licenses/by/4.0/",
        sourcelink: "https://www.inaturalist.org/observations/#{observation}",
        source_label: "iNaturalist observation"
      }
    end)
  end

  # Generated photos for the browser tests, so they need no network: SVGs
  # of known sizes, landscape and portrait in turn, numbered and ruled so a
  # zoom shows, written under tmp/preview/assets/photos when the preview
  # starts. Their credits are made up.
  @local_dir Path.expand("tmp/preview/assets/photos", __DIR__)
  @sizes [small: 240, medium: 800, large: 2000]

  def write_local do
    File.mkdir_p!(@local_dir)

    for n <- 1..11, {size, long} <- @sizes do
      {w, h} = if rem(n, 2) == 1, do: {long, div(long * 3, 4)}, else: {div(long * 3, 4), long}
      hue = rem(n * 47, 360)

      svg = """
      <svg xmlns="http://www.w3.org/2000/svg" width="#{w}" height="#{h}" viewBox="0 0 #{w} #{h}">
      <defs><pattern id="g" width="#{div(w, 10)}" height="#{div(w, 10)}" patternUnits="userSpaceOnUse">
      <path d="M #{div(w, 10)} 0 L 0 0 0 #{div(w, 10)}" fill="none" stroke="#fff" stroke-opacity="0.35"/></pattern></defs>
      <rect width="100%" height="100%" fill="hsl(#{hue} 35% 40%)"/><rect width="100%" height="100%" fill="url(#g)"/>
      <text x="50%" y="55%" font-family="sans-serif" font-size="#{div(min(w, h), 3)}" fill="#fff" text-anchor="middle">#{n}</text>
      </svg>
      """

      File.write!(Path.join(@local_dir, "#{n}_#{size}.svg"), svg)
    end
  end

  defp local do
    for n <- 1..11 do
      %{
        src: "/assets/photos/#{n}_medium.svg",
        thumb: "/assets/photos/#{n}_small.svg",
        full: "/assets/photos/#{n}_large.svg",
        creator: "Test photo #{n}",
        license: "CC0",
        sourcelink: "#source-#{n}",
        source_label: "Source"
      }
    end
  end

  def many, do: montana() |> Stream.cycle() |> Enum.take(24)

  @captions [
    "Bark of a mature trunk: deep, blocky ridges, darker in the furrows.",
    "Leaf, upper surface: the margin cut into rounded, regular teeth, ten to fourteen to a side, each tooth with a small gland at its tip; the blade widest above the middle and tapering to a wedge-shaped base, the petiole about a sixth of the blade's length.",
    nil,
    "Acorns."
  ]

  def captioned do
    montana()
    |> Enum.take(4)
    |> Enum.zip(@captions)
    |> Enum.map(fn {photo, caption} -> Map.put(photo, :caption, caption) end)
    |> List.update_at(3, fn photo ->
      Map.merge(photo, %{
        reserved: true,
        license: "All rights reserved, used with the creator's permission",
        licenselink: nil,
        attribution: "Made-up example of an all-rights-reserved photo"
      })
    end)
  end
end

defmodule Preview.Layout do
  @moduledoc false
  use Phoenix.Component

  def render("root.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()} />
        <title>heartwood_ui preview</title>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Archivo:wght@500;600;700&family=League+Spartan:wght@600;700&family=Source+Sans+3:ital,wght@0,400;0,600;1,400&family=Source+Serif+4:ital,wght@0,400;0,600;1,400&display=swap"
        />
        <link rel="stylesheet" href="/assets/app.css" />
        <script defer src="/assets/app.js">
        </script>
      </head>
      <body>
        {@inner_content}
      </body>
    </html>
    """
  end
end

defmodule Preview.Live do
  @moduledoc false
  use Phoenix.LiveView

  import Heartwood.UI.PhotoViewer, only: [photo_viewer: 1]

  @themes [
    {"Neutral (the component's own defaults)", "neutral"},
    {"Oak Compendium", "oaks"},
    {"Gallformers, light", "gf"},
    {"Gallformers, dark", "gf-dark"}
  ]
  @widths [{"240px", "240"}, {"300px", "300"}, {"420px", "420"}, {"Full width", "full"}]

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       moves: [],
       themes: @themes,
       widths: @widths,
       montana: Preview.Photos.montana(),
       many: Preview.Photos.many(),
       captioned: Preview.Photos.captioned()
     )}
  end

  # The theme and width are in the URL, so a browser test can choose them.
  def handle_params(params, _uri, socket) do
    {:noreply,
     assign(socket,
       theme: pick(params["theme"], @themes, "oaks"),
       width: pick(params["width"], @widths, "300")
     )}
  end

  def handle_event("set", params, socket) do
    {:noreply,
     push_patch(socket, to: "/?" <> URI.encode_query(Map.take(params, ~w(theme width))))}
  end

  def handle_event("moved", %{"index" => i}, socket) do
    {:noreply, update(socket, :moves, &Enum.take(["moved to #{i + 1}" | &1], 5))}
  end

  def render(assigns) do
    assigns =
      assign(assigns,
        class: adapter(assigns.theme),
        style: if(assigns.width == "full", do: nil, else: "width: #{assigns.width}px")
      )

    ~H"""
    <main class={["page", "page-#{@theme}"]}>
      <header class="bar">
        <h1>heartwood_ui preview</h1>
        <form phx-change="set">
          <label>
            Theme
            <select name="theme">
              {Phoenix.HTML.Form.options_for_select(@themes, @theme)}
            </select>
          </label>
          <label>
            Width
            <select name="width">
              {Phoenix.HTML.Form.options_for_select(@widths, @width)}
            </select>
          </label>
        </form>
        <p class="note">
          Photos: Oak Compendium's Quercus montana, with their real credits. Captions and the all-rights-reserved credit are made up for the preview.
        </p>
      </header>

      <section>
        <h2>Eleven photos</h2>
        <div class="slot" style={@style}>
          <.photo_viewer id="montana" label="Quercus montana" photos={@montana} class={@class} />
        </div>
      </section>

      <section>
        <h2>Twenty-four photos, with actions and on_change</h2>
        <div class="slot" style={@style}>
          <.photo_viewer
            id="many"
            label="Quercus montana"
            photos={@many}
            class={@class}
            on_change="moved"
          >
            <:actions><a href="#many">Edit photos</a></:actions>
          </.photo_viewer>
        </div>
        <ol class="log" aria-label="on_change events">
          <li :for={move <- @moves}>{move}</li>
        </ol>
      </section>

      <section>
        <h2>Captions and an all-rights-reserved credit (made up)</h2>
        <div class="slot" style={@style}>
          <.photo_viewer id="captioned" label="Quercus montana" photos={@captioned} class={@class} />
        </div>
      </section>

      <section>
        <h2>One photo</h2>
        <div class="slot" style={@style}>
          <.photo_viewer
            id="one"
            label="Quercus montana"
            photos={Enum.take(@montana, 1)}
            class={@class}
          />
        </div>
      </section>

      <section>
        <h2>No photos</h2>
        <div class="slot" style={@style}>
          <.photo_viewer id="none" label="Quercus montana" photos={[]} class={@class} />
        </div>
        <div class="slot" style={@style}>
          <.photo_viewer id="none-actions" label="Quercus montana" photos={[]} class={@class}>
            <:actions><a href="#none-actions">Add images</a></:actions>
          </.photo_viewer>
        </div>
      </section>
    </main>
    """
  end

  defp pick(value, options, default) do
    if Enum.any?(options, fn {_label, v} -> v == value end), do: value, else: default
  end

  defp adapter("oaks"), do: "oc-photos"
  defp adapter("gf"), do: "gf-photos"
  defp adapter("gf-dark"), do: "gf-photos"
  defp adapter(_neutral), do: nil
end

defmodule Preview.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_root_layout, html: {Preview.Layout, :root}
  end

  scope "/" do
    pipe_through :browser
    live "/", Preview.Live
  end
end

defmodule Preview.Endpoint do
  use Phoenix.Endpoint, otp_app: :heartwood_ui

  @session_options [store: :cookie, key: "_preview_key", signing_salt: "heartwood-preview"]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]
  socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket

  plug Plug.Static, at: "/assets", from: Path.expand("tmp/preview/assets", __DIR__), gzip: false
  plug Phoenix.LiveReloader
  plug Phoenix.CodeReloader
  plug Plug.Session, @session_options
  plug Preview.Router
end

if System.get_env("PREVIEW_PHOTOS") == "local", do: Preview.Photos.write_local()

Application.put_env(:phoenix, :serve_endpoints, true)

# The supervisor stops when the process that started it ends, so this one
# never does.
Task.async(fn ->
  {:ok, _} =
    Supervisor.start_link([{Phoenix.PubSub, name: Preview.PubSub}, Preview.Endpoint],
      strategy: :one_for_one
    )

  IO.puts("heartwood_ui preview: http://localhost:#{port}")
  Process.sleep(:infinity)
end)
|> Task.await(:infinity)

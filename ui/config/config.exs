import Config

# The preview's bundle (dev.exs): esbuild reads this when it starts. The
# package itself has no configuration.
if config_env() == :dev do
  config :esbuild,
    version: "0.25.4",
    preview: [
      args: ~w(dev/app.js --bundle --target=es2022 --outdir=tmp/preview/assets),
      cd: Path.expand("..", __DIR__),
      env: %{"NODE_PATH" => Enum.join([Path.expand("../deps", __DIR__), Mix.Project.build_path()], ":")}
    ]
end

defmodule Heartwood.Guardrails.CheckToolchainTest do
  @moduledoc """
  `bin/check-toolchain` against app roots built in a temporary directory,
  with the versions of the Elixir and OTP running these tests (the dev
  shell's) and a stand-in `typst` on PATH.
  """
  use ExUnit.Case, async: true

  alias Heartwood.Test.GitRepo

  @moduletag :tmp_dir

  @script Path.expand("../../../bin/check-toolchain", __DIR__)

  defp otp_version do
    [:code.root_dir(), "releases", :erlang.system_info(:otp_release), "OTP_VERSION"]
    |> Path.join()
    |> File.read!()
    |> String.trim()
  end

  defp dockerfile(opts \\ []) do
    elixir = Keyword.get(opts, :elixir, System.version())
    tailwind = Keyword.get(opts, :tailwind, "4.1.12")

    """
    FROM hexpm/elixir:#{elixir}-erlang-#{otp_version()}-alpine-3.24.3 AS builder
    #{if path = opts[:tailwind_path], do: "ENV MIX_TAILWIND_PATH=/usr/local/bin/tailwindcss-#{path}"}
    ADD https://github.com/tailwindlabs/tailwindcss/releases/download/v#{tailwind}/tailwindcss-linux-x64-musl /tmp/tw
    #{if typst = opts[:typst], do: "ADD https://github.com/typst/typst/releases/download/v#{typst}/typst.tar.xz /tmp/t"}
    FROM alpine:3.24.3 AS runtime
    """
  end

  # An app root with config.exs and flake.nix at Tailwind 4.1.12, and the
  # given Dockerfiles; `typst` is the version the stand-in on PATH reports.
  defp run(dir, files, opts \\ []) do
    flake =
      ~s|  tailwindVersion = "4.1.12";\n| <>
        if(opts[:flake_typst], do: "  packages = [ pkgs.typst ];\n", else: "")

    all =
      Map.merge(
        %{
          "config/config.exs" =>
            ~s|config :esbuild, version: "0.25.0"\nconfig :tailwind,\n  version: "4.1.12",\n|,
          "flake.nix" => flake
        },
        files
      )

    for {path, contents} <- all, do: GitRepo.write!(dir, path, contents)

    bin = Path.join(dir, "bin")
    GitRepo.write!(dir, "bin/typst", "#!/bin/sh\necho 'typst #{opts[:typst] || "0.15.1"}'\n")
    File.chmod!(Path.join(bin, "typst"), 0o755)

    System.cmd(@script, [],
      env: [{"CHECK_TOOLCHAIN_ROOT", dir}, {"PATH", bin <> ":" <> System.get_env("PATH")}],
      stderr_to_stdout: true
    )
  end

  test "matching Dockerfiles pass", %{tmp_dir: dir} do
    assert {out, 0} = run(dir, %{"Dockerfile" => dockerfile()})
    assert out =~ "ok        Dockerfile Elixir: #{System.version()}"
    assert out =~ "Dockerfiles match the dev toolchain."
  end

  test "every Dockerfile.* is checked too", %{tmp_dir: dir} do
    files = %{"Dockerfile" => dockerfile(), "Dockerfile.preview" => dockerfile(elixir: "1.18.0")}

    assert {out, 1} = run(dir, files)

    assert out =~
             "MISMATCH: Dockerfile.preview Elixir: expected #{System.version()}, found 1.18.0"
  end

  test "a Tailwind download that differs from config.exs fails", %{tmp_dir: dir} do
    assert {out, 1} = run(dir, %{"Dockerfile" => dockerfile(tailwind: "4.0.0")})
    assert out =~ "MISMATCH: Dockerfile Tailwind (= config.exs): expected 4.1.12, found 4.0.0"
  end

  test "MIX_TAILWIND_PATH is checked when the Dockerfile sets it", %{tmp_dir: dir} do
    assert {out, 0} = run(dir, %{"Dockerfile" => dockerfile(tailwind_path: "4.1.12")})
    assert out =~ "ok        Dockerfile MIX_TAILWIND_PATH (= config.exs): 4.1.12"

    assert {out, 1} = run(dir, %{"Dockerfile" => dockerfile(tailwind_path: "4.0.0")})
    assert out =~ "MISMATCH: Dockerfile MIX_TAILWIND_PATH"
  end

  test "MIX_TAILWIND_PATH isn't required", %{tmp_dir: dir} do
    assert {out, 0} = run(dir, %{"Dockerfile" => dockerfile()})
    refute out =~ "MIX_TAILWIND_PATH"
  end

  test "Typst is checked when flake.nix provides it", %{tmp_dir: dir} do
    files = %{"Dockerfile" => dockerfile(typst: "0.15.1")}
    assert {out, 0} = run(dir, files, flake_typst: true)
    assert out =~ "ok        Dockerfile Typst: 0.15.1"

    assert {out, 1} = run(dir, files, flake_typst: true, typst: "0.16.0")
    assert out =~ "MISMATCH: Dockerfile Typst: expected 0.16.0, found 0.15.1"
  end

  test "a Typst on PATH that flake.nix doesn't provide is ignored", %{tmp_dir: dir} do
    assert {out, 0} = run(dir, %{"Dockerfile" => dockerfile()}, typst: "0.14.2")
    refute out =~ "Typst"
  end

  test "flake.nix's Tailwind must match config.exs", %{tmp_dir: dir} do
    files = %{"Dockerfile" => dockerfile(), "flake.nix" => ~s|  tailwindVersion = "4.0.0";\n|}

    assert {out, 1} = run(dir, files)
    assert out =~ "MISMATCH: flake.nix Tailwind (= config.exs): expected 4.1.12, found 4.0.0"
  end

  test "no Dockerfile fails", %{tmp_dir: dir} do
    assert {out, 1} = run(dir, %{})
    assert out =~ "MISMATCH: no Dockerfile in"
  end
end

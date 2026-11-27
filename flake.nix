{
  description = "Heartwood development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      # aarch64-darwin: development Macs. x86_64-linux: GitHub Actions runners.
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (
        pkgs:
        let
          # The same Elixir and OTP as Oak Compendium and Gallformers.
          beam = pkgs.beam.packages.erlang_28;
        in
        {
          default = pkgs.mkShell {
            packages = [
              # On macOS the shell sets DEVELOPER_DIR to Nix's Apple SDK, which breaks
              # /usr/bin/git (an xcrun stub: "tool 'git' not found"). A real git fixes it.
              pkgs.git
              beam.erlang
              beam.elixir_1_19
            ];
          };
        }
      );
    };
}

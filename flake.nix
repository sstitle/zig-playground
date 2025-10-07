{
  description = "Zig playground";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs@{ self, flake-parts, nixpkgs, nixpkgs-unstable, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        let
          treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
          unstable = import inputs.nixpkgs-unstable { inherit system; };
        in
        {
          # Development shell with nickel and mask
          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              # Core tools
              git
              nickel
              mask

              # Zig tools
              # unstable.zig_0_14
              # unstable.zls

              # Qt 6 development dependencies
              qt6.qtbase
              qt6.qttools
              qt6.qtdeclarative
            ];

            shellHook = ''
              echo "🚀 Development environment loaded!"
              echo "Available tools:"
              echo "  - nickel: Configuration language"
              echo "  - mask: Task runner"
              echo ""
              echo "Run 'mask --help' to see available tasks."
              echo "Run 'nix fmt' to format all files."
            '';
          };

          # for `nix fmt`
          formatter = treefmtEval.config.build.wrapper;

          # for `nix flake check`
          checks = {
            formatting = treefmtEval.config.build.check self;
          };
        };
    };
}

{
  description = "Container images for Freenet (freenet.org), built from official release binaries";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          # Task runner: every routine command lives in the Justfile.
          just

          # Every gate the CI workflow runs, so it can be reproduced locally.
          hadolint
          actionlint
          shellcheck
          act

          # Used by the release-checking scripts and by hand when bumping the
          # pinned version.
          curl
          jq
          gnutar
        ];

        shellHook = ''
          echo "freenet-docker dev shell - run 'just' for the task list"
        '';
      };
    });
}

{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    foundry.url = "github:shazow/foundry.nix/monthly";
    foundry.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = inputs@{ nixpkgs, rust-overlay, foundry, ... }:
    inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default foundry.overlay ];
        };
      in
      {
        devShells = import ./shells { inherit pkgs; };
      }
    );
}

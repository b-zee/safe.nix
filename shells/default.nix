{ pkgs }:


let
  # Needed for rust-analyzer
  extensions = [ "rust-src" ];

  # Packages used as a base for Rust shells
  buildRust = opt: pkgs.rust-bin.stable."1.81.0".default.override ({ inherit extensions; } // opt);
  buildRustNightly = opt: pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default.override (opt // { inherit extensions; }));

  # Default stable Rust package
  # rustPkg = buildRust { targets = [ "x86_64-unknown-linux-gnu" "x86_64-unknown-linux-musl" ]; };
  rustPkg = buildRust { };

  safeShell = import ./safe.nix;
in
{
  safe = safeShell { inherit pkgs rustPkg; };
  safe-extra = safeShell { inherit pkgs rustPkg; enableExtra = true;};
  safe-wasm = safeShell { inherit pkgs; enableWasm = true; rustPkg = buildRust { targets = [ "wasm32-unknown-unknown" "wasm32-wasi" ]; }; };
  safe-musl = safeShell { inherit pkgs; enableMusl = true; rustPkg = buildRust { targets = [ "x86_64-unknown-linux-musl" ]; }; };
  safe-nightly = safeShell { inherit pkgs; rustPkg = buildRustNightly { }; };
}

{ pkgs
, rustPkg
, enableMusl ? false
, enableWasm ? false
  # 'mold' is a faster linker for Linux (Darwin 'sold' should work but has issue with YAML https://github.com/bluewhalesystems/sold/pull/15#issuecomment-1670641312)
, enableMold ? !enableMusl && !enableWasm && pkgs.stdenv.hostPlatform.isLinux
, enableExtra ? false
, enableSccache ? true
, enableProtobuf ? true
, enableOpenssl ? false
, enableFoundry ? true
}:

let
  inherit (pkgs.lib) optionals optionalAttrs getBin;
  # Copied from https://github.com/oxalica/rust-overlay/issues/70#issuecomment-1140319456
  # Prevent package dependencies from appearing in $PATH. (E.g. clang 16 from the Rust overlay)
  mkBinOnlyWrapper = pkg:
    pkgs.runCommand "${pkg.pname}-${pkg.version}-bin" { inherit (pkg) meta; } ''
      mkdir -p "$out/bin"
      for bin in "${getBin pkg}/bin/"*; do
          ln -s "$bin" "$out/bin/"
      done
    '';
  stdenv =
    if pkgs.stdenv.targetPlatform.system == "x86_64-linux"
    # Using `clangMultiStdenv` solves a weird `wasm-pack build` issue, where a dependency looks for a stub-32.h file. Supported only on `x86_64-linux`.
    then pkgs.clangMultiStdenv
    else pkgs.llvmPackages_17.stdenv;
in
pkgs.mkShell.override { inherit stdenv; }
  ({
    packages = [
      # Fixes weird shell errors when using VSCode built-in terminal
      pkgs.bashInteractive

      # Rust toolchain and cargo
      (mkBinOnlyWrapper rustPkg)
    ] ++ [
      # pkgs.llvmPackages_17.lld
    ]
    ++ optionals stdenv.hostPlatform.isDarwin (with pkgs; [ libiconv darwin.apple_sdk.frameworks.SystemConfiguration ])
    ++ optionals enableMusl [ pkgs.musl.dev ]
    # Use LLVM/Clang for building WASM
    ++ optionals enableWasm (with pkgs; [ wasm-pack wasm-bindgen-cli ])
    ++ optionals enableExtra (with pkgs; [ parallel terraform ansible jq cargo-edit ])
    ++ optionals enableOpenssl (with pkgs; [ pkg-config openssl.dev openssl.out ])
    ++ optionals enableFoundry (with pkgs; [ foundry-bin ])
    ;

    CARGO_ALIAS_C = "clippy --all-targets --all-features";

    # CARGO_TARGET_WASM32_UNKNOWN_UNKNOWN_LINKER = "wasm-ld";
    # CC = "clang";
    CC_wasm32_unknown_unknown = "${pkgs.llvmPackages_17.clang-unwrapped}/bin/clang-17";
    CFLAGS_wasm32_unknown_unknown = "-I ${pkgs.llvmPackages_17.libclang.lib}/lib/clang/17/include/";

    RUSTFLAGS = builtins.concatStringsSep " " (
      [
        # Debug information is slow to generate and makes the binary larger
        "-C strip=debuginfo"
        "-C debuginfo=0"
      ]
      ++ (if enableMold then [
      "-C link-arg=--ld-path=${pkgs.mold}/bin/mold"

      # Should generate more optimal machine code (x86_64 only)
      "-C target-cpu=native"
      ] else if (!enableWasm && !enableMusl) then [ "-C link-arg=--ld-path=${pkgs.llvmPackages_17.lld}/bin/ld.lld" ] else [ ])
    );

  }

  // optionalAttrs stdenv.hostPlatform.isDarwin {
    "LIBRARY_PATH" = "${pkgs.libiconv}/lib";
  }

  # Use sccache for faster builds
  // optionalAttrs enableSccache {
    RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
    SCCACHE_CACHE_SIZE = "30G";
  }

  # Use sccache for faster builds
  // optionalAttrs enableOpenssl {
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
    LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.openssl ];
  }

    // optionalAttrs enableProtobuf { PROTOC = "${pkgs.protobuf}/bin/protoc"; }
  )

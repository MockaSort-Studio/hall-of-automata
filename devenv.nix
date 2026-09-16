{ pkgs, lib, config, inputs, ... }:

let
  # Version shared with docker/Dockerfile — both must track the same pair.
  # Update docker/chrome-version to change both simultaneously.
  chromeVersion = lib.fileContents ./docker/chrome-version;

  # Per-system metadata for Chrome for Testing downloads.
  # Chrome and chromedriver are published at the same version; hashes are for
  # the zip files (pkgs.fetchurl SHA-256 in SRI format).
  chromeSrcs = {
    "x86_64-linux" = {
      platform = "linux64";
      chrome = {
        zipName = "chrome-linux64";
        hash = "sha256-FnoJjE/ewVa1ip9njJCoT5By14n5xuezVJammHuLfvg=";
      };
      chromedriver = {
        zipName = "chromedriver-linux64";
        hash = "sha256-wF87+1AbN7Erf6KlS4swtR0ImmQ4mJg2KusnhfEqyD8=";
      };
    };
    "aarch64-linux" = {
      platform = "linux-arm64";
      chrome = {
        zipName = "chrome-linux-arm64";
        hash = "sha256-38SVVxnF1JTIUHmQUG0tW+0XTDG/iSZqotxVk8Zgfos=";
      };
      chromedriver = {
        zipName = "chromedriver-linux-arm64";
        hash = "sha256-6bM4GcGUtPCcPSUfmqPYUu28uPUFrHkIFWffdwg/bdI=";
      };
    };
    "aarch64-darwin" = {
      platform = "mac-arm64";
      chrome = {
        zipName = "chrome-mac-arm64";
        hash = "sha256-H3Ae9gdXxjxsz5ivrygpHdDI0UV9PXOOgf1iIBwjCtA=";
      };
      chromedriver = {
        zipName = "chromedriver-mac-arm64";
        hash = "sha256-BRNZj7iBK/QlMzG3QjwkBfAa0WlH6hZOQW2D8RSC9I4=";
      };
    };
    "x86_64-darwin" = {
      platform = "mac-x64";
      chrome = {
        zipName = "chrome-mac-x64";
        hash = "sha256-zd/YP634iAj7A29EKCSIsc8/G1DvrM5HAiWuQfFLAwI=";
      };
      chromedriver = {
        zipName = "chromedriver-mac-x64";
        hash = "sha256-8YGvy5toOOzivm8ph3XUUXPAc7wC7y8w61tbrfN0CRg=";
      };
    };
  };

  currentSystem = pkgs.stdenv.hostPlatform.system;

  # Chrome for Testing browser. Installs the full extracted directory so the
  # chrome binary's $ORIGIN-relative RPATH resolves its bundled shared libs.
  # Exposed on PATH as `chrome-for-testing`; Wallaby should be configured with
  # `binary: System.get_env("CHROME_BINARY")` in config/test.exs rather than
  # relying on a misleading `google-chrome` shim.
  chromeForTesting =
    let
      info = chromeSrcs.${currentSystem};
      chromeBin =
        if pkgs.stdenv.isDarwin
        then "Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing"
        else "chrome";
    in
    pkgs.stdenv.mkDerivation {
      pname = "chrome-for-testing";
      version = chromeVersion;
      src = pkgs.fetchurl {
        url = "https://storage.googleapis.com/chrome-for-testing-public/${chromeVersion}/${info.platform}/${info.chrome.zipName}.zip";
        hash = info.chrome.hash;
      };
      nativeBuildInputs = [ pkgs.unzip pkgs.makeWrapper ];
      dontUnpack = true;
      installPhase = ''
        mkdir -p "$out/share" "$out/bin"
        unzip "$src" -d "$out/share"
        makeWrapper "$out/share/${info.chrome.zipName}/${chromeBin}" \
          "$out/bin/chrome-for-testing"
      '';
    };

  # chromedriver from Chrome for Testing — same version as chromeForTesting.
  chromedriverForTesting =
    let
      info = chromeSrcs.${currentSystem};
    in
    pkgs.stdenv.mkDerivation {
      pname = "chromedriver-for-testing";
      version = chromeVersion;
      src = pkgs.fetchurl {
        url = "https://storage.googleapis.com/chrome-for-testing-public/${chromeVersion}/${info.platform}/${info.chromedriver.zipName}.zip";
        hash = info.chromedriver.hash;
      };
      nativeBuildInputs = [ pkgs.unzip ];
      dontUnpack = true;
      installPhase = ''
        unzip "$src" -d "$TMPDIR/extract"
        mkdir -p "$out/bin"
        mv "$TMPDIR/extract/${info.chromedriver.zipName}/chromedriver" "$out/bin/"
        chmod +x "$out/bin/chromedriver"
      '';
    };

  # Fixed-output derivation containing all Mix dependencies for the production
  # release build. The hash must be computed once and committed:
  #
  #   devenv container build livedata --copy
  #
  # The first run fails with a hash mismatch; copy the "got:" value from the
  # error and replace lib.fakeHash below, then rebuild.
  #
  mixFodDeps = pkgs.beamPackages.fetchMixDeps {
    pname = "livedata-mix-deps";
    version = "0.1.0";
    src = ./livedata;
    hash = "sha256-MKCy8vBexCAJUHvA8mPMPQqnh0BFAH5nm7F0XNpuayo=";
  };

  # Tailwind v4.1.12 standalone CLI for Linux x86_64.
  # pkgs.tailwindcss in the pinned nixpkgs resolves to v3, which is
  # incompatible with the v4 CLI syntax and config in livedata/assets/css/app.css.
  # Tailwind publishes prebuilt executables on GitHub releases; fetch directly.
  # The binary is dynamically linked against glibc/libstdc++ and expects the
  # standard FHS dynamic linker path, which doesn't exist in the Nix sandbox —
  # autoPatchelfHook rewrites its interpreter/rpath to Nix store paths.
  tailwindcssV4 = pkgs.stdenv.mkDerivation {
    pname = "tailwindcss-v4-cli";
    version = "4.1.12";
    src = pkgs.fetchurl {
      url = "https://github.com/tailwindlabs/tailwindcss/releases/download/v4.1.12/tailwindcss-linux-x64";
      hash = "sha256-Xu7mbqI36umhYPozFP0M92q5k1Uamfr7Fvodtsa5Aok=";
    };
    dontUnpack = true;
    # This binary is a Bun-compiled standalone executable — Bun embeds the
    # packaged app as a section appended to the ELF, and uses its presence to
    # decide whether to run the embedded app or fall back to bare `bun`'s own
    # CLI. stdenv's default fixup phase strips the binary, which corrupts
    # that section: the binary silently starts behaving as plain `bun`
    # (prints its own help and exits 0 on unrecognized args) instead of
    # running Tailwind, with no build failure to signal it.
    dontStrip = true;
    nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/.tailwindcss-unwrapped
      chmod +x $out/bin/.tailwindcss-unwrapped
    '';
    # autoPatchelfHook only fixes the RPATH of files Nix can see at build
    # time. Tailwind's CLI bundles a native addon (@parcel/watcher, a .node
    # file) inside the Bun-packaged binary and extracts it to a runtime temp
    # path when it actually runs — that extracted file never existed at
    # build time, so no amount of patchelf'ing the main binary reaches it.
    # It needs libstdc++ found via the dynamic linker's runtime search path
    # instead, which LD_LIBRARY_PATH provides regardless of RPATH.
    postFixup = ''
      makeWrapper $out/bin/.tailwindcss-unwrapped $out/bin/tailwindcss \
        --prefix LD_LIBRARY_PATH : ${pkgs.stdenv.cc.cc.lib}/lib
    '';
  };

  # Production Mix release.
  # Assets are compiled using nixpkgs-provided esbuild and the Tailwind v4
  # standalone binary (tailwindcssV4 above) instead of the Mix-managed
  # binaries, which download at runtime and are unavailable in the Nix sandbox.
  #
  livedataRelease = pkgs.beamPackages.mixRelease {
    pname = "livedata";
    version = "0.1.0";
    src = ./livedata;
    inherit mixFodDeps;
    nativeBuildInputs = [ pkgs.nodejs pkgs.git ];

    # mixRelease strips releases/COOKIE by default (removeCookie = true), but
    # the generated bin/livedata boot script falls back to `cat`-ing that
    # exact file when RELEASE_COOKIE isn't set in the environment — with it
    # gone, every boot attempt crash-loops. This app runs single-node with no
    # Erlang clustering, so there's no security reason to strip the
    # auto-generated cookie; keeping it restores Mix's normal release
    # behavior with no extra deploy-time secret to wire up.
    removeCookie = false;

    # Run after `mix compile`, before `mix release` (installPhase).
    # deps/ is available (symlinked from mixFodDeps by configurePhase).
    # _build/prod/ is also present — phoenix-colocated/livedata is compiled
    # there by `mix compile` and must be on NODE_PATH for the esbuild bundle.
    postBuild = ''
      NODE_PATH="$PWD/deps:$PWD/_build/prod" \
        ${pkgs.esbuild}/bin/esbuild assets/js/app.js \
          --bundle --target=es2022 \
          --outdir=priv/static/assets/js \
          --external:/fonts/* --external:/images/* \
          --alias:@=. \
          --define:process.env.NODE_ENV=\"production\"

      ${tailwindcssV4}/bin/tailwindcss \
        --input=assets/css/app.css \
        --output=priv/static/assets/css/app.css \
        --minify

      # tailwindcss exits 0 even when it silently degrades into printing
      # bare `bun`'s own help text instead of running (see tailwindcssV4's
      # dontStrip comment above) — assert real output exists so that class
      # of failure breaks the build instead of shipping unstyled.
      test -s priv/static/assets/css/app.css
    '';
  };
in
lib.mkMerge [
  {
    # Environment variables set in both the dev shell and the built container.
    env.LANG = "en_US.UTF-8";
    env.LC_ALL = "en_US.UTF-8";

    # Production OCI image, built via `devenv container build livedata`.
    # Contains only the compiled Mix release and its Nix-tracked runtime
    # dependencies — not the Elixir/Erlang toolchain or dev shell.
    #
    # Build:  devenv container build livedata --copy
    # Load:   docker load < result
    # Start:  see deploy/README.md
    #
    containers.livedata = {
      name = "livedata";

      copyToRoot = pkgs.buildEnv {
        name = "livedata-root";
        paths = [
          livedataRelease
          pkgs.cacert   # CA bundle for TLS verify-peer (Repo ssl: true on Neon)
          pkgs.bash     # /bin/sh for release overlay scripts
          pkgs.coreutils
        ];
        pathsToLink = [ "/" ];
      };

      # Points directly at the release derivation's own store path rather than
      # the buildEnv-merged /bin/start — the merge produced no resolvable file
      # at the container-root path (stat failed at container start), while
      # ${livedataRelease}/bin/start is guaranteed to exist: Mix always copies
      # rel/overlays/ into the release root, and postFixup's wrapProgram
      # preserves the "start" name (renames the original to .start-wrapped).
      entrypoint = [ "${livedataRelease}/bin/start" ];
    };

    # https://devenv.sh/basics/
    enterShell = ''
      mix local.hex --force --if-missing
      mix local.rebar --force --if-missing
      git config core.hooksPath .githooks
    '';
  }

  # Dev-shell tools — excluded from container builds so they don't bloat the
  # OCI image closure. config.container.isBuilding is false for normal
  # `devenv shell`/`devenv up`, so all of these remain available interactively.
  (lib.mkIf (!config.container.isBuilding) {
    # CHROME_BINARY points Wallaby's `binary:` option at the Chrome for Testing
    # browser without requiring a misleading `google-chrome` PATH shim.
    # Set `config :wallaby, chrome: [binary: System.get_env("CHROME_BINARY")]`
    # in config/test.exs.
    env.CHROME_BINARY = "${chromeForTesting}/bin/chrome-for-testing";

    # https://devenv.sh/languages/
    languages.elixir.enable = true;
    languages.erlang.enable = true;
    languages.javascript = {
      enable = true;
      npm.enable = true;
    };

    # https://devenv.sh/packages/
    packages = [
      pkgs.git
      pkgs.terraform
      pkgs.tflint

      # Chrome for Testing — both browser and chromedriver from the same pinned
      # version (see docker/chrome-version). Available on Linux and macOS.
      chromeForTesting
      chromedriverForTesting
    ];

    # https://devenv.sh/services/
    # Vanilla PostgreSQL. devenv runs it on a Unix socket and exports
    # PGHOST (socket dir) / PGDATA. Phoenix connects via socket_dir
    # (see livedata/config/dev.exs and livedata/config/test.exs) — no
    # TCP/password needed.
    # Port 5433 avoids clashing with a system PostgreSQL on the default 5432.
    # devenv exports PGPORT; Phoenix reads it (see the livedata/config files).
    # Databases (livedata_dev / livedata_test) are created by `mix ecto.create`,
    # which is run from inside the livedata/ app directory.
    services.postgres = {
      enable = true;
      port = 5433;
      extensions = extensions: [
        extensions.postgis
        extensions.timescaledb
      ];
      settings = {
        shared_preload_libraries = "timescaledb";
      };
    };
  })
]

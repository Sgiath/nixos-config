{
  config,
  lib,
  pkgs,
  ...
}:
let
  factorio = pkgs.factorio-space-age-experimental.overrideAttrs (old: {
    src = pkgs.requireFile {
      name = old.src.name;
      sha256 = old.src.outputHash;
      message = ''
        Download Factorio Space Age ${old.version} for Linux from:
          https://factorio.com/get-download/${old.version}/expansion/linux64
        Then import the archive without account credentials:
          nix-prefetch-url --type sha256 --name ${old.src.name} file://$HOME/Downloads/factorio-space-age_linux_${old.version}.tar.xz
        Once installed, fetch-factorio-archive can download using the runtime SOPS token.
      '';
    };
  });
in
{
  config = lib.mkIf config.sgiath.roles.gaming.enable {
    # Keep the paid source available across dependency rebuilds and garbage collection.
    home.extraDependencies = [ factorio.src ];

    home.packages = with pkgs; [
      (lutris.override {
        extraLibraries = pkgs: [
          # libraries for KSP mod Principia
          pkgs.llvmPackages.libcxx
          pkgs.llvmPackages.libunwind
        ];

        extraPkgs = pkgs: [
          # default icons
          pkgs.adwaita-icon-theme
          # MS fonts needed for KSP
          pkgs.corefonts
        ];
      })

      # Minecraft
      (prismlauncher.override {
        jdks = [
          # GT: New Horizons
          zulu25
          # Vanilla
          zulu21
          # Nomifactory
          zulu8
        ];
      })

      # KSP mods
      ckan

      # Kitten Space Agency
      ksa

      factorio
      (writeShellApplication {
        name = "fetch-factorio-archive";
        runtimeInputs = [
          coreutils
          curl
          nix
        ];
        text = ''
          umask 077
          token_file=/run/secrets/factorio-token
          if [[ ! -r "$token_file" ]]; then
            echo "Factorio token is not readable at $token_file" >&2
            exit 1
          fi
          archive_dir=$(mktemp -d)
          trap 'rm -rf "$archive_dir"' EXIT
          echo "Downloading Factorio Space Age ${factorio.version}" >&2
          curl --disable --fail --silent --show-error --location \
            --proto '=https' --proto-redir '=https' \
            --get --data-urlencode 'username=Sgiath' \
            --data-urlencode "token@$token_file" \
            --output "$archive_dir/${factorio.src.name}" \
            'https://factorio.com/get-download/${factorio.version}/expansion/linux64'
          nix-prefetch-url --type sha256 --name '${factorio.src.name}' \
            "file://$archive_dir/${factorio.src.name}" '${factorio.src.outputHash}'
          echo "Factorio archive imported and hash verified" >&2
        '';
      })

      # inputs.nix-gaming.packages.${pkgs.stdenv.hostPlatform.system}.star-citizen
    ];

    wayland.windowManager.hyprland.settings.window_rule = [
      {
        match.class = ".factorio-wrapped";
        workspace = "6 silent";
      }
      {
        match.class = "lutris";
        workspace = "6 silent";
      }
      {
        match.class = "steam_app_8500";
        float = true;
      }
    ];
  };
}

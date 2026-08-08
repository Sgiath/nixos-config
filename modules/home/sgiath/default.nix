{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./audio.nix
    ./bitcoin.nix
    ./chromium.nix
    ./clipboard.nix
    ./comm.nix
    ./editors.nix
    ./email_client.nix
    ./file_explorer.nix
    ./games.nix
    ./git.nix
    ./gnupg.nix
    ./hyprland.nix
    ./noctalia.nix
    ./ssh.nix
    ./starship.nix
    ./stt.nix
    ./stylix.nix
    ./tmux.nix
    ./waybar.nix
    ./web_browsers.nix
    ./zsh.nix
  ];

  options.sgiath.enable = lib.mkEnableOption "sgiath config";

  config = lib.mkIf config.sgiath.enable {
    home = {
      stateVersion = "23.11";

      packages = with pkgs; [
        (writeShellScriptBin "update" ''
          pushd ~/nixos

          no_commit=false
          update_args=()
          for arg in "$@"; do
            if [[ "$arg" == "--no-commit" ]]; then
              no_commit=true
            else
              update_args+=("$arg")
            fi
          done
          set -- "''${update_args[@]}"

          if [[ "$no_commit" == false ]]; then
            git add --all
            if ! commit_message="$(${lib.getExe pkgs.llm-agents.pi} \
              --model cliproxy/gpt-5.6-luna:low \
              --print \
              --no-session \
              --no-tools \
              --no-extensions \
              --no-context-files \
              --no-prompt-templates \
              --no-skills \
              --skill "$HOME/.agents/skills/conventional-commit" \
              "Use the loaded conventional-commit skill to write exactly one commit message for the staged diff supplied on stdin. The first line must match '<type>(<optional-scope>): <imperative subject>'. Output only the commit message. Do not describe the change, mention implementation status, or use Markdown fences." \
              < <(git diff --cached))"; then
              echo "Failed to generate a commit message with pi" >&2
              exit 1
            fi

            if [[ ! "$commit_message" =~ ^(feat|fix|docs|style|refactor|perf|build|test|ci|chore)(\([a-z0-9._/-]+\))?!?:[[:space:]][^[:space:]] ]]; then
              echo "pi generated an invalid Conventional Commit message:" >&2
              echo "$commit_message" >&2
              exit 1
            fi

            git commit --signoff -m "$commit_message"
            git push
          fi

          case "$1" in
            --ceres)
              nixos-rebuild switch --sudo --flake '.#ceres'
              ;;

            --vesta)
              nix-store --add-fixed sha256 ~/nix-root/FoundryVTT-Linux-14.364.zip
              NIX_SSHOPTS="-o IdentityAgent=$SSH_AUTH_SOCK" nixos-rebuild switch --sudo --flake '.#vesta' --target-host 'vesta.local'
              ;;

            --hygiea)
              nixos-rebuild switch --sudo --flake '.#hygiea' --target-host 'sgiath@hygiea.sgiath.dev'
              ;;

            --iso)
              nix build '.#install-isoConfigurations.live'

              echo
              echo "doas dd if=result/iso/*.iso of=/dev/sdX status=progress"
              ;;

            *)
              nixos-rebuild switch --sudo --flake .
              ;;
          esac

          popd
        '')

        (writeShellScriptBin "update-limited" ''
          pushd ~/nixos

          case "$1" in
            --ceres)
              nixos-rebuild switch --sudo --max-jobs 2 --cores 12 --flake '.#ceres'
              ;;

            --vesta)
              nix-store --add-fixed sha256 ~/nix-root/FoundryVTT-Linux-13.361.zip
              nixos-rebuild switch --sudo --max-jobs 2 --cores 12 --flake '.#vesta' --target-host 'sgiath@vesta.local'
              ;;

            --hygiea)
              nixos-rebuild switch --sudo --max-jobs 2 --cores 12 --flake '.#hygiea' --target-host 'sgiath@hygiea.sgiath.dev'
              ;;

            --iso)
              nix build '.#install-isoConfigurations.live'

              echo
              echo "doas dd if=result/iso/*.iso of=/dev/sdX status=progress"
              ;;

            *)
              nixos-rebuild switch --sudo --max-jobs 2 --cores 12 --flake .
              ;;
          esac

          popd
        '')

        (writeShellScriptBin "fix-images" ''
          find . -type f \( \
            -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \
            -o -iname "*.tif" -o -iname "*.tiff" -o -iname "*.webp" -o -iname "*.heic" \
            -o -iname "*.heif" \) -print0 | \
          ${lib.getExe parallel-full} -0 --eta \
            ${lib.getExe exiftool} -quiet -api PNGEarlyXMP=1 -JUMBF:all= -overwrite_original {}
        '')

        (writeShellScriptBin "clear-cache" ''
          doas nix-collect-garbage -d
          nix-collect-garbage -d

          doas nix-store --gc
          doas nix-store --optimise

          docker system prune -a -f
          docker volume prune -f

          doas journalctl --vacuum-time=14d
        '')

        # general programs I want to have always available
        imagemagick
        # parallel-full
        ffmpeg
        zip
        unzip
        p7zip
        wget
        dig
        killall
        inotify-tools
        lshw
        parted
        nix-du
        exfat
      ];
    };

    services = {
      pass-secret-service.enable = true;
    };

    programs = {
      home-manager.enable = true;
      fastfetch.enable = true;

      direnv = {
        enable = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };

      password-store = {
        enable = true;
        settings = {
          PASSWORD_STORE_DIR = "${config.xdg.dataHome}/password-store";
        };
        package = pkgs.pass-wayland.withExtensions (exts: [ exts.pass-otp ]);
      };
    };

    systemd.user.startServices = "sd-switch";
  };
}

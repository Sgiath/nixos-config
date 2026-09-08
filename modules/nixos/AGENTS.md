# modules/nixos

## OVERVIEW

Role-based NixOS modules. Snowfall imports every `<dir>/default.nix` into every host, so everything is gated by options, never by import selection. `common/` is the baseline behind `sgiath.enable`; `hardware/` selects GPU/kernel/boot; `desktop/`, `laptop/`, `server/`, `gaming/` are `sgiath.roles.*` toggles; `services/` and `sites/` hook `services.<name>.enable` / `sgiath.sites.<name>.enable`.

## WHERE TO LOOK

| Task | Location | Notes |
| --- | --- | --- |
| Baseline user/nix/boot | `common/users.nix`, `common/nix.nix`, `common/boot.nix` | `boot.nix` reads `sgiath.hardware.{kernel,boot}`. |
| Shared secrets | `common/secrets.nix` | SOPS defaults, user API keys, `apiKeyWrapper`, nix access-tokens template. |
| Network quirks | `common/networking.nix`, `common/yggdrasil.nix`, `laptop/default.nix` | Static branch is `mkIf (!networkmanager.enable)`; laptop forces NetworkManager + public DNS. |
| GPU choice | `hardware/gpu.nix`, `hardware/gpu-amd.nix`, `hardware/gpu-nvidia.nix` | Nullable `sgiath.hardware.gpu`. |
| Desktop session | `desktop/wayland.nix`, `desktop/audio.nix`, `common/stylix.nix` | Greetd/Hyprland, pipewire, theme from `themes/yoru.yaml`. |
| Gaming stack | `gaming/role.nix` | Steam/wine/gamescope/gamemode + `factorio-token` secret. |
| Server root | `server/default.nix`, `server/nginx.nix` | Ceres cache-key trust; ACME Cloudflare, QUIC, shared nginx tuning. |
| Large integrated service | `services/matrix.nix`, `services/hermes-agent.nix` | Secrets, TURN/LiveKit, vhosts, ordering. |
| Reverse proxy template | `sites/nas.nix`, `sites/sinai-camp.nix`, `sites/sgiath-dev.nix` | Static/proxy patterns and rewrites. |
| Game/app services | `services/foundryvtt.nix`, `server/minecraft.nix`, `services/factorio.nix` | Hardcoded ports/working dirs. |
| Local runtime stacks | `services/docker.nix`, `services/ollama.nix`, `services/comfyui.nix` | Hook upstream `enable`; may add groups/services. |

## OPTION NAMESPACE

| Option | Declared in |
| --- | --- |
| `sgiath.enable` | `common/default.nix` |
| `sgiath.hardware.{gpu,kernel,boot,razer.enable}` | `hardware/default.nix` |
| `sgiath.roles.{desktop,laptop,server,gaming}.enable` | `<role>/default.nix` |
| `sgiath.sites.<name>.enable` | `sites/default.nix` |
| `services.<name>.enable` | upstream, or `services/<name>.nix` when project-owned |
| `virtualisation.docker.enable` | upstream; `services/docker.nix` only hooks it |

## CONVENTIONS

- One `default.nix` per top-level directory; subdirectory files are imported explicitly by name.
- `default.nix` never references `pkgs`: Snowfall substitutes its channel `pkgs` (no module-provided overlays) there. Keep bodies in sibling files (`role.nix`, `users.nix`, `<service>.nix`).
- File names are kebab-case and match the option they hook (`services/ntfy-sh.nix` ↔ `services.ntfy-sh.enable`).
- Roles push Home Manager options: `common` sets `home-manager.users.sgiath.sgiath.{enable,roles.terminal.enable}`, `desktop`/`gaming` set their matching `roles.*.enable`.
- Server services gate on `config.sgiath.roles.server.enable && config.services.<name>.enable`; sites additionally on `sgiath.sites.<name>.enable`.
- Host-specific secrets (ceres signing key, openclaw token) live in `systems/`, not here. Never read plaintext secret values during evaluation.
- Nginx vhosts use `onlySSL`, `enableACME`, `kTLS`, and proxy to localhost/internal addresses; ACME credentials live under `/data/secrets`.
- Service state commonly lives under `/data`; capture side effects (firewall ports, `extraGroups`, systemd ordering, bind addresses).

## ANTI-PATTERNS

- Do not add a `default.nix` inside a subdirectory or gate behavior by import selection.
- Do not branch on `networking.hostName`; add a role or host-level setting instead.
- Do not install Wayland or graphical applications outside the desktop role; servers are headless.
- Do not put user-facing Home Manager config here; use `modules/home`.
- Do not broaden GPU logic beyond `amd`/`nvidia`/unset without checking hosts.
- Do not change hardcoded ports/IPs/working dirs without checking vhost and firewall references.

## VALIDATION

```bash
nixfmt modules/nixos/<dir>/<file>.nix
nixos-rebuild switch --sudo --flake '.#ceres'
NIX_SSHOPTS="-o IdentityAgent=$SSH_AUTH_SOCK" nixos-rebuild switch --sudo --flake '.#vesta' --target-host 'vesta.local'
```

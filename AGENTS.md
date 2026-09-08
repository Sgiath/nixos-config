# PROJECT KNOWLEDGE BASE

**Generated:** 2026-06-16
**Commit:** 8380fbec
**Branch:** master

## OVERVIEW

Personal NixOS/Home Manager configuration built with Snowfall Lib namespace `sgiath`. Hosts: `ceres` daily AMD desktop, `pallas` notebook, `vesta` home server.

## STRUCTURE

```text
flake.nix                         # Snowfall Lib entry; overlays/modules wired here
systems/x86_64-linux/<host>/      # host NixOS configs; default/hardware/disko split, services.nix on servers
homes/x86_64-linux/sgiath@<host>/ # host Home Manager configs (host-only extras; roles come from NixOS)
modules/nixos/common/             # baseline under sgiath.enable: users, nix, boot, secrets, networking
modules/nixos/hardware/           # one-of hardware: sgiath.hardware.{gpu,kernel,boot,razer}
modules/nixos/{desktop,laptop,server,gaming}/ # additive roles: sgiath.roles.<role>.enable
modules/nixos/services/           # one file per service, hooked on services.<name>.enable
modules/nixos/sites/              # nginx vhosts, sgiath.sites.<name>.enable
modules/home/common/              # baseline under HM sgiath.enable
modules/home/{terminal,desktop,gaming}/ # HM roles: sgiath.roles.<role>.enable (pushed from NixOS)
modules/home/programs/            # opt-in program groups: sgiath.programs.<group>.enable
modules/home/agents/              # agent tooling and services (cli-proxy-api, t3code, ...)
modules/home/work/                # sgiath.work.{crazyegg,remote}.enable
themes/                           # base16 schemes shared by NixOS and HM stylix
secrets/                          # SOPS files plus the public ceres-cache.pub signing key
scripts/                          # update-inputs.sh
packages/                         # custom packages, update/clear-cache commands, updater scripts
overlays/sgiath/default.nix       # selected packages from alternate nixpkgs channels
shells/default/default.nix        # dev/update toolchain
```

## WHERE TO LOOK

| Task | Location | Notes |
| --- | --- | --- |
| Add/change host config | `systems/x86_64-linux/<host>/default.nix` | Role/hardware toggles and host-only secrets; keep hardware/disk layout separate. |
| Server service list | `systems/x86_64-linux/vesta/services.nix` | `services.<name>.enable` and `sgiath.sites.<name>.enable`. |
| Add/change user config | `homes/x86_64-linux/sgiath@<host>/default.nix` | Host-only packages, work toggles, font sizes; HM roles are pushed from NixOS. |
| Shared NixOS baseline | `modules/nixos/common/` | Everything every host gets under `sgiath.enable`. |
| Hardware variant | `modules/nixos/hardware/` | GPU vendor, kernel, boot mode, Razer. |
| Machine role | `modules/nixos/<role>/` | `desktop`, `laptop`, `server`, `gaming`; each pushes its HM role. |
| Server service | `modules/nixos/services/<name>.nix` | `/data`, ports, secrets; file named after the option. |
| Reverse-proxied site | `modules/nixos/sites/<name>.nix` | nginx vhost behind `sgiath.sites.<name>.enable`. |
| Shared Home Manager feature | `modules/home/<group>/` | `common`, `terminal`, `desktop`, `programs`, `gaming`, `agents`, `work`. |
| Custom package | `packages/<name>/` and `packages/default.nix` | Add/update package plus registry entry. |
| Package updater tooling | `shells/default/default.nix` | Add updater dependencies here, not via `nix-shell` shebangs. |
| Alternate nixpkgs package | `overlays/sgiath/default.nix` | Imports master/stable/ksa with repo channel config. |

## CODE MAP

| Symbol/Field | Location | Role |
| --- | --- | --- |
| `inputs` | `flake.nix` | 30+ flake inputs; includes local absolute `bird-src`. |
| `lib.mkFlake` | `flake.nix` | Snowfall Lib output generation; no manual `nixosConfigurations`. |
| `channels-config` | `flake.nix` | `allowUnfree`, ROCm enabled, CUDA disabled. |
| `systems.modules.nixos` | `flake.nix` | External NixOS modules exposed to all hosts. |
| `homes.modules` | `flake.nix` | External Home Manager modules exposed to all homes. |
| `sgiath.enable` | `modules/nixos/common/default.nix` | Main shared system gate; pushes HM `sgiath.enable` + `roles.terminal`. |
| `sgiath.hardware.*` | `modules/nixos/hardware/default.nix` | `gpu` (`null`/`amd`/`nvidia`), `kernel` (`zen`/`xanmod`), `boot` (`uefi`/`legacy`), `razer.enable`. |
| `sgiath.roles.desktop.enable` | `modules/nixos/desktop/default.nix` | Wayland, audio, bluetooth, printing; pushes HM `roles.desktop`. |
| `sgiath.roles.laptop.enable` | `modules/nixos/laptop/default.nix` | NetworkManager + public DNS `resolv.conf`. |
| `sgiath.roles.server.enable` | `modules/nixos/server/default.nix` | Main server-module gate; nginx, minecraft, trusts `secrets/ceres-cache.pub`. |
| `sgiath.roles.gaming.enable` | `modules/nixos/gaming/default.nix` (body in `role.nix`) | Steam/wine/gamescope/gamemode, factorio token; pushes HM `roles.gaming`. |
| `sgiath.sites.<name>.enable` | `modules/nixos/sites/default.nix` | nginx vhosts: `sgiath-dev`, `sinai-camp`, `nas`, `eve`, `ai`. |
| `services.<name>.enable` | `modules/nixos/services/<name>.nix` | Local services (upstream option or declared there). |
| HM `sgiath.roles.*` | `modules/home/{terminal,desktop,gaming}/default.nix` | User-side role bodies; set from NixOS, not from homes. |
| HM `sgiath.programs.*` | `modules/home/programs/default.nix` | `audio`, `bitcoin`, `chat`, `editors`, `email`, `browsers`. |
| HM `sgiath.work.*` | `modules/home/work/default.nix` | `crazyegg`, `remote`. |
| `packages/default.nix` attrs | `packages/default.nix` | Hand-maintained local package registry. |

## LAYOUT RULES

- One baseline: `common` (NixOS and HM) holds everything every machine gets, gated on `sgiath.enable`.
- Hardware is one-of: `sgiath.hardware.gpu`/`kernel`/`boot` are enums, `razer` a toggle; pick values, never stack modules.
- Roles are additive: `desktop`, `laptop`, `server`, `gaming` under `sgiath.roles.<role>.enable`; a host enables any combination.
- Services hook `services.<name>.enable` uniformly, whether the option is upstream or declared locally in `modules/nixos/services/<name>.nix`.
- Sites are nginx vhosts under `sgiath.sites.<name>.enable`, one file per site in `modules/nixos/sites/`.
- NixOS roles push the matching HM roles via `home-manager.users.sgiath.sgiath.roles.<role>.enable`; homes never set roles themselves.
- Snowfall imports every `modules/<class>/<dir>/default.nix`: exactly one `default.nix` per module directory, none in subdirectories; parents import plain-named `*.nix` files explicitly. Gate with `lib.mkIf`, never by import selection.
- Snowfall rewrites `pkgs` and `lib` for every discovered `<dir>/default.nix` (its channel `pkgs` lacks module-provided `nixpkgs.overlays`, e.g. Stylix's). `default.nix` therefore holds only option declarations, `imports`, and cross-layer option coupling; anything touching `pkgs` lives in a sibling file (`role.nix`, `base.nix`, `<feature>.nix`).

## CONVENTIONS

- Snowfall discovers `systems`, `homes`, `modules`, `packages`, `overlays`, `shells`; do not add manual output lists unless replacing Snowfall behavior.
- Modules use `options.<scope>.enable = lib.mkEnableOption ...` plus `config = lib.mkIf config.<scope>.enable ...`.
- Main NixOS/Home Manager state versions are `23.11`; do not bump casually.
- Secrets are SOPS-encrypted in `secrets/` and decrypted at activation using host SSH keys. Use `sops.secrets` with native runtime credential files; never evaluate plaintext credentials into Nix/store files.
- New files must be `git add`ed before Nix flake evaluation can see them.
- Format Nix with `nixfmt`; use `nix develop` for `nixd`, `nil`, `shfmt`, `prettier`, and update helpers.
- Do not evaluate Home Manager outputs directly; Stylix Home Manager wiring is provided through the NixOS Stylix module. Validate homes as part of the full NixOS system evaluation/build.

## ANTI-PATTERNS

- Never delete the `result` symlink; leave it for the user.
- Do not use `nix-shell` shebangs in new update scripts; add missing tools to `shells/default/default.nix`.
- Do not compute hashes before detecting that an updater's version actually changed.
- Do not copy `packages/relay-tester/update.sh`'s `nix-shell` lockfile step into new scripts; treat it as legacy.
- Do not reintroduce git-crypt, plaintext secret files, or secret values in Nix options/derivations. Ceres's private build-signing key must never be distributed to Vesta.
- Do not gate shared modules on `networking.hostName`; host-only config belongs in `systems/.../<host>/`.
- Destructive git ops are forbidden unless explicit: no reset, clean, restore, force-push.

## COMMANDS

```bash
nix develop
nixfmt <file.nix>
./scripts/update-inputs.sh
nix flake update
nix build '.#<package>'
nix build '.#install-isoConfigurations.live'
nixos-rebuild switch --sudo --flake .
nixos-rebuild switch --sudo --flake '.#ceres'
update --vesta
```

## NOTES

- No in-repo CI or NixOS VM test suite. Validate homes through full NixOS builds.
- Custom user commands `update` and `clear-cache` are packages in `packages/`; `update` commits and pushes before rebuilding (`--no-commit` skips that) and `update --vesta` builds/signs on Ceres and pushes over SSH.
- `clear-cache` runs Nix GC, Docker prune, and journal vacuum; treat as destructive maintenance.
- `scripts/update-inputs.sh` bumps release-pinned flake inputs and runs `packages/*/update.sh`.
- `dnd5etools` has a separate image hash updater; package `update.sh` alone is incomplete if image assets changed.

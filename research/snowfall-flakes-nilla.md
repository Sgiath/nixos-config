# Snowfall, flakes, and Nilla: state of play and options for this repo

Researched: 2026-08-09

## Question

Snowfall Lib looks unmaintained ([snowfallorg/lib#173](https://github.com/snowfallorg/lib/issues/173)),
and there is talk that flakes themselves are a dead end. What is actually true, what is Jake
Hamilton (Snowfall's author) doing now, and is Nilla a viable migration target for this config?

## 1. Snowfall Lib: maintenance mode, not dead

- Jake Hamilton, in issue #173 (2025-03-16): "Snowfall Lib hasn't really changed much at all in
  quite some time now and I don't foresee it changing in the future." and "If you want to keep
  using flakes then Snowfall Lib will still be around for you to use. It isn't going anywhere."
  He calls Snowfall "a bandage over a problem rather than a solution" and says he does not see
  flakes as the future of Nix. ([comment](https://github.com/snowfallorg/lib/issues/173#issuecomment-2727170925))
- Activity: last release `v3.0.3` is from **2024-06-11**. Two PRs merged in 2025 (a Home Manager
  compat fix in Jan, a `fold`→`foldr` deprecation fix in Dec). No merges in 2026. On
  **2026-07-17** the README gained a **call-for-maintainers** section
  ([6ee3542](https://github.com/snowfallorg/lib/commit/6ee3542cb459ca4b038cfe50ceb8797f05cdabad)).
- Users in #173 asked about handing the project to nix-community (May 2026); no maintainer
  response confirming a transfer.
- Rest of snowfallorg: `flake` last touched 2025-06; `frost` 2023-08; `thaw`/`drift` 2024-05.
  Effectively dormant.

**Conclusion:** feature-frozen, occasionally patched, seeking maintainers. Not disappearing, but
do not expect fixes for new nixpkgs/HM breakage to arrive quickly. Our vendored
`vendor/flake-utils-plus-fixed` workaround is exactly the kind of cost this implies, recurring.

## 2. "Consensus that flakes are bad" is an overstatement

- Adoption is high: **78.9%** of NixOS 2025 survey respondents use flakes (85% in 2024)
  ([survey](https://nixos.org/surveys/community/2025/)). Flakes are also the #1 area people want
  improved (50.3%).
- Real, documented criticisms: still officially experimental with outstanding issues
  ([nix.dev](https://nix.dev/concepts/flakes)); RFC 49 never accepted, implementation merged
  anyway; `flake.nix` inputs can't be computed/DRYed; input copying to the store scales badly;
  awkward cross-compilation; flake-specific lockfile with weak versioning story. Canonical
  critique: jade's ["Flakes aren't real and cannot hurt you"](https://jade.fyi/blog/flakes-arent-real/);
  Jake's own ["Flakes have failed"](https://kilo.bytesize.xyz/flakes-have-failed).
- Institutional split, not consensus:
  - **Determinate Systems**: flakes are stable in practice, the biggest step forward for Nix
    ([post](https://determinate.systems/blog/experimental-does-not-mean-unstable/)).
  - **Lix**: keeps supporting flakes but froze their feature set (Nov 2025) and is extracting
    them from core into a plugin (Lix 2.95, Mar 2026); wants flake-like capabilities available
    to npins-style projects too ([freeze](https://wiki.lix.systems/books/development/page/flakes-feature-freeze),
    [2.95](https://lix.systems/blog/2026-03-25-lix-2.95-release/)).
  - **Critics**: want pinning and purity via ordinary Nix + npins/niv/lon, without the flake
    schema. Notably even jade's position is "both flakes and npins should be equally valid",
    not "flakes must die".

**Conclusion:** flakes are the dominant, imperfect de-facto standard. There is consensus they
have flaws; there is no consensus to abandon them. Nobody credible predicts existing flake
configs breaking.

## 3. What Jake runs now: jakehamilton/config = Nilla + npins + Colmena

- Migrated **2025-03-12/13**: [`ae60b16`](https://github.com/jakehamilton/config/commit/ae60b160f43283cb537ee76ab3f0f14d7c9b99ef)
  "feat: add nilla", then [`d67e871`](https://github.com/jakehamilton/config/commit/d67e8711427aad333cc6dea8781890ca27d889d2)
  "chore: remove flake files". README: "Instead of the usual ecosystem solutions, here I am
  using Nilla." He notes he's run it "for well over a year now for all of my systems".
- Structure: `nilla.nix` entrypoint + `npins/` for pinning + `nilla/` tree
  (`systems/nixos/<host>/`, `packages/`, `colmena/`, `lib/`, `inputs.nix`). No Snowfall-style
  auto-discovery: every module, package, and host is **explicitly registered** via `includes`
  and `config.modules.*`.
- Inputs: `npins` fetches, Nilla loads with per-input loaders (`home-manager = "flake"`,
  `stylix = "flake"`, `lix = "raw"`), with `follows`-style input rewiring done in Nilla config.
- Home Manager is loaded as a flake input and integrated through NixOS modules (no standalone
  `homeConfigurations`).
- Deployment: Colmena nodes registered next to each system; a tiny compatibility `flake.nix`
  (no inputs) exposes selected outputs (currently `darwinConfigurations`).

## 4. Nilla itself: coherent design, alpha maturity

- Active in 2025-2026 (core, cli, nixos, home all pushed July 2026), multiple contributors,
  latest release **v0.0.0-alpha.17** ([releases](https://github.com/nilla-nix/nilla/releases)).
  ~155 stars on core; the `home` (Home Manager) repo has ~2 stars and minimal docs.
- Model: `nilla.nix` + Aux Lib module system; inputs pinned by npins, loaded by Nilla
  (loaders: nilla/nixpkgs/flake/legacy/raw); `packages.*`, `shells.*`, `systems.nixos.*`
  options; operated via `nilla build` / `nilla shell` / `nilla nixos switch <host>`
  ([docs](https://nilla.dev/guides/)).
- Works without flakes but can consume flakes, and a compat `flake.nix` can re-expose outputs.
- Gaps/risks: alpha with breaking-change churn (loader auto-detection, overrides, args handling
  all have open issues); Home Manager guide missing vs the NixOS guide; no overlays guide; no
  Snowfall migration guide; small ecosystem; quickstart/doc breakage reported
  ([#37](https://github.com/nilla-nix/nilla/issues/37), [#40](https://github.com/nilla-nix/nilla/issues/40)).

## 5. What this means for ~/nixos

Coupling assessment (2026-08-09): Snowfall touches us via (a) `flake.nix` `mkLib`/`mkFlake`,
(b) auto-discovery of `systems/`, `homes/`, `modules/`, `packages/`, `overlays/`, `shells/`,
(c) the injected `namespace` module arg / `pkgs.sgiath.*` in ~12 files, (d) the vendored
`flake-utils-plus-fixed` fix. Module bodies, host configs, disko/hardware, secrets, and package
derivations are all framework-agnostic and would port as-is.

Options, roughly in order of increasing effort:

1. **Stay put (fine for now).** Snowfall keeps working; we already patched its one rotting
   dependency. Cost: we own such patches forever, and the maintainer pool may shrink further.
2. **De-Snowfall onto plain flakes or flake-parts.** Replace discovery with explicit
   `nixosConfigurations` wiring; keep flakes, drop the dead framework. Least conceptual change,
   flakes stay the ecosystem default (78.9% adoption, Lix/DetSys both committed to keeping them
   running).
3. **Nilla + npins (Jake's path).** Structural rewrite of the top layer: flake.lock → npins,
   discovery → explicit registration, `nixos-rebuild --flake` → `nilla nixos switch` (or keep a
   compat flake so `nixos-rebuild` still works). Alpha risk, weak HM docs, but the author runs
   6 hosts on it and it fixes the actual flake pain points (input rigidity, store copying).

**Recommendation:** no emergency. Treat Snowfall as frozen: avoid deepening dependence on its
discovery/namespace features. If we want to move, prototype Nilla on one host (e.g. `vesta` or
a VM) on a branch — port one system, one home, one package, one shell — and check whether
`nilla-nix/home` covers our HM usage before committing. Re-evaluate Nilla once it leaves
alpha or ships a Snowfall/flakes migration guide. Migrate deliberately, not reactively.

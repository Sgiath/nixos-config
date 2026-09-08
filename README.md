# NixOS configs

## Install

```bash
# install system config
nixos-rebuild switch --sudo --flake https://github.com/sgiath/nixos-config#ceres

reboot

# install dotfiles
git clone https://github.com/sgiath/nixos-config ~/nixos
cd nixos/
nixos-rebuild switch --sudo --flake '.#ceres'

reboot
```

## Usage

```bash
# update release pinned flake inputs and packages
./update-inputs

# update branch inputs
nix flake update

# switch current system
update

# switch server
update --vesta
```

## Secrets

Secrets are SOPS-encrypted under `secrets/`. Nix evaluation and builds need only
ciphertext; sops-nix decrypts on the target using its SSH Ed25519 host key.
The administrator GPG key can edit all files:

```bash
nix develop -c sops secrets/secrets.yaml
nix develop -c sops secrets/vesta.yaml
```

`secrets.yaml` contains shared/application credentials. `vesta.yaml` contains
Hermes and its Bird credentials and is encrypted only for Vesta and the
administrator. `ceres-signing.yaml` contains the build-signing private key and
is encrypted only for Ceres and the administrator. Only the public signing key
is stored unencrypted, in `public-keys/ceres-cache.pub`.

The configured host recipients are Ceres and Vesta. Before deploying another
host or replacing a host's SSH key, add its `ssh-to-age` public recipient to
`.sops.yaml` and run `sops updatekeys` on the relevant files. Keep an offline
backup of the administrator encryption key.

User API credentials are readable only by `sgiath` and loaded into that user's
shell sessions at runtime. `with-api-keys COMMAND` supplies them to commands
started outside a login shell. Nix's GitHub token is included from a protected
runtime file in the user's Nix configuration, not the system-wide `nix.conf`.
Daemon services receive only their own credential files.

Do not put plaintext secrets in the repository, Nix options, derivation
arguments, or generated store files. Git-crypt is no longer used.

## Signed server deployment

After integrating these changes, activate Ceres first to install its signing
key and updated deployment commands:

```bash
nixos-rebuild switch --sudo --flake '.#ceres'
update --vesta
```

Both `update --vesta` build on Ceres, sign the exact
selected system closure, and pass it to `nixos-rebuild --store-path` for SSH
transfer and activation. Neither command changes the existing `result` link.
Vesta trusts Ceres's public key; it never receives the private key. Signature
checks remain enabled, including for downloaded packages. Existing flake
caches remain explicitly allowed for ordinary, non-trusted Nix users.

The paid Factorio archive must already be imported into the Nix store for the
first Ceres build; the package error provides the exact filename/hash/import
command. After activation, `fetch-factorio-archive` downloads and verifies the
pinned archive using the runtime credential, without embedding it in a build.

Removing plaintext from the current configuration does not remove it from
old store paths, generations, backups, or previously copied sources. Rotate
the affected credentials after activation; retain recovery generations until
the migrated services have been verified.

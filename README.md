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

Both `update --vesta` and `update-limited --vesta` build on Ceres, sign the exact
selected system closure, and pass it to `nixos-rebuild --store-path` for SSH
transfer and activation. Neither command changes the existing `result` link.
Vesta trusts Ceres's public key; it never receives the private key. Signature
checks remain enabled, including for downloaded packages. Existing flake
caches remain explicitly allowed for ordinary, non-trusted Nix users.

The first Vesta activation copies active Hermes state from
`/home/sgiath/hermes` to `/var/lib/hermes-agent`, verifies the copy, and changes
ownership to the dedicated `hermes` account. It retains the source and leaves
older `/var/lib/hermes` data untouched. Later activations reuse the migrated
state. The dashboard is accessible through its existing HTTPS proxy rather
than directly through port 9119. Buzz services are removed; their stored data
is not deleted.

The paid Factorio archive must already be imported into the Nix store for the
first Ceres build; the package error provides the exact filename/hash/import
command. After activation, `fetch-factorio-archive` downloads and verifies the
pinned archive using the runtime credential, without embedding it in a build.

Removing plaintext from the current configuration does not remove it from
old store paths, generations, backups, or previously copied sources. Rotate
the affected credentials after activation; retain recovery generations until
the migrated services have been verified.

## Security verification

```bash
nix develop
python3 -m unittest discover -s tests
python3 modules/nixos/server/hermes-migrate-test.py
python3 tests/check_signed_transfer.py /run/secrets/nix-signing-key public-keys/ceres-cache.pub
ceres=$(nix build '.#nixosConfigurations.ceres.config.system.build.toplevel' --no-link --print-out-paths)
vesta=$(nix build '.#nixosConfigurations.vesta.config.system.build.toplevel' --no-link --print-out-paths)
python3 tests/check_service_credentials.py "$vesta"
python3 tests/check_hermes_setup.py "$vesta"
python3 tests/check_store_secrets.py "$ceres" "$vesta"
```

The transfer check uses a disposable Vesta store, verifies signatures before
and after SSH transfer, and does not activate either host.

The service and activation checks use synthetic secrets in disposable
Bubblewrap namespaces. The store check decrypts credentials only in memory and
reports matching paths without printing secret values.

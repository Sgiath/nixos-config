{
  writeShellApplication,
  coreutils,
  git,
  gnupg,
  nix,
  openssh,
  ssh-to-age,
  util-linux,
}:
# Installer for the live ISO: imports the GPG key from the SGIATH-KEYS
# partition written by `burn-iso`, then runs disko + nixos-install for a host
# from this repository.
writeShellApplication {
  name = "live-install";
  runtimeInputs = [
    coreutils
    git
    gnupg
    nix
    openssh
    ssh-to-age
    util-linux
  ];
  text = ''
    usage() {
      cat <<EOF
    Usage: live-install [--keep-disks] <host>

    Installs systems/x86_64-linux/<host> from ~/nixos onto this machine.

      --keep-disks  Skip disko; expect the target filesystems mounted at /mnt.
    EOF
    }

    keep_disks=false
    host=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --keep-disks) keep_disks=true ;;
        -h | --help) usage; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
        *) host="$1" ;;
      esac
      shift
    done
    [[ -n "$host" ]] || { usage >&2; exit 2; }

    repo="$HOME/nixos"
    keys_dev=/dev/disk/by-label/SGIATH-KEYS

    echo "==> GPG key"
    if [[ -e "$keys_dev" ]]; then
      keys_mnt=$(mktemp -d)
      sudo mount -o ro "$keys_dev" "$keys_mnt"
      [[ -f "$keys_mnt/secret-keys.asc" ]] && gpg --import "$keys_mnt/secret-keys.asc"
      [[ -f "$keys_mnt/ownertrust.txt" ]] && gpg --import-ownertrust "$keys_mnt/ownertrust.txt"
      sudo umount "$keys_mnt"
      rmdir "$keys_mnt"
    else
      echo "    no SGIATH-KEYS partition found; continuing without the private key"
    fi

    echo "==> Repository at $repo"
    if [[ ! -d "$repo" ]]; then
      # /etc/sgiath/nixos is a symlink into the read-only store.
      cp -rT --no-preserve=mode "$(readlink -f /etc/sgiath/nixos)" "$repo"
    fi
    if [[ ! -d "$repo/.git" ]]; then
      # Turn the baked snapshot into a checkout; the working tree stays as shipped.
      git -C "$repo" init -q -b master
      git -C "$repo" remote add origin https://github.com/sgiath/nixos-config
      if git -C "$repo" fetch -q origin master; then
        git -C "$repo" reset -q origin/master
      else
        echo "    offline: history will be attached later with 'git fetch && git reset origin/master'"
      fi
    fi
    # Nix Git flakes omit untracked files, including modules absent upstream.
    git -C "$repo" add -A

    host_dir="$repo/systems/x86_64-linux/$host"
    if [[ ! -d "$host_dir" ]]; then
      echo "ERROR: $host_dir does not exist; create the host first (nixos-generate-config --no-filesystems --show-hardware-config)" >&2
      exit 1
    fi

    if [[ "$keep_disks" == false ]]; then
      if [[ ! -f "$host_dir/disko.nix" ]]; then
        echo "ERROR: $host has no disko.nix; use --keep-disks with filesystems mounted at /mnt" >&2
        exit 1
      fi
      echo "==> Disks $host will be installed on (from disko.nix):"
      nix eval --json "$repo#nixosConfigurations.$host.config.disko.devices.disk" \
        --apply 'disks: builtins.mapAttrs (_: d: d.device) disks'
      echo
      lsblk -o NAME,SIZE,TYPE,MODEL,MOUNTPOINTS
      echo
      read -r -p "Type '$host' to WIPE those disks and install: " answer
      [[ "$answer" == "$host" ]] || { echo "aborted"; exit 1; }
      sudo disko --mode destroy,format,mount --yes-wipe-all-disks --flake "$repo#$host"
    else
      mountpoint -q /mnt || { echo "ERROR: nothing mounted at /mnt" >&2; exit 1; }
    fi

    echo "==> nixos-install $host"
    sudo nixos-install --flake "$repo#$host" --no-root-passwd

    echo "==> Host SSH key (sops recipient)"
    host_key=/mnt/etc/ssh/ssh_host_ed25519_key
    if ! sudo test -f "$host_key"; then
      sudo mkdir -p /mnt/etc/ssh
      sudo ssh-keygen -q -t ed25519 -N "" -C "root@$host" -f "$host_key"
    fi
    recipient=$(sudo cat "$host_key.pub" | ssh-to-age)

    echo "==> Copying repository to /mnt/home/sgiath/nixos"
    sudo mkdir -p /mnt/home/sgiath
    sudo rm -rf /mnt/home/sgiath/nixos
    sudo cp -a "$repo" /mnt/home/sgiath/nixos
    sudo nixos-enter --root /mnt -c 'chown -R sgiath:users /home/sgiath/nixos' >/dev/null

    cat <<EOF

    ==> Installed $host. Before rebooting, let it decrypt its secrets:

      1. Add the host to .sops.yaml:   - &$host $recipient
         and reference *$host in the creation_rules that apply to it.
      2. cd ~/nixos && sops updatekeys -y secrets/*.yaml
      3. Reinstall with the updated encrypted secrets before rebooting:
         sudo nixos-install --flake "$repo#$host" --no-root-passwd
      4. git commit -a && git push, then copy the result:
         sudo cp -a ~/nixos/. /mnt/home/sgiath/nixos/

    Then: reboot
    EOF
  '';
}

{
  writeShellApplication,
  coreutils,
  dosfstools,
  gnupg,
  nix,
  parted,
  systemd,
  util-linux,
}:
# Builds the live ISO, writes it to a USB stick and appends a SGIATH-KEYS
# partition holding the passphrase-protected GPG secret keys exported from the
# running keyring. The keys never enter the Nix store.
writeShellApplication {
  name = "burn-iso";
  runtimeInputs = [
    coreutils
    gnupg
    nix
    util-linux
  ];
  text = ''
    usage() {
      cat <<EOF
    Usage: burn-iso [--no-keys] [--iso PATH] <device>

    Writes the live ISO to <device> (e.g. /dev/sdb) and adds a SGIATH-KEYS
    partition with the GPG secret keys from this user's keyring.

      --no-keys   Write only the ISO.
      --iso PATH  Use an already built ISO instead of building it.
    EOF
    }

    with_keys=true
    iso=""
    dev=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --no-keys) with_keys=false ;;
        --iso) iso="$2"; shift ;;
        -h | --help) usage; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
        *) dev="$1" ;;
      esac
      shift
    done
    [[ -n "$dev" ]] || { usage >&2; exit 2; }
    [[ -b "$dev" ]] || { echo "ERROR: $dev is not a block device" >&2; exit 1; }

    dev_type=$(lsblk -dno TYPE "$dev")
    if [[ "$dev_type" != "disk" && "$dev_type" != "loop" ]]; then
      echo "ERROR: $dev is a $dev_type, not a whole disk" >&2
      exit 1
    fi
    if [[ -n "$(lsblk -no MOUNTPOINTS "$dev" | tr -d '[:space:]')" ]]; then
      echo "ERROR: $dev has mounted partitions" >&2
      exit 1
    fi

    if [[ -z "$iso" ]]; then
      echo "==> Building the live ISO"
      out=$(nix build --no-link --print-out-paths "$HOME/nixos#install-isoConfigurations.live")
      iso=$(echo "$out"/iso/*.iso)
    fi
    [[ -f "$iso" ]] || { echo "ERROR: ISO not found: $iso" >&2; exit 1; }

    echo "==> Target"
    lsblk -dno NAME,SIZE,MODEL,TRAN "$dev"
    read -r -p "Type '$(basename "$dev")' to overwrite it: " answer
    [[ "$answer" == "$(basename "$dev")" ]] || { echo "aborted"; exit 1; }

    echo "==> Writing $iso"
    sudo ${coreutils}/bin/dd if="$iso" of="$dev" bs=4M conv=fsync status=progress

    if [[ "$with_keys" == false ]]; then
      echo "==> Done"
      exit 0
    fi

    # Desktop automounters grab the ISO and new partitions as soon as they appear.
    unmount_all() {
      sudo ${systemd}/bin/udevadm settle
      lsblk -lnpo MOUNTPOINTS "$dev" | sed '/^$/d' | while read -r mp; do
        sudo ${util-linux}/bin/umount "$mp"
      done
    }

    echo "==> Adding SGIATH-KEYS partition"
    # The hybrid ISO's GPT is sized to the image and overlaps its own MBR entry,
    # so gptfdisk refuses it; the kernel reads the MBR, so append there.
    unmount_all
    echo 'size=64M, type=0c' | sudo ${util-linux}/bin/sfdisk --quiet --append --no-reread "$dev" 2>/dev/null
    sudo ${parted}/bin/partprobe "$dev"
    unmount_all
    part=$(lsblk -lnpo NAME,PARTN "$dev" | awk '$2 == 3 { print $1 }')
    [[ -n "$part" ]] || { echo "ERROR: partition 3 not found after partprobe" >&2; exit 1; }
    sudo ${dosfstools}/bin/mkfs.vfat -n SGIATH-KEYS "$part" >/dev/null
    unmount_all

    mnt=$(mktemp -d)
    trap 'sudo ${util-linux}/bin/umount "$mnt" 2>/dev/null; rmdir "$mnt" 2>/dev/null' EXIT
    sudo ${util-linux}/bin/mount -o "uid=$(id -u),fmask=077,dmask=077" "$part" "$mnt"

    echo "==> Exporting GPG secret keys (passphrase-protected)"
    gpg --export-secret-keys --armor > "$mnt/secret-keys.asc"
    gpg --export-ownertrust > "$mnt/ownertrust.txt"
    sync
    sudo ${util-linux}/bin/umount "$mnt"
    trap - EXIT
    rmdir "$mnt"

    echo "==> Done. Boot the stick and run: live-install <host>"
  '';
}

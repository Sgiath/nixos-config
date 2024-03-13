# NixOS configs

## Install

```bash
# install system config
sudo nixos-rebuild switch --flake https://git.sr.ht/~sgiath/nix-config#ceres

# install Home Manager
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update

reboot

# install dotfiles
git clone https://git.sr.ht/~sgiath/nix-config ~/.dotfiles
cd .dotfiles/
sudo nixos-rebuild switch --flake .

reboot
upgrade
```

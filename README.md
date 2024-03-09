# NixOS configs

## Install

```bash
# install system config
sudo nixos-rebuild switch --flake https://git.sr.ht/~sgiath/nix-config#ceres
reboot

# install Home Manager
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
# re-login
nix-shell '<home-manager>' -A install

# install dotfiles
git clone https://git.sr.ht/~sgiath/nix-config ~/.dotfiles
cd .dotfiles/
home-manager switch --flake .

reboot
upgrade
```

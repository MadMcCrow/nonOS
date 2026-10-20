# This module defines a NixOS installation CD that contains Plasma 6.
{
  lib,
  pkgs,
  nonOS,
  inputs,
  ...
}:
let
  name = nonOS.lib.meta.name;
  username = "nixos"; # we use the nixos config, so we can't/ won't override too much
in
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-base.nix"
    "${inputs.nixpkgs}/nixos/modules/profiles/minimal.nix"
    nonOS.nixosModules.shared # TODO : make this a default import for other modules
    nonOS.nixosModules.desktop
    nonOS.nixosModules.storage
    nonOS.nixosModules.customization
  ];

  config = {
    # our special sauce :
    nonOS = {
      storage.zfs.enable = true;
      storage.bcachefs.enable = true;
      desktop.apps.enable = true;
      nixpkgs.removeSources = true; # hopefully we get network !
    };

    # name of the iso
    isoImage.edition = name;

    # give user a way to format drives
    programs.partition-manager.enable = true;

    # add a simple text editor
    environment.systemPackages = with pkgs; [
      nano
    ];

    # make for an even smaller iso :
    services.speechd.enable = mkForce false;
    documentation.info.enable = mkForce false;
    documentation.nixos.enable = mkForce false;

    # Support choosing from any locale
    i18n.supportedLocales = [ "all" ];

    # Automatically login as nixos;
    services.displayManager.autoLogin = {
      enable = true;
      user = username;
    };

    # Whitelist wheel users to do anything
    security.polkit = {
      enablePkexecWrapper = true;
      extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (subject.isInGroup("wheel")) {
            return polkit.Result.YES;
          }
        });
      '';
    };

    systemd.tmpfiles.settings."10-installer-desktop" = {
      "/home/name/Desktop".d = {
        user = username;
        group = "users";
        mode = "0755";
      };
    };
    system.stateVersion = lib.mkForce "26.11";
  };
}

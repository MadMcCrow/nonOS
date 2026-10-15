# update.nix
# A/B updates with systemd-sysupdate, and the bundle to upload
{
  mkModule,
  mkOptions,
  self,
  ...
}:
{
  config,
  lib,
  pkgs,
  ...
}:
with (mkModule config);
let
  inherit (config.system.image) id version;
  inherit (config.system.boot.loader) ukiFile;
in
{
  options =
    with self.lib.options;
    mkOptions {
      # updates paths
      paths = {
        staging = mkPathOption "verifies update files" "/var/lib/fw-upload/staging";
        incoming = mkPathOption "receives raw uploads" "/var/lib/fw-upload/incoming";
      };

      target.disk = lib.mkOption {
        description = ''
          disk holding the store slots. "auto" may fail with a tmpfs root :
          prefer /dev/disk/by-id/nvme-...
        '';
        default = "auto";
        type = lib.types.str;
      };

      autoReboot = mkBoolOption "reboot automatically after a successful update" true;

      markerFile = mkStrOption "file name that signals an upload batch is complete" ".ready";

      container = {
        name = mkStrOption "container name" "fw-upload";
        port = mkPortOption "fw-upload" 8888;
      };
    };

  config = mkIfEnable {
    # what you upload : compressed store slot + UKI
    system.build.updateBundle =
      pkgs.runCommand "nonos-update-${version}" { nativeBuildInputs = [ pkgs.xz ]; }
        ''
          mkdir -p $out
          src=$(echo ${config.system.build.image}/*nix-store*.raw)
          xz -T0 -c "$src" > $out/${id}_${version}.nix-store.raw.xz
          cp ${config.system.build.uki}/${ukiFile} $out/
        '';

    systemd.sysupdate = {
      enable = true;
      transfers =
        let
          source = {
            Type = "regular-file";
            Path = cfg.paths.staging;
          };
          Transfer.Verify = "no"; # TODO : sign bundles, then set to yes
        in
        {
          "10-nix-store" = {
            Source = source // {
              MatchPattern = [ "${id}_@v.nix-store.raw.xz" ];
            };
            Target = {
              InstancesMax = 2;
              Path = cfg.target.disk;
              MatchPattern = "nix-store_@v";
              Type = "partition";
              MatchPartitionType = "linux-generic";
              ReadOnly = "yes";
            };
            inherit Transfer;
          };
          "20-boot-image" = {
            Source = source // {
              MatchPattern = [ "${config.boot.uki.name}_@v.efi" ];
            };
            Target = {
              InstancesMax = 2;
              MatchPattern = [ "${config.boot.uki.name}_@v.efi" ];
              Mode = "0444";
              Path = "/EFI/Linux";
              PathRelativeTo = "boot";
              Type = "regular-file";
            };
            inherit Transfer;
          };
        };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.paths.staging} 0750 root root -"
      "d ${cfg.paths.incoming} 0750 root root -"
    ];

    containers."${cfg.container.name}" = {
      autoStart = true;
      ephemeral = true;
      privateNetwork = true;
      hostAddress = "192.168.101.1";
      localAddress = "192.168.101.2";
      forwardPorts = [
        {
          containerPort = cfg.container.port;
          hostPort = cfg.container.port;
          protocol = "tcp";
        }
      ];
      bindMounts."/incoming" = {
        hostPath = cfg.paths.incoming;
        isReadOnly = false;
      };

      config = { pkgs, ... }: {
        nix.enable = false;
        system.stateVersion = config.system.stateVersion;
        networking.firewall.allowedTCPPorts = [ cfg.container.port ];
        environment.systemPackages = [ pkgs.busybox ];

        environment.etc."httpd.conf".text = ''
          H:/www
          *.cgi:/bin/sh
        '';
        environment.etc."www/cgi-bin/upload.cgi" = {
          mode = "0755";
          text = ''
            #!/bin/sh
            name=$(printf '%s' "$QUERY_STRING" | sed -n 's/^name=//p' | tr -cd 'A-Za-z0-9._-')
            if [ -z "$name" ]; then
              printf 'Status: 400\r\n\r\nbad name\n'
              exit 0
            fi
            cat > "/incoming/$name"
            printf 'Status: 200\r\n\r\nok\n'
          '';
        };
        systemd.services.httpd = {
          description = "busybox uploader";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${lib.getExe pkgs.busybox} httpd -f -v -p ${toString cfg.container.port} -h /www -c /etc/httpd.conf";
            Restart = "on-failure";
          };
        };
      };
    };

    # batch complete : commit, apply, maybe reboot
    systemd.paths."fw-upload-commit" = {
      wantedBy = [ "multi-user.target" ];
      pathConfig.PathExists = "${cfg.paths.incoming}/${cfg.markerFile}";
    };
    systemd.services."fw-upload-commit" = {
      description = "commit uploaded update batch, apply, maybe reboot";
      serviceConfig.Type = "oneshot";
      path = [
        pkgs.coreutils
        config.systemd.package
      ];
      script = ''
        set -euo pipefail
        cd "${cfg.incomingDir}"
        for f in *; do
          [ "$f" = "${cfg.markerFile}" ] && continue
          mv -f -- "$f" "${cfg.paths.staging}/$f"
        done
        rm -f -- "${cfg.markerFile}"
        systemd-sysupdate update
        ${lib.optionalString cfg.autoReboot "systemctl reboot"}
      '';
    };
  };
}

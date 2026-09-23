# modules/image/push-update.nix
{
  modConfig,
  mkOptions,
  ...
}:
{
  config,
  lib,
  pkgs,
  ...
}:
with (modConfig config);
{
  options = mkOptions {
    paths = {
      incoming = lib.mkOption {
        description = "host dir, bind-mounted into container, receives raw uploads";
        default = "/var/lib/fw-upload/incoming";
        type = lib.types.path;
      };
      staging = lib.mkOption {
        description = "verified files, read by systemd-sysupdate";
        default = "/var/lib/fw-upload/staging";
        type = lib.types.path;
      };
      markerFile = lib.mkOption {
        description = "file name that signals an upload batch is complete";
        default = ".ready";
        type = lib.types.str;
      };
    };

    autoReboot = lib.mkOption {
      description = "reboot automatically after a successful update";
      default = true;
      type = lib.types.bool;
    };
    container = {
      name = lib.mkOption {
        default = "fw-upload";
        type = lib.types.str;
      };
      port = lib.mkOption {
        description = "port the uploader container listens on";
        default = 8888;
        type = lib.types.port;
      };
    };
  };

  config = mkIfEnable {
    systemd.sysupdate = {
      enable = true;

      transfers =
        let
          commonSource = {
            Type = "regular-file";
            Path = "/var/lib/fw-upload/staging";
          };
          Transfer.Verify = "yes";
        in
        {
          "10-nix-store" = {
            Source = commonSource // {
              MatchPattern = [ "${config.system.image.id}_@v.nix-store.raw.xz" ];
            };

            Target = {
              InstancesMax = 2;
              Path = "auto";
              MatchPattern = "nix-store_@v";
              Type = "partition";
              MatchPartitionType = "linux-generic";
              ReadOnly = "yes";
            };

            inherit Transfer;
          };

          "20-boot-image" = {
            Source = commonSource // {
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

    # host-side dirs, shared into the container by bind mount
    systemd.tmpfiles.rules = with cfg.paths; [
      "d ${incoming} 0750 root root -"
      "d ${staging}  0750 root root -"
    ];

    # isolated container running busybox httpd only
    containers."${cfg.container.name}" = {
      autoStart = true;
      ephemeral = true;
      privateNetwork = true;
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
        nix.daemon.enable = false;
        system.stateVersion = config.system.stateVersion;

        environment.systemPackages = [ pkgs.busybox ];

        environment.etc."httpd.conf".text = ''
          H:/www
          *.cgi:/bin/sh
        '';

        environment.etc."www/cgi-bin/upload.cgi" = {
          mode = "0755";
          text = ''
            #!/bin/sh
            # name comes from query string, sanitized to a safe charset
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

    # host side : batch complete -> commit, verify, apply, maybe reboot
    systemd.paths."fw-upload-commit" = {
      wantedBy = [ "multi-user.target" ];
      pathConfig.PathExists = with cfg.paths; "${incoming}/${markerFile}";
    };

    systemd.services."fw-upload-commit" = {
      description = "commit uploaded update batch, verify, apply, maybe reboot";
      serviceConfig.Type = "oneshot";
      path = [
        pkgs.coreutils
        config.systemd.package
      ];
      script = with cfg.paths; ''
        set -euo pipefail
        cd "${incoming}"
        for f in *; do
          [ "$f" = "${markerFile}" ] && continue
          mv -f -- "$f" "${staging}/$f"
        done
        rm -f -- "${markerFile}"
        systemd-sysupdate update
        ${lib.optionalString cfg.autoReboot "systemctl reboot"}
      '';
    };
  };
}

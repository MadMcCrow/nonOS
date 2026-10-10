# upload.nix
# web upload : isolated container receives files, host commits and applies
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
let
  inherit (mod) layout;
in
{
  options = mkOptions {
    incomingDir = lib.mkOption {
      description = "host dir, bind-mounted into the container, receives raw uploads";
      default = "/var/lib/fw-upload/incoming";
      type = lib.types.path;
    };
    markerFile = lib.mkOption {
      description = "file name that signals an upload batch is complete";
      default = ".ready";
      type = lib.types.str;
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
    systemd.tmpfiles.rules = [ "d ${cfg.incomingDir} 0750 root root -" ];

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
        hostPath = cfg.incomingDir;
        isReadOnly = false;
      };

      config =
        { pkgs, ... }:
        {
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
      pathConfig.PathExists = "${cfg.incomingDir}/${cfg.markerFile}";
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
          mv -f -- "$f" "${layout.stagingDir}/$f"
        done
        rm -f -- "${cfg.markerFile}"
        systemd-sysupdate update
        ${lib.optionalString cfg.autoReboot "systemctl reboot"}
      '';
    };
  };
}

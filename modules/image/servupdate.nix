# servupdate.nix
# create an address to drop updates to
{
  modConfig,
  mkOptions,
  ...
}:
{
  config,
  pkgs,
  lib,
  ...
}:
with (modConfig config);
{
  options = mkOptions {
    updateServer = {
      port = lib.mkOption {
        description = "TCP port to use for the update server";
        default = 8888;
        type = lib.types.port;
      };
    };
  };

  config = mkIfEnable {
    # NGINX is way overkill for that. a simpler http server (maybe nixos-containerized) would be simpler
    services.nginx = {
      enable = true;

      package = pkgs.nginx.override {
        modules = [ pkgs.nginxModules.dav ];
      };

      virtualHosts."update-server" = {
        listen = [
          {
            addr = "0.0.0.0";
            inherit (cfg) port;
          }
        ];

        locations."/upload/" = {
          root = "/var/lib/fw-upload";
          extraConfig = ''
            client_max_body_size 2g;
            client_body_timeout 30m;

            dav_methods PUT;
            dav_access user:rw;
            create_full_put_path off;

            # Do not expose uploaded files for reading.
            limit_except PUT {
              deny all;
            }
          '';
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];

    systemd.tmpfiles.rules = [
      "d /var/lib/fw-upload 0750 nginx nginx -"
      "d /var/lib/fw-upload/upload 0750 nginx nginx -"
      "d /var/lib/fw-upload/upload/incoming 0750 nginx nginx -"
    ];
  };
}

# combined.nix
# create a pipewire output that sends audio to all devices
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
    combinedOutput = {
      enable = lib.mkEnableOption "a virtual sink that routes to all outputs";
    };
  };

  config = mkIfEnable {
    services.pipewire = {
      enable = true;
      extraConfig.pipewire = {
        "10-combined-sink.conf" = {
          context.modules = [
            {
              name = "libpipewire-module-combine-stream";
              args = {
                node = {
                  name = "combined_sink";
                  description = "Combined Output";
                };
                combine = {
                  mode = "sink";
                  latency-compensate = false;
                  props = {
                    audio.position = [
                      "FL"
                      "FR"
                    ];
                  };
                };
                stream = {
                  props = { };
                  rules = [
                    {
                      matches = [
                        {
                          media.class = "Audio/Sink";
                        }
                      ];
                      actions = {
                        create-stream = {
                        };
                      };
                    }
                  ];
                };
              };
            }
          ];
        };
      };
    };
  };
}

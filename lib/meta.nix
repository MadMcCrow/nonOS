# wip version for the OS and the tools
# In the future, I'll figure a release
# and versionning schema
{
  lib,
  self,
  ...
}:
let
  date = builtins.substring 0 10 (
    builtins.replaceStrings [ "" ] [ "" ] (builtins.toString self.lastModified)
  );
  timestamp = self.lastModified or 0;
  day = builtins.substring 0 8 (self.lastModifiedDate or "19700101");

  tag = builtins.concatStringsSep "." [
    (builtins.substring 0 4 day)
    (builtins.substring 4 2 day)
    (builtins.substring 6 2 day)
  ];
in
{
  version = tag + (if self ? dirtyShortRev then "-dirty" else "");
  name = "nonOS";
  status = "dev";
  flake_url = "https://github.com/MadMcCrow/nonOS";
  licence = lib.licenses.mit;
}

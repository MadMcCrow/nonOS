# flake part module for creating profiles for re-using imports
# MAYBE: have a more "complex" profile type (an attrset with what to import, default values, descriptions)
args@{
  self,
  inputs,
  ...
}:
with self.nixosModules; {
    appliance = [ customization image security storage ];
    pc = [ audio customization desktop security storage unlock ];
    server = [ audio customization security storage unlock ];
  }

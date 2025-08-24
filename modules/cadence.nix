{ inputs, ... }:
{
  imports = [
    inputs.flake-file.flakeModules.dendritic
  ];

  flake-file.description = "Compact and Declarative Nix Config Elaborator";

}

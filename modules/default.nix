{
  flakeModules.default =
    { inputs, lib, ... }:
    {
      flake-file.inputs.home-manager.url = lib.mkDefault "github:nix-community/home-manager";

      perSystem =
        { system, ... }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config = {
              allowUnfreePredicate = _pkg: true;
            };
          };
        };

      imports = [
        inputs.flake-file.flakeModules.dendritic
        ./configurations.nix
        ./formatter.nix
        ./options.nix
        ./lib.nix
      ];
    };
}

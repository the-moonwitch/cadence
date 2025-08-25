{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  mkHostConfig =
    label:
    {
      features,
      primaryUser,
      class,
      hostname,
      system,
      ...
    }:
    let
      inherit (inputs.self.hosts.${label})
        features
        class
        hostname
        system
        primaryUser
        ;
      allFeatures = builtins.attrNames (inputs.self.dependencies // inputs.self.features);
      hostDeps =
        features
        ++ (lib.optional (lib.elem "base" allFeatures) "base")
        ++ (lib.optional (lib.elem label allFeatures) label);
      toKey =
        feature:
        assert
          lib.elem allFeatures feature
          || throw ''
            Undefined feature `${feature}` while resolving host `${label}`.
            Known features: [ ${builtins.concatStringsSep ", " allFeatures} ];
          '';
        {
          key = feature;
        };
      keys = builtins.genericClosure {
        startSet = builtins.map toKey hostDeps;
        operator = { key }: builtins.map toKey (inputs.self.dependencies.${key} or [ ]);
      };
      hostFeaturesAndTags = builtins.map ({ key }: key) keys;
      hostFeatures = builtins.filter (f: builtins.hasAttr f inputs.self.features) hostFeaturesAndTags;
      featureImpls = lib.flatten (
        builtins.map (f: builtins.removeAttrs inputs.self.features.${f} [ "extra" ]) hostFeatures
      );
      applicableImpls = builtins.filter (impl: impl.pred label) featureImpls;
      hostFeatureImpls = builtins.zipAttrsWith (_: values: values) applicableImpls;
      homeModule = {
        home-manager.users.${primaryUser}.imports = hostFeatureImpls.home;
      };
    in
    {
      nixosConfigurations.${if class == "nixos" then hostname else null} = pkgs.lib.nixosSystem {
        inherit system;
        specialArgs.host = label;
        modules = hostFeatureImpls.nixos ++ [
          inputs.home-manager.nixosModules.home-manager
          homeModule
        ];
      };
      darwinConfigurations.${if class == "darwin" then hostname else null} = pkgs.lib.darwinSystem {
        specialArgs.host = label;
        modules = hostFeatureImpls.darwin ++ [
          inputs.home-manager.darwinModules.home-manager
          homeModule
        ];
      };
      homeConfigurations."${primaryUser}@${hostname}" = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        extraSpecialArgs.host = label;
        modules = hostFeatureImpls.home;
      };
    };
  configs = builtins.zipAttrsWith (_: values: values) (
    builtins.map (label: mkHostConfig label) (builtins.attrNames inputs.self.hosts)
  );
in
{
  flake.nixosConfigurations = configs.nixosConfigurations;
  flake.darwinConfigurations = configs.darwinConfigurations;
  flake.homeConfigurations = configs.homeConfigurations;
}

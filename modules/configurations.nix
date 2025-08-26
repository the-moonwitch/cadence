{
  inputs,
  lib,
  config,
  ...
}:
let
  mkHostConfig =
    label: hostDef:
    let
      inherit (hostDef)
        features
        class
        hostname
        system
        username
        ;
      allFeatures = builtins.attrNames (config.cadence.dependencies // config.cadence.features);
      hostDeps =
        features
        ++ (lib.optional (lib.elem "base" allFeatures) "base")
        ++ (lib.optional (lib.elem label allFeatures) label);
      toKey =
        feature:
        assert
          lib.elem feature allFeatures
          || throw ''
            Undefined feature `${feature}` while resolving host `${label}`.
            Known features: [ ${builtins.concatStringsSep ", " allFeatures} ];
          '';
        {
          key = feature;
        };
      keys = builtins.genericClosure {
        startSet = builtins.map toKey hostDeps;
        operator = { key }: builtins.map toKey (config.cadence.dependencies.${key} or [ ]);
      };
      hostFeaturesAndTags = builtins.map ({ key }: key) keys;
      hostFeatures = builtins.filter (f: builtins.hasAttr f config.cadence.features) hostFeaturesAndTags;
      hostFeatureDefs = builtins.map (f: {
        name = f;
        value = config.cadence.features.${f};
      }) hostFeatures;
      featureImpls =
        featureLabel: impls:
        builtins.map (
          { name, value }:
          {
            featureName = featureLabel;
            implName = name;
            impl = value;
          }
        ) impls;
      hostFeatureImpls = lib.flatten (
        builtins.map (
          { name, value }: featureImpls name (lib.attrsToList (builtins.removeAttrs value [ "extra" ]))
        ) hostFeatureDefs
      );
      applicableImpls = builtins.filter (i: i.impl.pred label) hostFeatureImpls;
      homeModule = {
        home-manager.users.${username} = {
          imports = builtins.map (i: i.impl.home) applicableImpls;
        };
      };
    in
    {
      nixosConfigurations = {
        ${if class == "nixos" then hostname else null} = inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs.host = label;
          modules = (builtins.map (i: i.impl.nixos) applicableImpls) ++ [
            {
              nixpkgs.hostPlatform = system;
              networking.hostName = hostname;
            }
            inputs.home-manager.nixosModules.home-manager
            homeModule
          ];
        };
      };
      darwinConfigurations = {
        ${if class == "darwin" then hostname else null} = inputs.nixpkgs.lib.darwinSystem {
          specialArgs.host = label;
          modules = (builtins.map (i: i.impl.darwin) applicableImpls) ++ [
            inputs.home-manager.darwinModules.home-manager
            homeModule
          ];
        };
      };
      homeConfigurations = {
        "${username}@${hostname}" = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = inputs.nixpkgs.legacyPackages.${system};
          extraSpecialArgs.host = label;
          modules = (builtins.map (i: i.impl.home) applicableImpls);
        };
      };
    };

  # Handle the no-hostconfig case
  flake =
    builtins.foldl'
      (l: r: {
        nixosConfigurations = l.nixosConfigurations // r.nixosConfigurations;
        darwinConfigurations = l.darwinConfigurations // r.darwinConfigurations;
        homeConfigurations = l.homeConfigurations // r.homeConfigurations;
      })
      {
        nixosConfigurations = { };
        darwinConfigurations = { };
        homeConfigurations = { };
      }
      (lib.mapAttrsToList mkHostConfig config.cadence.hosts);
in
{
  inherit flake;
}

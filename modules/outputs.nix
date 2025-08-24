{ inputs, lib, ... }:
let
  hostsList = lib.attrsToList inputs.self.hosts;
  hostsByClass = builtins.groupBy (host: host.value.class) hostsList;
  nixosHosts = builtins.listToAttrs hostsByClass.nixos;
  darwinHosts = builtins.listToAttrs hostsByClass.darwin;
  homeHosts = builtins.listToAttrs hostsByClass.home-manager;

  mkHostConfig =
    label:
    { features, ... }:
    let
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
        startSet = builtins.map toKey hostDeclaredFeatures;
        operator = { key }: builtins.map toKey (inputs.self.dependencies.${key} or [ ]);
      };
      hostFeaturesAndTags = builtins.map ({ key }: key) keys;
      hostFeatures = builtins.filter (f: builtins.hasAttr f inputs.self.features) hostFeaturesAndTags;
      featureImpls = lib.flatten (
        builtins.map (f: builtins.removeAttrs inputs.self.features.${f} [ "extra" ]) hostFeatures
      );
      applicableImpls = builtins.filter (impl: impl.pred label) featureImpls;
      hostFeatureImpls =
        builtins.foldl'
          (acc: elem: {
            nixos = acc.nixos ++ [ elem.nixos ];
            darwin = acc.darwin ++ [ elem.darwin ];
            home = acc.home ++ [ elem.home ];
          })
          {
            nixos = [ ];
            darwin = [ ];
            home = [ ];
          }
          applicableImpls;
    in
    "TODO";
in
{
  flake.nixosConfigurations = "TODO";
  flake.darwinConfigurations = "TODO";
  flake.homeConfigurations = "TODO";
}

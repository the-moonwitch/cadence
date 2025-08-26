{
  config,
  lib,
  ...
}:
{
  options.cadence.lib = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
  };

  config.cadence.lib =
    let
      hostDef = hostKey: config.cadence.hosts.${hostKey};

      classFeature =
        class:
        let
          mkClassFeature =
            {
              system ? { },
              home ? { },
            }:
            {
              inherit home;
              pred = h: (hostDef h).class == class;
              ${class} = system;
            };
        in
        {
          system = mod: mkClassFeature { system = mod; };
          home = mod: mkClassFeature { home = mod; };
          __functor = _: mkClassFeature;
        };
      /**
        Define a feature that will only apply to a specific host.

        # Example

        ```nix
        features.hetznerSetup.def = (hostFeature "hetzner-vps").home {
          programs.fish.enable = true;
        };
        ```

        # Type

        ```
        hostFeature :: string -> module -> cadence.lib.types.featureImpl;
        ```

        # Arguments

        hostKey
        : The key of the host definition in `hosts`

        mod
        : The module definition to use for the host.
      */

      # TODO fix doc for functors
      hostFeature =
        hostKey:
        let
          def = hostDef hostKey;
          notSystemErr = "Host ${hostKey} is not a system host but tried to call `hostFeature.system \"${hostKey}\"`";
          pred = h: h == hostKey;
          systemKey = if def.class == "home-manager" then null else def.class;
        in
        {
          system =
            mod:
            if systemKey == null then
              throw notSystemErr
            else
              {
                inherit pred;
                ${systemKey} = mod;
              };
          home = mod: {
            inherit pred;
            home = mod;
          };
          __functor =
            _:
            {
              system ? { },
              home ? { },
            }:
            {
              inherit home pred;
              ${if systemKey == null && system != { } then throw notSystemErr else systemKey} = system;
            };
        };
      nixosFeature = classFeature "nixos";
      darwinFeature = classFeature "darwin";
      systemFeature = mod: {
        pred = hostKey: (hostDef hostKey).class != "home-manager";
        darwin = mod;
        nixos = mod;
      };
      homeFeature = mod: {
        pred = hostKey: (hostDef hostKey).class == "home-manager";
        home = mod;
      };
    in
    {
      inherit
        hostDef
        nixosFeature
        darwinFeature
        homeFeature
        hostFeature
        systemFeature
        ;
    };

}

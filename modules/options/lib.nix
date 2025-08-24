{ lib, inputs, ... }:
{
  flake.lib =
    let
      classFeature =
        class:
        let
          pred = h: (hostDef h).class == class;
        in
        mod: {
          system = {
            inherit pred;
            ${class} = mod;
          };
          home = mod: {
            inherit pred;
            home = mod;
          };
          __functor =
            {
              system ? { },
              home ? { },
            }:
            {
              inherit home pred;
              ${class} = system;
            };
        };

      hostDef = hostKey: inputs.self.hosts.${hostKey};
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
          notSystemErr = "Host ${hostKey} is not a system host but tried to call `hostFeature.system \"${hostKey}\"`";
          pred = h: h == hostKey;
          systemKey = if hostDef.class == "home-manager" then null else hostDef.class;
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
        ;
    };

}

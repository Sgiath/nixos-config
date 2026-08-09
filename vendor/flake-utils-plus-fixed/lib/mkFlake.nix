{ flake-utils-plus }:

{
  self,
  supportedSystems ? flake-utils-plus.lib.defaultSystems,
  inputs,
  channels ? { },
  channelsConfig ? { },
  sharedOverlays ? [ ],
  hosts ? { },
  hostDefaults ? {
    system = "x86_64-linux";
    modules = [ ];
    extraArgs = { };
  },
  outputsBuilder ? _: { },
  ...
}@args:

let
  inherit (flake-utils-plus.lib)
    eachSystem
    mergeAny
    patchChannel
    ;
  inherit (flake-utils-plus.lib.internal)
    filterAttrs
    partitionString
    reverseList
    ;
  inherit (builtins)
    attrNames
    attrValues
    concatMap
    concatStringsSep
    elemAt
    filter
    foldl'
    genList
    head
    isString
    length
    listToAttrs
    mapAttrs
    pathExists
    removeAttrs
    split
    tail
    ;

  srcs = filterAttrs (_: value: !value ? outputs) inputs;

  evalHostArgs =
    {
      channelName ? "nixpkgs",
      system ? "x86_64-linux",
      output ? "nixosConfigurations",
      builder ? (getChannels system).${channelName}.input.lib.nixosSystem,
      modules ? [ ],
      extraArgs ? { },
      specialArgs ? { },
    }:
    {
      inherit
        channelName
        system
        output
        builder
        extraArgs
        specialArgs
        ;
      modules = modules ++ [ ./options.nix ];
    };

  optionalAttrs = check: value: if check then value else { };

  otherArguments = removeAttrs args [
    "inputs"
    "hosts"
    "hostDefaults"
    "nixosProfiles"
    "channels"
    "channelsConfig"
    "self"
    "sharedOverlays"
    "supportedSystems"
    "outputsBuilder"
  ];

  getChannels = system: self.pkgs.${system};
  getNixpkgs = host: (getChannels host.system).${host.channelName};

  configurationBuilder =
    reverseDomainName: host':
    let
      dnsLabels = reverseList (partitionString "\\." reverseDomainName);
      hostname = head dnsLabels;
      domain =
        let
          domainLabels = tail dnsLabels;
        in
        if domainLabels == [ ] then lib.mkDefault null else concatStringsSep "." domainLabels;

      selectedNixpkgs = getNixpkgs host;
      host = evalHostArgs (mergeAny hostDefaults host');
      patchedChannel = selectedNixpkgs.path;
      channels = getChannels host.system;

      specialArgs = host.specialArgs // {
        channel = selectedNixpkgs;
      };

      lib = selectedNixpkgs.lib;
      baseModules = import (patchedChannel + "/nixos/modules/module-list.nix");
      nixosSpecialArgs =
        let
          f = channelName: {
            "${channelName}ModulesPath" = toString (channels.${channelName}.input + "/nixos/modules");
          };
        in
        (foldl' (lhs: rhs: lhs // rhs) { } (map f (attrNames channels)))
        // {
          modulesPath = toString (patchedChannel + "/nixos/modules");
        };
    in
    {
      ${host.output}.${reverseDomainName} = host.builder (
        {
          inherit (host) system;
          modules = [
            (
              {
                pkgs,
                lib,
                options,
                ...
              }:
              {
                _type = "merge";
                contents = [
                  (optionalAttrs (options ? networking.hostName) {
                    networking.hostName = hostname;
                  })

                  (optionalAttrs (options ? networking.domain) {
                    networking.domain = domain;
                  })

                  (
                    if options ? nixpkgs.pkgs then
                      {
                        nixpkgs = {
                          config = selectedNixpkgs.__flakeUtilsPlus.channelConfig;
                          overlays = selectedNixpkgs.__flakeUtilsPlus.channelOverlays;
                        };
                      }
                    else
                      { }
                  )

                  (optionalAttrs (options ? system.configurationRevision) {
                    system.configurationRevision = lib.mkIf (self ? rev) self.rev;
                  })

                  (optionalAttrs (options ? nix.package) {
                    nix.package = lib.mkDefault pkgs.nixVersions.latest;
                  })

                  (optionalAttrs (options ? nix.extraOptions) {
                    nix.extraOptions = "extra-experimental-features = nix-command flakes";
                  })

                  {
                    _module.args =
                      (optionalAttrs (host.output != "darwinConfigurations") { inherit inputs; }) // host.extraArgs;
                  }
                ];
              }
            )
          ]
          ++ host.modules;
          inherit specialArgs;
        }
        // (optionalAttrs (host.output == "darwinConfigurations") {
          inherit inputs;
          pkgs = selectedNixpkgs;
        })
        // (optionalAttrs (host.output == "nixosConfigurations") {
          inherit lib baseModules;
          specialArgs = nixosSpecialArgs // specialArgs;
        })
      );
    };
in
mergeAny otherArguments (
  eachSystem supportedSystems (
    system:
    let
      filterAttrs =
        pred: set:
        listToAttrs (
          concatMap (
            name:
            let
              value = set.${name};
            in
            if pred name value then [ { inherit name value; } ] else [ ]
          ) (attrNames set)
        );

      channelFlakes = filterAttrs (
        _: value:
        value ? legacyPackages
        && value.legacyPackages ? x86_64-linux
        && value.legacyPackages.x86_64-linux ? nix
      ) inputs;
      channelsFromFlakes = mapAttrs (name: input: { inherit input; }) channelFlakes;

      importChannel =
        name: value:
        let
          channelSource = patchChannel system value.input (value.patches or [ ]);
          channelOverlays = [
            (final: prev: {
              __dontExport = true;
              inherit srcs;
            })
          ]
          ++ sharedOverlays
          ++ (if value ? overlaysBuilder then value.overlaysBuilder pkgs else [ ])
          ++ [ flake-utils-plus.overlay ];
          channelConfig = channelsConfig // (value.config or { });
        in
        (import channelSource {
          inherit system;
          overlays = channelOverlays;
          config = channelConfig;
        })
        // {
          inherit name;
          inherit (value) input;
          __flakeUtilsPlus = {
            inherit channelConfig channelOverlays;
          };
        };

      pkgs = mapAttrs importChannel (mergeAny channelsFromFlakes channels);

      systemOutputs = outputsBuilder pkgs;

      mkOutputs =
        attrs: output:
        attrs
        //
          mergeAny
            (optionalAttrs (otherArguments ? ${output}.${system}) {
              ${output} = otherArguments.${output}.${system};
            })
            (
              optionalAttrs (systemOutputs ? ${output}) {
                ${output} = systemOutputs.${output};
              }
            );
    in
    { inherit pkgs; } // (foldl' mkOutputs { } (attrNames systemOutputs))
  )
  // foldl' mergeAny { } (attrValues (mapAttrs configurationBuilder hosts))
)

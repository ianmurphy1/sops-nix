{ lib, options, config, pkgs, ... }:
let
  cfg = config.sops;
  secretsForUsers = lib.filterAttrs (_: v: v.neededForUsers) cfg.secrets;
  manifestFor = pkgs.callPackage ../manifest-for.nix {
    inherit cfg;
    inherit (pkgs) writeTextFile;
  };
  withEnvironment = import ../with-environment.nix {
    inherit cfg lib;
  };
  manifestForUsers = manifestFor "-for-users" secretsForUsers {
    secretsMountPoint = "/run/secrets-for-users.d";
    symlinkPath = "/run/secrets-for-users";
  };
in
{

  assertions = [{
    assertion = (lib.filterAttrs (_: v: (v.uid != 0 && v.owner != "root") || (v.gid != 0 && v.group != "root")) secretsForUsers) == { };
    message = "neededForUsers cannot be used for secrets that are not root-owned";
  }];

  system.activationScripts =  {
    postActivation.text = lib.mkAfter ''
      echo Setting up secrets for users...
      ${withEnvironment "${cfg.package}/bin/sops-install-secrets -ignore-passwd ${manifestForUsers}"}
    '';
    }; 

  system.build.sops-nix-users-manifest = manifestForUsers;
}

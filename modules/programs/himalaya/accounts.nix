pkgs:
{ lib, ... }:

let
  inherit (lib) mkEnableOption mkOption types;
  tomlFormat = pkgs.formats.toml { };

in
{
  options.himalaya = {
    enable = mkEnableOption "Himalaya CLI for this email account";

    settings = mkOption {
      type = types.submodule { freeformType = tomlFormat.type; };
      default = { };
      description = ''
        Himalaya CLI configuration for this email account, merged over the
        one the module derives from the account.
        See <https://github.com/pimalaya/himalaya/blob/master/config.sample.toml> for supported values.
      '';
    };
  };
}

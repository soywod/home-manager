{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    attrNames
    filterAttrs
    mapAttrs
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.programs.cardamum;
  tomlFormat = pkgs.formats.toml { };
  settingsType = types.submodule { freeformType = tomlFormat.type; };

  enabledAccounts = filterAttrs (
    _: account: account.cardamum.enable
  ) config.accounts.contact.accounts;

in
{
  meta.maintainers = with lib.maintainers; [ soywod ];

  options = {
    programs.cardamum = {
      enable = mkEnableOption "Cardamum, a CLI to manage contacts";

      package = lib.mkPackageOption pkgs "cardamum" { nullable = true; };

      settings = mkOption {
        type = settingsType;
        default = { };
        example = lib.literalExpression ''
          {
            card.list.page-size = 50;

            accounts.personal = {
              default = true;
              addressbook.default = "contacts";
              carddav = {
                server = "https://dav.example.org/";
                auth.basic = {
                  username = "alice@example.org";
                  password.command = [ "pass" "show" "carddav" ];
                };
              };
            };
          }
        '';
        description = ''
          Cardamum configuration, written to
          {file}`$XDG_CONFIG_HOME/cardamum/config.toml`.

          The accounts enabled through
          {option}`accounts.contact.accounts.<name>.cardamum.enable` are
          merged into `accounts`.

          Beware that the generated file lands in the world-readable Nix
          store, so read secrets through a command rather than inlining them.

          See <https://github.com/pimalaya/cardamum/blob/master/config.sample.toml>
          for supported values.
        '';
      };
    };

    accounts.contact.accounts = mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, config, ... }:
          {
            options.cardamum = {
              enable = mkEnableOption "Cardamum for this contact account";

              settings = mkOption {
                type = settingsType;
                default = { };
                example = lib.literalExpression ''
                  {
                    default = true;
                    addressbook.default = "contacts";
                  }
                '';
                description = ''
                  Cardamum configuration of this contact account, merged into
                  `accounts.<name>` of {option}`programs.cardamum.settings`.

                  A `carddav` remote fills the `carddav` table: `server` from
                  its URL and, when it carries both a user name and a password
                  command, `auth.basic`. An account with no such remote reads
                  its local `filesystem` storage through the `vdir` table. The
                  account is marked `default` when it is the only one enabled.
                  Each value is a default that a definition here overrides.
                '';
              };
            };

            config.cardamum.settings =
              let
                inherit (config) local remote;
                carddav = remote != null && remote.type == "carddav" && remote.url != null;
              in
              mkMerge [
                (mkIf (attrNames enabledAccounts == [ name ]) { default = mkDefault true; })

                (mkIf carddav {
                  carddav = {
                    server = mkDefault remote.url;
                    auth = mkIf (remote.userName != null && remote.passwordCommand != null) (mkDefault {
                      basic = {
                        username = remote.userName;
                        password.command = remote.passwordCommand;
                      };
                    });
                  };
                })

                (mkIf (!carddav && local.type == "filesystem") { vdir.root = mkDefault local.path; })
              ];
          }
        )
      );
    };
  };

  config = mkIf cfg.enable {
    home.packages = mkIf (cfg.package != null) [ cfg.package ];

    programs.cardamum.settings.accounts = mkIf (enabledAccounts != { }) (
      mapAttrs (_: account: account.cardamum.settings) enabledAccounts
    );

    xdg.configFile."cardamum/config.toml" = mkIf (cfg.settings != { }) {
      source = tomlFormat.generate "cardamum-config.toml" cfg.settings;
    };
  };
}

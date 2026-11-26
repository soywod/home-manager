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

  cfg = config.programs.calendula;
  tomlFormat = pkgs.formats.toml { };
  settingsType = types.submodule { freeformType = tomlFormat.type; };

  enabledAccounts = filterAttrs (
    _: account: account.calendula.enable
  ) config.accounts.calendar.accounts;

in
{
  meta.maintainers = with lib.maintainers; [ soywod ];

  options = {
    programs.calendula = {
      enable = mkEnableOption "Calendula, a CLI to manage calendars";

      package = lib.mkPackageOption pkgs "calendula" { nullable = true; };

      settings = mkOption {
        type = settingsType;
        default = { };
        example = lib.literalExpression ''
          {
            event.list.page-size = 50;

            accounts.personal = {
              default = true;
              calendar.default = "personal";
              caldav = {
                server = "https://dav.example.org/";
                auth.basic = {
                  username = "alice@example.org";
                  password.command = [ "pass" "show" "caldav" ];
                };
              };
            };
          }
        '';
        description = ''
          Calendula configuration, written to
          {file}`$XDG_CONFIG_HOME/calendula/config.toml`.

          The accounts enabled through
          {option}`accounts.calendar.accounts.<name>.calendula.enable` are
          merged into `accounts`.

          Beware that the generated file lands in the world-readable Nix
          store, so read secrets through a command rather than inlining them.

          See <https://github.com/pimalaya/calendula/blob/master/config.sample.toml>
          for supported values.
        '';
      };
    };

    accounts.calendar.accounts = mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, config, ... }:
          {
            options.calendula = {
              enable = mkEnableOption "Calendula for this calendar account";

              settings = mkOption {
                type = settingsType;
                default = { };
                example = lib.literalExpression ''
                  {
                    default = true;
                    calendar.default = "work";
                  }
                '';
                description = ''
                  Calendula configuration of this calendar account, merged into
                  `accounts.<name>` of {option}`programs.calendula.settings`.

                  A `caldav` remote fills the `caldav` table: `server` from
                  its URL and, when it carries both a user name and a password
                  command, `auth.basic`. An account with no such remote reads
                  its local `filesystem` storage through the `vdir` table. The
                  account is marked `default` when it is primary or the only
                  one enabled, and its primary collection is the
                  `calendar.default` the event commands take. Each value is a
                  default that a definition here overrides.
                '';
              };
            };

            config.calendula.settings =
              let
                inherit (config) local remote;
                caldav = remote != null && remote.type == "caldav" && remote.url != null;
              in
              mkMerge [
                (mkIf (config.primary || attrNames enabledAccounts == [ name ]) {
                  default = mkDefault true;
                })

                (mkIf (config.primaryCollection != null) {
                  calendar.default = mkDefault config.primaryCollection;
                })

                (mkIf caldav {
                  caldav = {
                    server = mkDefault remote.url;
                    auth = mkIf (remote.userName != null && remote.passwordCommand != null) (mkDefault {
                      basic = {
                        username = remote.userName;
                        password.command = remote.passwordCommand;
                      };
                    });
                  };
                })

                (mkIf (!caldav && local.type == "filesystem") { vdir.root = mkDefault local.path; })
              ];
          }
        )
      );
    };
  };

  config = mkIf cfg.enable {
    home.packages = mkIf (cfg.package != null) [ cfg.package ];

    programs.calendula.settings.accounts = mkIf (enabledAccounts != { }) (
      mapAttrs (_: account: account.calendula.settings) enabledAccounts
    );

    xdg.configFile."calendula/config.toml" = mkIf (cfg.settings != { }) {
      source = tomlFormat.generate "calendula-config.toml" cfg.settings;
    };
  };
}

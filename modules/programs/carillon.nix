{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    attrNames
    concatStringsSep
    elem
    filterAttrs
    mapAttrs
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    optionalAttrs
    types
    ;

  cfg = config.programs.carillon;
  tomlFormat = pkgs.formats.toml { };
  settingsType = types.submodule { freeformType = tomlFormat.type; };

  enabledAccounts = filterAttrs (
    _: account: account.enable && account.carillon.enable
  ) config.accounts.email.accounts;

  imapAccounts = filterAttrs (_: account: account.imap != null) enabledAccounts;

  # The field each SASL mechanism carries the secret in, null for none.
  sasl = {
    anonymous = null;
    login = "password";
    oauthbearer = "token";
    plain = "password";
    "scram-sha-256" = "password";
    xoauth2 = "token";
  };

  supportedSasl = attrNames sasl;

  unsupportedSasl = attrNames (
    filterAttrs (
      _: account: account.imap.authentication != null && !elem account.imap.authentication supportedSasl
    ) imapAccounts
  );

  unnamedSasl = attrNames (
    filterAttrs (
      _: account: account.imap.authentication == null && account.passwordCommand != null
    ) imapAccounts
  );

in
{
  meta.maintainers = with lib.maintainers; [ soywod ];

  options = {
    programs.carillon = {
      enable = mkEnableOption "Carillon, a CLI to watch PIM collection changes";

      package = lib.mkPackageOption pkgs "carillon" { nullable = true; };

      settings = mkOption {
        type = settingsType;
        default = { };
        example = lib.literalExpression ''
          {
            accounts.personal = {
              default = true;
              maildir = {
                root = "~/Mail/personal";
                mailbox = "INBOX";
                hooks.on-message-add.notify = {
                  summary = "New mail from $sender";
                  body = "$subject";
                };
              };
            };
          }
        '';
        description = ''
          Carillon configuration, written to
          {file}`$XDG_CONFIG_HOME/carillon/config.toml`.

          Each account watches one collection per backend, and fires the
          hooks its backend table declares on every change. The accounts
          enabled through
          {option}`accounts.email.accounts.<name>.carillon.enable` are
          merged into `accounts`.

          Beware that the generated file lands in the world-readable Nix
          store, so read secrets through a command rather than inlining them.

          See <https://github.com/pimalaya/carillon/blob/master/config.sample.toml>
          for supported values.
        '';
      };
    };

    accounts.email.accounts = mkOption {
      type = types.attrsOf (
        types.submodule (
          { config, ... }:
          {
            options.carillon = {
              enable = mkEnableOption "Carillon for this email account";

              settings = mkOption {
                type = settingsType;
                default = { };
                example = lib.literalExpression ''
                  {
                    imap.hooks.on-message-add.notify.summary =
                      "New mail in $mailbox from $sender";
                  }
                '';
                description = ''
                  Carillon configuration of this email account, merged into
                  `accounts.<name>` of {option}`programs.carillon.settings`.

                  The account's IMAP settings fill the `imap` table, which
                  watches the inbox folder, the password command reaching the
                  SASL mechanism named by
                  {option}`accounts.email.accounts.<name>.imap.authentication`.
                  The account is marked `default` when primary. Each value is
                  a default that a definition here overrides, the hooks being
                  left to it.
                '';
              };
            };

            config.carillon.settings =
              let
                inherit (config) imap passwordCommand userName;
                starttls = imap.tls.enable && imap.tls.useStartTls;
                scheme = if imap.tls.enable && !starttls then "imaps" else "imap";
                authority = if imap.port == null then imap.host else "${imap.host}:${toString imap.port}";
                mechanism = imap.authentication;
                field = sasl.${mechanism} or null;
                usable = field == null || passwordCommand != null;
              in
              {
                default = mkIf config.primary (mkDefault true);
                imap = mkIf (imap != null) {
                  mailbox = mkDefault config.folders.inbox;
                  server = mkDefault "${scheme}://${authority}";
                  starttls = mkDefault starttls;
                  sasl = mkIf (mechanism != null && usable) (mkDefault {
                    ${mechanism} = optionalAttrs (field != null) {
                      username = userName;
                      ${field}.command = concatStringsSep " " passwordCommand;
                    };
                  });
                };
              };
          }
        )
      );
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = unsupportedSasl == [ ];
        message = ''
          Carillon speaks the ${concatStringsSep ", " supportedSasl} SASL
          mechanisms; these accounts ask for one it does not implement:
          ${concatStringsSep ", " unsupportedSasl}.
        '';
      }
      {
        assertion = unnamedSasl == [ ];
        message = ''
          Carillon negotiates no SASL mechanism, so an account carrying a
          password command has to name the one to send it with. Set
          accounts.email.accounts.<name>.imap.authentication to one of
          ${concatStringsSep ", " supportedSasl} on:
          ${concatStringsSep ", " unnamedSasl}.
        '';
      }
    ];

    home.packages = mkIf (cfg.package != null) [ cfg.package ];

    programs.carillon.settings.accounts = mkIf (enabledAccounts != { }) (
      mapAttrs (_: account: account.carillon.settings) enabledAccounts
    );

    xdg.configFile."carillon/config.toml" = mkIf (cfg.settings != { }) {
      source = tomlFormat.generate "carillon-config.toml" cfg.settings;
    };
  };
}

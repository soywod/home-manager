{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    attrNames
    concatMap
    concatStringsSep
    elem
    filterAttrs
    mapAttrs
    mapAttrsToList
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optionalAttrs
    types
    ;

  cfg = config.programs.neverest;
  tomlFormat = pkgs.formats.toml { };

  emailAccounts = filterAttrs (
    _: account: account.enable && account.neverest.enable
  ) config.accounts.email.accounts;

  contactAccounts = filterAttrs (
    _: account: account.neverest.enable
  ) config.accounts.contact.accounts;

  calendarAccounts = filterAttrs (
    _: account: account.neverest.enable
  ) config.accounts.calendar.accounts;

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

  saslValidator =
    pred:
    concatMap
      (
        protocol:
        mapAttrsToList (name: _: "${name}.${protocol}") (
          filterAttrs (_: account: account.${protocol} != null && pred protocol account) emailAccounts
        )
      )
      [
        "imap"
        "smtp"
      ];

  unsupportedSasl = saslValidator (
    protocol: account:
    account.${protocol}.authentication != null && !elem account.${protocol}.authentication supportedSasl
  );

  unnamedSasl = saslValidator (
    protocol: account: account.${protocol}.authentication == null && account.passwordCommand != null
  );

  settingsType = types.submodule { freeformType = tomlFormat.type; };

  mkMailSettings =
    protocol: account:
    let
      transport = account.${protocol};
      starttls = transport.tls.enable && transport.tls.useStartTls;
      scheme = if transport.tls.enable && !starttls then "${protocol}s" else protocol;
      authority =
        if transport.port == null then transport.host else "${transport.host}:${toString transport.port}";
      mechanism = transport.authentication;
      field = sasl.${mechanism} or null;
      usable = field == null || account.passwordCommand != null;
    in
    {
      server = mkDefault "${scheme}://${authority}";
      starttls = mkDefault starttls;
      sasl = mkIf (mechanism != null && usable) (mkDefault {
        ${mechanism} = optionalAttrs (field != null) {
          username = account.userName;
          ${field}.command = concatStringsSep " " account.passwordCommand;
        };
      });
    };

  mkDavAccounts =
    protocol: kind:
    types.attrsOf (
      types.submodule (
        { config, ... }:
        {
          options.neverest = {
            enable = mkEnableOption "the synchronization of this ${kind} account by Neverest";

            settings = mkOption {
              type = settingsType;
              default = { };
              description = ''
                Neverest configuration of this ${kind} account, merged into
                {option}`programs.neverest.settings.accounts.<name>`.

                A `${protocol}` remote fills the `${protocol}` table: `server`
                from its URL and, when it carries both a user name and a
                password command, `auth.basic`. Each value is a default that
                a definition here overrides.
              '';
            };
          };

          config.neverest.settings =
            let
              inherit (config) remote;
            in
            mkIf (remote != null && remote.type == protocol && remote.url != null) {
              ${protocol} = {
                server = mkDefault remote.url;
                auth = mkIf (remote.userName != null && remote.passwordCommand != null) (mkDefault {
                  basic = {
                    username = remote.userName;
                    password.command = remote.passwordCommand;
                  };
                });
              };
            };
        }
      )
    );

in
{
  meta.maintainers = with lib.maintainers; [ soywod ];

  options = {
    programs.neverest = {
      enable = mkEnableOption "Neverest, a CLI to synchronize mails, contacts and calendars";

      package = lib.mkPackageOption pkgs "neverest" { nullable = true; };

      settings = mkOption {
        type = settingsType;
        default = { };
        example = lib.literalExpression ''
          {
            contact.merger = "tcard merge {base} {local} {remote} --output {output}";

            accounts.personal = {
              mail.filter.since = "30d";
              imap = {
                server = "imap.example.org";
                sasl.plain = {
                  username = "alice@example.org";
                  password.command = "pass show mail/personal";
                };
                collection.filter.include = [ "INBOX" "Sent" ];
              };
            };
          }
        '';
        description = ''
          Neverest configuration, written to
          {file}`$XDG_CONFIG_HOME/neverest/config.toml`.

          The accounts enabled through
          {option}`accounts.email.accounts.<name>.neverest.enable`,
          {option}`accounts.contact.accounts.<name>.neverest.enable` and
          {option}`accounts.calendar.accounts.<name>.neverest.enable` are
          merged into `accounts`, one Neverest account per name: an email, a
          contact and a calendar account sharing a name sync as one account.

          Beware that the generated file lands in the world-readable Nix
          store, so read secrets through a command rather than inlining them.

          See <https://github.com/pimalaya/neverest/blob/master/config.sample.toml>
          for supported values.
        '';
      };
    };

    accounts.email.accounts = mkOption {
      type = types.attrsOf (
        types.submodule (
          { config, ... }:
          {
            options.neverest = {
              enable = mkEnableOption "the synchronization of this email account by Neverest";

              settings = mkOption {
                type = settingsType;
                default = { };
                description = ''
                  Neverest configuration of this email account, merged into
                  {option}`programs.neverest.settings.accounts.<name>`.

                  The account's IMAP and SMTP settings fill the `imap` and
                  `smtp` tables, the password command reaching the SASL
                  mechanism named by
                  {option}`accounts.email.accounts.<name>.imap.authentication`
                  and
                  {option}`accounts.email.accounts.<name>.smtp.authentication`.
                  Each value is a default that a definition here overrides.
                '';
              };
            };

            config.neverest.settings = mkMerge [
              (mkIf (config.imap != null) { imap = mkMailSettings "imap" config; })
              (mkIf (config.smtp != null) { smtp = mkMailSettings "smtp" config; })
            ];
          }
        )
      );
    };

    accounts.contact.accounts = mkOption { type = mkDavAccounts "carddav" "contact"; };

    accounts.calendar.accounts = mkOption { type = mkDavAccounts "caldav" "calendar"; };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = unsupportedSasl == [ ];
        message = ''
          Neverest speaks the ${concatStringsSep ", " supportedSasl} SASL
          mechanisms; these accounts ask for one it does not implement:
          ${concatStringsSep ", " unsupportedSasl}.
        '';
      }
      {
        assertion = unnamedSasl == [ ];
        message = ''
          Neverest negotiates no SASL mechanism, so an account carrying a
          password command has to name the one to send it with. Set
          accounts.email.accounts.<name>.<protocol>.authentication to one of
          ${concatStringsSep ", " supportedSasl} on:
          ${concatStringsSep ", " unnamedSasl}.
        '';
      }
    ];

    home.packages = mkIf (cfg.package != null) [ cfg.package ];

    programs.neverest.settings.accounts =
      let
        settingsOf = mapAttrs (_: account: account.neverest.settings);
      in
      mkIf (emailAccounts != { } || contactAccounts != { } || calendarAccounts != { }) (mkMerge [
        (settingsOf emailAccounts)
        (settingsOf contactAccounts)
        (settingsOf calendarAccounts)
      ]);

    xdg.configFile."neverest/config.toml" = mkIf (cfg.settings != { }) {
      source = tomlFormat.generate "neverest-config.toml" cfg.settings;
    };
  };
}

{
  imports = [ ../../accounts/email-test-accounts.nix ];

  accounts.email.accounts = {
    "hm@example.com" = {
      imap.port = 993;
      imap.authentication = "login";
      smtp.authentication = "xoauth2";
      neverest.enable = true;
    };

    # STARTTLS on SMTP, and a definition overriding a derived value
    hm-account = {
      imap.authentication = "plain";
      smtp.authentication = "plain";
      neverest = {
        enable = true;
        settings = {
          imap.server = "imap.example.org:1993";
          mail.filter.since = "30d";
        };
      };
    };
  };

  # sharing its name with an email account, it syncs as the same account
  accounts.contact = {
    basePath = "/home/hm-user/contacts";
    accounts."hm@example.com" = {
      remote = {
        type = "carddav";
        url = "https://dav.example.com/";
        userName = "home.manager";
        passwordCommand = [
          "pass"
          "show"
          "carddav"
        ];
      };
      neverest.enable = true;
    };
  };

  # no credential: the server asks for none
  accounts.calendar = {
    basePath = "/home/hm-user/calendars";
    accounts.calendars = {
      remote = {
        type = "caldav";
        url = "https://dav.example.com/calendars/";
      };
      neverest = {
        enable = true;
        settings.calendar.merger = "my-tcal {base} {local} {remote} --output {output}";
      };
    };
  };

  programs.neverest = {
    enable = true;
    settings.contact.merger = "tcard merge {base} {local} {remote} --output {output}";
  };

  nmt.script = ''
    assertFileExists home-files/.config/neverest/config.toml
    assertFileContent home-files/.config/neverest/config.toml ${./accounts-expected.toml}
  '';
}

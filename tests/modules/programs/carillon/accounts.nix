{
  imports = [ ../../accounts/email-test-accounts.nix ];

  test.stubs.carillon = { };

  accounts.email.accounts = {
    "hm@example.com" = {
      imap.port = 993;
      imap.authentication = "xoauth2";
      carillon = {
        enable = true;
        settings.imap.hooks.on-message-add.notify = {
          summary = "New mail from $sender";
          body = "$subject";
        };
      };
    };

    # a definition overriding a derived value
    hm-account = {
      imap.authentication = "plain";
      folders.inbox = "INBOX";
      carillon = {
        enable = true;
        settings.imap = {
          mailbox = "Archive";
          watch.poll.interval = "5m";
          hooks.on-message-add.command = "true";
        };
      };
    };
  };

  # an account the email accounts do not describe
  programs.carillon = {
    enable = true;
    settings.accounts.local.maildir = {
      root = "~/Mail/local";
      mailbox = "INBOX";
      hooks.on-flag-add.command = "true";
    };
  };

  nmt.script = ''
    assertFileExists home-files/.config/carillon/config.toml
    assertFileContent home-files/.config/carillon/config.toml ${./accounts-expected.toml}
  '';
}

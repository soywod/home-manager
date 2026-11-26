{
  test.stubs.carillon = {
    name = "carillon";
  };

  programs.carillon = {
    enable = true;
    package = null;
    settings.accounts.local.maildir = {
      root = "~/Mail";
      mailbox = "INBOX";
    };
  };

  services.carillon.enable = true;

  nmt.script = ''
    serviceFile=home-files/.config/systemd/user/carillon.service
    assertFileContent "$(normalizeStorePaths "$serviceFile")" ${./expected.service}

    # the service restarts when the configuration it read changes
    configFile=$(readlink -f "$TESTED/home-files/.config/carillon/config.toml")
    assertFileContains "$serviceFile" "X-Restart-Triggers=$configFile"
  '';
}

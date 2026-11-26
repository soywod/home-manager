{
  test.stubs.calendula = { };

  # the only account enabled is the default one, primary or not
  accounts.calendar = {
    basePath = "/home/hm-user/calendars";
    accounts.personal = {
      remote = {
        type = "caldav";
        url = "https://dav.example.com/calendars/";
      };
      calendula.enable = true;
    };
  };

  programs.calendula.enable = true;

  nmt.script = ''
    assertFileContent home-files/.config/calendula/config.toml ${./single-account-expected.toml}
  '';
}

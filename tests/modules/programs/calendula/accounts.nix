{
  test.stubs.calendula = { };

  accounts.calendar = {
    basePath = "/home/hm-user/calendars";
    accounts = {
      personal = {
        primary = true;
        primaryCollection = "work";
        remote = {
          type = "caldav";
          url = "https://dav.example.com/calendars/";
          userName = "home.manager";
          passwordCommand = [
            "pass"
            "show"
            "caldav"
          ];
        };
        calendula = {
          enable = true;
          settings.event.composer = [
            "tcal"
            "edit"
          ];
        };
      };

      # no caldav remote: read the local vdir another tool syncs
      synced = {
        remote = {
          type = "http";
          url = "https://example.com/holidays.ics";
        };
        calendula.enable = true;
      };

      ignored.remote = {
        type = "caldav";
        url = "https://dav.example.com/calendars/";
      };
    };
  };

  programs.calendula = {
    enable = true;
    settings.event.list.page-size = 50;
  };

  nmt.script = ''
    assertFileExists home-files/.config/calendula/config.toml
    assertFileContent home-files/.config/calendula/config.toml ${./accounts-expected.toml}
  '';
}

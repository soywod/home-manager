{
  test.stubs.cardamum = { };

  accounts.contact = {
    basePath = "/home/hm-user/contacts";
    accounts = {
      personal = {
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
        cardamum = {
          enable = true;
          settings = {
            default = true;
            addressbook.default = "contacts";
          };
        };
      };

      # no carddav remote: read the local vdir another tool syncs
      synced = {
        remote = {
          type = "http";
          url = "https://example.com/contacts.vcf";
        };
        cardamum.enable = true;
      };

      ignored.remote = {
        type = "carddav";
        url = "https://dav.example.com/";
      };
    };
  };

  programs.cardamum = {
    enable = true;
    settings.card.list.page-size = 50;
  };

  nmt.script = ''
    assertFileExists home-files/.config/cardamum/config.toml
    assertFileContent home-files/.config/cardamum/config.toml ${./accounts-expected.toml}
  '';
}

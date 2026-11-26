{
  test.stubs.cardamum = { };

  # the only account enabled is the default one
  accounts.contact = {
    basePath = "/home/hm-user/contacts";
    accounts.personal = {
      remote = {
        type = "carddav";
        url = "https://dav.example.com/";
      };
      cardamum.enable = true;
    };
  };

  programs.cardamum.enable = true;

  nmt.script = ''
    assertFileContent home-files/.config/cardamum/config.toml ${./single-account-expected.toml}
  '';
}

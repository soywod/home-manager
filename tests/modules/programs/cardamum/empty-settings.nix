{
  programs.cardamum = {
    enable = true;
    package = null;
  };

  nmt.script = ''
    assertPathNotExists home-files/.config/cardamum
  '';
}

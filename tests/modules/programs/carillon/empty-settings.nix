{
  programs.carillon = {
    enable = true;
    package = null;
  };

  nmt.script = ''
    assertPathNotExists home-files/.config/carillon
  '';
}

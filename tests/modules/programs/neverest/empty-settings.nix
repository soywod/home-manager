{
  programs.neverest = {
    enable = true;
    package = null;
  };

  nmt.script = ''
    assertPathNotExists home-files/.config/neverest
  '';
}

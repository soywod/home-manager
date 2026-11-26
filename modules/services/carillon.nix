{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.carillon;
  program = config.programs.carillon;
  tomlFormat = pkgs.formats.toml { };

in
{
  meta.maintainers = with lib.maintainers; [ soywod ];

  options.services.carillon = {
    enable = lib.mkEnableOption "the Carillon watcher, firing the hooks of every configured account";

    package = lib.mkPackageOption pkgs "carillon" { };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      (lib.hm.assertions.assertPlatform "services.carillon" pkgs lib.platforms.linux)
    ];

    systemd.user.services.carillon = {
      Unit = {
        Description = "Carillon PIM watcher";
        # Carillon reads its configuration once, at start.
        X-Restart-Triggers = lib.mkIf (program.enable && program.settings != { }) [
          "${tomlFormat.generate "carillon-config.toml" program.settings}"
        ];
      };

      Install.WantedBy = [ "default.target" ];

      Service = {
        ExecStart = "${lib.getExe cfg.package} watch";
        Restart = "on-failure";
        RestartSec = 10;
      };
    };
  };
}

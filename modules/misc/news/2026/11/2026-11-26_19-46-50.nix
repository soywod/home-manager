{
  time = "2026-11-26T19:46:50+00:00";
  message = ''
    New modules are available: 'programs.carillon' and 'services.carillon'.

    Carillon is a CLI to watch mails, contacts and calendars, firing a
    command or a desktop notification on every change, every event alarm
    and every contact birthday. An email account is watched through
    'accounts.email.accounts.<name>.carillon.enable', which fills its
    IMAP settings, and 'services.carillon' runs the watcher as a systemd
    user service on Linux.

    See https://github.com/pimalaya/carillon for more.
  '';
}

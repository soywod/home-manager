{ config, ... }:
{
  time = "2026-11-26T19:39:14+00:00";
  condition = config.programs.himalaya.enable;
  message = ''
    The 'programs.himalaya' module now targets Himalaya CLI 3, which brings
    breaking changes to its configuration.

    Himalaya 3 refuses a key it does not know, naming it and its line,
    where v2 ignored it. Keys set through 'programs.himalaya.settings' or
    'accounts.email.accounts.<name>.himalaya.settings' that v3 dropped now
    fail the whole file: the `table` blocks, every `*-color` key,
    `envelope.list.datetime-relative` and a v1 `folder` table among them.
    Dates now print as `%F %R` in the local timezone; to print them as v2
    did, set for example:

    ```nix
    programs.himalaya.settings.envelope.list = {
      datetime-fmt = "%F %R%:z";
      datetime-local-tz = false;
    };
    ```

    Himalaya 3 also reads every default configuration path, each merged
    over the previous one, so a leftover {file}`~/.himalayarc` now
    overrides the generated {file}`$XDG_CONFIG_HOME/himalaya/config.toml`:
    delete it.

    The generated accounts now carry `email` and `display-name`, taken
    from 'accounts.email.accounts.<name>.address' and
    'accounts.email.accounts.<name>.realName', so the messages Himalaya
    composes have a `From` header. The first-run wizard is gone: a bare
    `himalaya` prints the help.

    See the migration guide at
    https://github.com/pimalaya/himalaya/blob/v3.0.0/MIGRATION.md for the
    other changes, such as the text output and the search query language.
  '';
}

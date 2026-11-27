# ===========================================================================
# modules/development/editors/vscode/vscode.nix — VS Code (Microsoft build)
#
# Package + settings. Extensions stay mutable (installed from the app / Noctalia
# writes its theme into ~/.vscode/extensions).
#
# Settings: same base as VSCodium (dotfiles/vscodium/settings.json) with the
# flow-icons license key from agenix injected, written as a real file so
# VS Code can modify it at runtime.
#
# Also sets VISUAL="code --wait" for every user on the host (EDITOR=hx comes
# from core.nix). --wait keeps the calling tool waiting until the tab closes.
#
# Enable per host by importing this module (installs for the host, settings for
# linuxury); remove the import to turn it off.
# ===========================================================================
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.vscode ];

  environment.variables.VISUAL = "code --wait";

  # sharedModules + home.username guard: importing this module on a
  # babylinux/alex host does not create a linuxury Home Manager profile.
  # lib here is Home Manager's (it carries lib.hm.dag).
  home-manager.sharedModules = [ ({ config, lib, ... }: lib.mkIf (config.home.username == "linuxury") {
    # Activation (after writeBoundary): replace a symlink at the target with a
    # real file, then merge the base settings with flow-icons.licenseKey (read
    # from /run/agenix/flow-icons-license when readable) into
    # ~/.config/Code/User/settings.json. Skipped when the base file is missing.
    home.activation.vscodeSettings =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _base="$HOME/dotfiles/vscodium/settings.json"
        _target="$HOME/.config/Code/User/settings.json"
        _license="/run/agenix/flow-icons-license"

        # Hosts where linuxury has no ~/dotfiles clone (e.g. Alex-Desktop):
        # skip instead of failing the whole activation.
        if [ -f "$_base" ]; then
        [ -L "$_target" ] && rm "$_target"
        mkdir -p "$(dirname "$_target")"

        ${pkgs.python3}/bin/python3 -c "
  import json, os
  with open('$_base') as f:
      s = json.load(f)
  if os.access('$_license', os.R_OK):
      with open('$_license') as f:
          s['flow-icons.licenseKey'] = f.read().strip()
  with open('$_target', 'w') as f:
      json.dump(s, f, indent=2)
      f.write('\n')
  "
        fi
      '';
  }) ];
}

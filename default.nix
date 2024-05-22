{
  sources ? import ./npins,
  system ? builtins.currentSystem,
  pkgs ? import sources.nixpkgs { inherit system; config = { }; overlays = [ ]; },
  nixdoc-to-github ? pkgs.callPackage sources.nixdoc-to-github { },
}:
let
  update-readme = lib.nixdoc-to-github.run {
    description = "Git hooks";
    category = "git-hooks";
    file = "${toString ./lib.nix}";
    output = "${toString ./README.md}";
  };
  lib = {
    inherit (nixdoc-to-github.lib) nixdoc-to-github;
    git-hooks = pkgs.callPackage ./lib.nix { };
  };
  shell = pkgs.mkShellNoCC {
    packages = with pkgs; [
      npins
    ];
    shellHook = ''
      ${with lib.git-hooks; pre-commit (wrap.abort-on-change update-readme)}
    '';
  };
in
{
  lib = { inherit (lib) git-hooks; };
  inherit shell;
}

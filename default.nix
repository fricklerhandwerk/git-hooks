let
  sources = import ./npins;
  nixdoc-overlay = src: final: prev:
    let
      package = (final.lib.importTOML "${src}/Cargo.toml").package;
    in
    {
      nixdoc = final.rustPlatform.buildRustPackage {
        pname = package.name;
        version = package.version;
        inherit src;
        cargoLock = {
          lockFile = "${src}/Cargo.lock";
        };
      };
    };
in
{
  pkgs ? import sources.nixpkgs {
    inherit system;
    config = { };
    overlays = [ (nixdoc-overlay nixdoc)];
  },
  nixdoc ? sources.nixdoc,
  system ? builtins.currentSystem,
}:
let
  update-readme = pkgs.writeShellApplication {
    name = "pre-commit-hook";
    runtimeInputs = with pkgs; [ git pkgs.nixdoc busybox ];
    text = ''
      nixdoc --category git-hooks --description "Git hooks" --file lib.nix | awk '
      BEGIN { p=0; }
      /^\:\:\:\{\.example\}/ { print "> **Example**"; p=1; next; }
      /^\:\:\:/ { p=0; next; }
      p { print "> " $0; next; }
      { print }
      ' | sed 's/[[:space:]]*$//' | sed 's/ {#[^}]*}//g' > README.md
      {
        changed=$(git diff --name-only --exit-code);
        status=$?;
      } || true

      if [ $status -ne 0 ]; then
        echo Files updated by pre-commit hook:
        echo "$changed"
        exit $status
      fi
    '';
  };
  lib.git-hooks = pkgs.callPackage ./lib.nix { };
  shell = pkgs.mkShellNoCC {
    packages = with pkgs; [
      npins
      pkgs.nixdoc
    ];
    shellHook = ''
      ${lib.git-hooks.pre-commit update-readme}
    '';
  };
in
{
  inherit shell lib;
}

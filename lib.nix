/**
  Install Nix packages as [Git hooks](https://git-scm.com/docs/githooks) from your Nix shell environment.

  Heavily inspired by [a hack](https://git.clan.lol/clan/clan-core/src/commit/930923512c03179fe75e4209c27eb3da368e7766/scripts/pre-commit) to get [treefmt](https://github.com/numtide/treefmt) into a pre-commit hook.
*/
{ lib, writeShellApplication, git, busybox }:
let
  wrap = hook: writeShellApplication
    {
      name = "pre-commit";
      runtimeInputs = [ git ];
      text = ''
        [[ -v DEBUG ]] && set -x
        readarray staged < <(git diff --name-only --cached)
        [[ ''${#staged[@]} = 0 ]] && exit
        unstash() {
          local ret=$?
          set +e
          git stash pop -q
          exit "$ret"
        }
        git stash push --quiet --keep-index --message "pre-commit"
        trap unstash EXIT
        ${lib.getExe hook}
      '';
    };
  install = hook: writeShellApplication {
    name = "install";
    runtimeInputs = [ git busybox ];
    text = ''
      ln -s -f ${lib.getExe (wrap hook)} "$(git rev-parse --show-toplevel)"/.git/hooks/pre-commit
    '';
  };
in
{
  /**
    `pre-commit` takes a derivaton with a [pre-commit hook](https://git-scm.com/docs/githooks#_pre_commit), and returns a path to an executable that will install the hook.

    ```
    pre-commit :: Derivation -> Path
    ```

    The derivation must have `meta.mainProgram` set to the name of the executable in `$out/bin/` that implements the hook.
    The hook is installed in the Git repository that surrounds the working directory of the Nix invocation, and will get run roughly like this:

    ```bash
    git stash push --keep-index
    hook
    git stash pop
    ```

    :::{.example}

    # Add a pre-commit hook to a development environment

    Entering this shell environment will install a Git hook that prints `Hello, world!` to the console before each commit:

    ```shell-session
    nix-shell -p npins
    npins init
    npins add github fricklerhandwerk git-hooks -b main
    ```

    ```nix
    # default.nix
    let
      sources = import ./npins;
    in
    {
      nixpkgs ? sources.nixpkgs,
      git-hooks ? sources.git-hooks,
      system ? builtins.currentSystem,
    }:
    let
      pkgs = import nixpkgs { inherit system; config = { }; overlays = [ ]; };
      inherit (pkgs.callPackage git-hooks { inherit system nixpkgs; }) lib;
    in
    pkgs.mkShellNoCC {
      shellHook = ''
        ${lib.git-hooks.pre-commit pkgs.hello}
      '';
    }
    ```
    :::

  */
  pre-commit = hook: "${lib.getExe (install hook)}";
}

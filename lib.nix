/**
  Install Nix packages as [Git hooks](https://git-scm.com/docs/githooks) from your Nix shell environment.

  Heavily inspired by [a hack](https://git.clan.lol/clan/clan-core/src/commit/930923512c03179fe75e4209c27eb3da368e7766/scripts/pre-commit) to get [treefmt](https://github.com/numtide/treefmt) into a pre-commit hook.

  # Installation

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
    pkgs ? import sources.nixpkgs { inherit system; config = { }; overlays = [ ]; },
    git-hooks ? import sources.git-hooks { inherit pkgs system; },
    system ? builtins.currentSystem,
  }:
  let
    inherit (git-hooks) lib;
  in
  pkgs.mkShellNoCC {
    shellHook = ''
      # add Git hooks here
    '';
  }
  ```
*/
{ lib, writeShellApplication, git, stdenv, busybox, coreutils }:
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
    runtimeInputs =
      let
        posix = if stdenv.isDarwin then coreutils else busybox;
      in
      [ git posix ];
    text = ''
      ln -s -f ${lib.getExe (wrap hook)} "$(git rev-parse --show-toplevel)"/.git/hooks/pre-commit
    '';
  };
in
{
  /**
    ```
    pre-commit :: Derivation -> Path
    ```

    `pre-commit` takes a derivaton with a [pre-commit hook](https://git-scm.com/docs/githooks#_pre_commit), and returns a path to an executable that will install the hook.

    The derivation must have `meta.mainProgram` set to the name of the executable in `$out/bin/` that implements the hook.
    The hook is installed in the Git repository that surrounds the working directory of the Nix invocation, and will get run roughly like this:

    ```bash
    git stash push --keep-index
    hook
    git stash pop
    ```

    :::{.example}

    # Add a pre-commit hook

    Entering this shell environment will install a Git hook that prints `Hello, world!` to the console before each commit:

    ```
    pkgs.mkShellNoCC {
      shellHook = ''
        ${lib.git-hooks.pre-commit pkgs.hello}
      '';
    }
    ```
    :::

  */
  pre-commit = hook: lib.getExe (install hook);
  /**
    ```
    abort-on-change :: Derivation -> Derivation
    ```

    Wrap a hook such that the commit is aborted if the hook changes staged files.

    :::{.example}

    # Wrap a pre-commit hook to abort on changed files

    The `cursed` hook will add an empty line to each staged file.
    Wrapping it in `abort-on-change` will prevent files thus changed from being committed.

    ```
    let
      cursed = pkgs.writeShellApplication {
        name = "pre-commit-hook";
        runtimeInputs = with pkgs; [ git ];
        text = ''
          for f in $(git diff --name-only --cached); do
            echo >> "$f"
          done
        '';
      };
    in
    pkgs.mkShellNoCC {
      shellHook = ''
        ${with lib.git-hooks; pre-commit (wrap.abort-on-change cursed)}
      '';
    }
    ```
    :::
  */
  wrap.abort-on-change = hook: writeShellApplication {
    name = "pre-commit-hook";
    runtimeInputs = [ git ];
    text = ''
      ${lib.getExe hook}
      {
        changed=$(git diff --name-only --exit-code);
        status=$?;
      } || true
      if [ $status -ne 0 ]; then
        exec 1>&2
        echo Files changed by pre-commit hook:
        echo "$changed"
        exit $status
      fi
    '';
  };
}

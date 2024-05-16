# Git hooks
Install Nix packages as [Git hooks](https://git-scm.com/docs/githooks) from your Nix shell environment.

Heavily inspired by [a hack](https://git.clan.lol/clan/clan-core/src/commit/930923512c03179fe75e4209c27eb3da368e7766/scripts/pre-commit) to get [treefmt](https://github.com/numtide/treefmt) into a pre-commit hook.

## Installation

``` shell-session
nix-shell -p npins
npins init
npins add github fricklerhandwerk git-hooks -b main
```

``` nix
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

## `lib.git-hooks.pre-commit`

`pre-commit` takes a derivaton with a [pre-commit hook](https://git-scm.com/docs/githooks#_pre_commit), and returns a path to an executable that will install the hook.

    pre-commit :: Derivation -> Path

The derivation must have `meta.mainProgram` set to the name of the executable in `$out/bin/` that implements the hook.
The hook is installed in the Git repository that surrounds the working directory of the Nix invocation, and will get run roughly like this:

``` bash
git stash push --keep-index
hook
git stash pop
```

> **Example**
>
> ### Add a pre-commit hook
>
> Entering this shell environment will install a Git hook that prints `Hello, world!` to the console before each commit:
>
>     pkgs.mkShellNoCC {
>       shellHook = ''
>         ${lib.git-hooks.pre-commit pkgs.hello}
>       '';
>     }
>




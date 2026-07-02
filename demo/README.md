# demo/ — from-zero live demo

Replays "empty machine → my full env" in a throwaway browser VS Code, then shows the
edit → commit loop. One command:

```sh
./demo/run-vscode.sh        # bare box + code-server → http://localhost:8080
```
You land in an empty (browser) VS Code with an integrated terminal. Nothing is installed.

> Not deployed by chezmoi: this folder sits above the source state (`home/`, via
> `.chezmoiroot`), so chezmoi never sees it.

## The demo

**1. From zero** — in the integrated terminal:
```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply bgauduch/dotfiles
exec zsh          # $HOME fills up: starship prompt, tools, doctor.sh green
```
chezmoi asks for name/email/profile (first run), then builds everything. (To test a branch
before it lands on main: `--branch <name>`.)

**2. Edit → commit loop** — the key point: you don't edit `$HOME` directly, you edit the
source and chezmoi applies:
```sh
chezmoi edit ~/.zshrc   # opens the SOURCE (home/dot_zshrc.tmpl), NOT ~/.zshrc
chezmoi diff            # source → target delta
chezmoi apply           # writes into $HOME
chezmoi cd              # → ~/.local/share/chezmoi (real git clone); commit + push
```
`init` cloned the repo into `~/.local/share/chezmoi` (real `.git` + `origin`), so
`chezmoi cd` + `git push` sends your change back to the repo. No phantom copy.

## Reset
Every run is a fresh `--rm` container — just re-run `./demo/run-vscode.sh`.

## Also available
- `./demo/run.sh` — the ready env in a plain terminal (no browser), to explore; inside it,
  `bash ~/.local/share/chezmoi/demo/steps.sh` runs a guided tour (templates, profiles,
  scripts, secrets, with doc links).
- `mise run demo-record` — records the install as an asciinema cast (optional).
- Codespaces: `.devcontainer/` gives the same bare box in the cloud (browser), with GitHub
  auth → `git push` works directly.

## Prerequisites
Docker. The one-liner requires the repo to be public (or, in Codespaces, GitHub auth).

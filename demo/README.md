# demo/ — from-zero live demo

Rejoue "machine vide → mon env complet" dans un VS Code navigateur jetable, puis montre
la boucle edit → commit. Une commande :

```sh
./demo/run-vscode.sh        # box vierge + code-server → http://localhost:8080
```
Tu arrives dans un VS Code (navigateur) vide, terminal intégré. Rien n'est installé.

> Not deployed by chezmoi: this folder sits above the source state (`home/`, via
> `.chezmoiroot`), so chezmoi never sees it.

## La démo

**1. From zero** — dans le terminal intégré :
```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply bgauduch/dotfiles
exec zsh          # $HOME se remplit : prompt starship, outils, doctor.sh vert
```
chezmoi demande nom/email/profil (1er run), puis build tout. (Tester une branche avant
qu'elle soit sur main : `--branch <nom>`.)

**2. Boucle edit → commit** — le point clé : tu n'édites pas `$HOME` en direct, tu édites
la source et chezmoi applique :
```sh
chezmoi edit ~/.zshrc   # ouvre la SOURCE (home/dot_zshrc.tmpl), PAS ~/.zshrc
chezmoi diff            # delta source → cible
chezmoi apply           # écrit dans $HOME
chezmoi cd              # → ~/.local/share/chezmoi (vrai clone git) ; commit + push
```
`init` a cloné le dépôt dans `~/.local/share/chezmoi` (vrai `.git` + `origin`), donc
`chezmoi cd` + `git push` renvoie ton changement au dépôt. Pas de copie fantôme.

## Reset
Chaque run est un container `--rm` neuf — relance `./demo/run-vscode.sh`.

## Aussi dispo
- `./demo/run.sh` — l'env prêt dans un terminal simple (sans navigateur), pour explorer ;
  dedans, `bash ~/.local/share/chezmoi/demo/steps.sh` déroule un tour guidé (templates,
  profils, scripts, secrets, avec liens doc).
- `mise run demo-record` — enregistre l'install en cast asciinema (optionnel).
- Codespaces : `.devcontainer/` donne la même box vierge dans le cloud (navigateur), avec
  l'auth GitHub → `git push` marche direct.

## Prérequis
Docker. Le one-liner exige le dépôt public (ou, en Codespaces, l'auth GitHub).

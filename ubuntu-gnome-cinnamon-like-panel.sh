#!/usr/bin/env bash
# ubuntu-gnome-cinnamon-like-panel.sh
# Installe Dash to Panel, active AppIndicators, désactive Ubuntu Dock
# et applique une config "façon Cinnamon" (barre en bas, 38px, etc.)

set -euo pipefail

EXT_UUID="dash-to-panel@jderose9.github.com"
DOCK_UUID="ubuntu-dock@ubuntu.com"
APPI_UUID="ubuntu-appindicators@ubuntu.com"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$EXT_UUID"

say() { printf "\033[1;32m[+] %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
err() { printf "\033[1;31m[x] %s\033[0m\n" "$*"; exit 1; }

ensure_session_bus() {
  if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    # Permet exécution via TTY/SSH sur la session graphique de l'utilisateur
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
  fi
}

require_cmds() {
  local need=(curl wget unzip git make gettext gsettings gnome-extensions)
  local miss=()
  for c in "${need[@]}"; do
    command -v "$c" >/dev/null 2>&1 || miss+=("$c")
  done
  if ((${#miss[@]})); then
    say "Installation dépendances APT: ${miss[*]}"
    sudo apt update
    sudo apt install -y "${miss[@]}"
  fi
}

install_dash_to_panel() {
  if [[ -d "$EXT_DIR" ]]; then
    say "Dash to Panel déjà présent."
    return
  fi

  say "Tentative d'installation via extensions.gnome.org (EGO)…"
  tmpdir=$(mktemp -d)
  pushd "$tmpdir" >/dev/null

  # Récupère le dernier zip publié (scrape simple et robuste)
  page="$(curl -fsSL https://extensions.gnome.org/extension/1160/dash-to-panel/)" || page=""
  zipurl="$(printf "%s" "$page" | grep -oE 'https://extensions.gnome.org/extension-data/dash-to-paneljderose9.github.com.v[0-9]+\.shell-extension\.zip' | head -n1 || true)"

  if [[ -n "$zipurl" ]]; then
    say "Téléchargement: $zipurl"
    curl -fSLO "$zipurl"
    zipfile="$(basename "$zipurl")"
    gnome-extensions install "$zipfile" --force
    popd >/dev/null
    rm -rf "$tmpdir"
    [[ -d "$EXT_DIR" ]] && { say "Install EGO OK."; return; }
    warn "Install via EGO semble avoir échoué, fallback GitHub…"
  else
    warn "Impossible de récupérer le zip EGO, fallback GitHub…"
    popd >/dev/null
    rm -rf "$tmpdir"
  fi

  # Fallback: build depuis GitHub (toujours compatible GNOME 46)
  say "Installation depuis GitHub…"
  tmpdir=$(mktemp -d)
  git clone --depth=1 https://github.com/home-sweet-gnome/dash-to-panel.git "$tmpdir/dtp"
  pushd "$tmpdir/dtp" >/dev/null
  make install
  popd >/dev/null
  rm -rf "$tmpdir"

  [[ -d "$EXT_DIR" ]] || err "Échec: Dash to Panel non installé."
  say "Install GitHub OK."
}

apply_settings() {
  say "Activation AppIndicators + Dash to Panel, désactivation Ubuntu Dock…"
  gnome-extensions enable "$APPI_UUID" 2>/dev/null || true
  gnome-extensions disable "$DOCK_UUID" 2>/dev/null || true
  gnome-extensions enable "$EXT_UUID"

  say "Réglages 'façon Cinnamon'…"
  gsettings set org.gnome.shell.extensions.dash-to-panel panel-position 'BOTTOM'
  gsettings set org.gnome.shell.extensions.dash-to-panel panel-size 38
  gsettings set org.gnome.shell.extensions.dash-to-panel show-activities-button false
  gsettings set org.gnome.shell.extensions.dash-to-panel show-apps-button true
  gsettings set org.gnome.shell.extensions.dash-to-panel isolate-monitors false
  gsettings set org.gnome.shell.extensions.dash-to-panel show-window-previews true
  gsettings set org.gnome.shell.extensions.dash-to-panel group-apps true
  gsettings set org.gnome.shell.extensions.dash-to-panel transparency-mode 'FIXED'
  gsettings set org.gnome.shell.extensions.dash-to-panel panel-opacity 0.9
}

post_hint() {
  say "Terminé."
  if [[ "${XDG_SESSION_TYPE:-}" == "x11" ]]; then
    echo "Sous Xorg: Alt+F2, tapez 'r', Entrée pour recharger GNOME Shell."
  else
    echo "Sous Wayland: déconnectez/reconnectez votre session pour appliquer la barre."
  fi
  echo "Extensions actives:"
  gnome-extensions list --enabled | grep -E 'dash-to-panel|ubuntu-dock|appindicators' || true
}

main() {
  ensure_session_bus
  require_cmds
  install_dash_to_panel
  apply_settings
  post_hint
}

main "$@"

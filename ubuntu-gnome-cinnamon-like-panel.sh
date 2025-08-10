#!/usr/bin/env bash
# ubuntu-gnome-cinnamon-like-panel.sh
# Ubuntu Desktop (GNOME) + barre façon Cinnamon sans installer Cinnamon
# - Installe Dash to Panel (site EGO sinon GitHub)
# - Active AppIndicators, désactive Ubuntu Dock
# - Applique un preset “Cinnamon-like”
# - Ajoute icône menu Cinnamon officielle
# - Sauvegarde/restaure les réglages (dconf)
# - Garde-fou systemd user pour réappliquer après login/MAJ
# - Revert propre vers GNOME stock
#
# Usage:
#   ./ubuntu-gnome-cinnamon-like-panel.sh           # install + config
#   ./ubuntu-gnome-cinnamon-like-panel.sh restore   # restaurer preset dconf
#   ./ubuntu-gnome-cinnamon-like-panel.sh revert    # retour GNOME stock
#   ./ubuntu-gnome-cinnamon-like-panel.sh backup    # sauver preset dconf
#   ./ubuntu-gnome-cinnamon-like-panel.sh ensure    # forcer réactivation (hook)

set -euo pipefail

EXT_UUID="dash-to-panel@jderose9.github.com"
DOCK_UUID="ubuntu-dock@ubuntu.com"
APPI_UUID="ubuntu-appindicators@ubuntu.com"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$EXT_UUID"
PRESET_DIR="$HOME/.config/ubcynt"
PRESET_FILE="$PRESET_DIR/dtp.dconf"

say()  { printf "\033[1;32m[+] %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m[x] %s\033[0m\n" "$*"; exit 1; }

ensure_session_bus() {
  if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
  fi
}

require_cmds() {
  local need=(curl wget unzip git make gettext gsettings gnome-extensions dconf)
  local miss=()
  for c in "${need[@]}"; do command -v "$c" >/dev/null 2>&1 || miss+=("$c"); done
  if ((${#miss[@]})); then
    say "APT: ${miss[*]}"
    sudo apt update
    sudo apt install -y "${miss[@]}"
  fi
}

install_dash_to_panel() {
  if [[ -d "$EXT_DIR" ]]; then
    say "Dash to Panel déjà présent."
    return
  fi

  say "Installation via extensions.gnome.org (EGO)…"
  local tmpdir; tmpdir="$(mktemp -d)"
  pushd "$tmpdir" >/dev/null || true
  local page zipurl zipfile
  page="$(curl -fsSL https://extensions.gnome.org/extension/1160/dash-to-panel/ || true)"
  zipurl="$(printf "%s" "$page" | grep -oE \
    'https://extensions.gnome.org/extension-data/dash-to-paneljderose9.github.com.v[0-9]+\.shell-extension\.zip' \
    | head -n1 || true)"
  if [[ -n "${zipurl:-}" ]]; then
    say "Téléchargement: $zipurl"
    curl -fSLO "$zipurl"
    zipfile="$(basename "$zipurl")"
    gnome-extensions install "$zipfile" --force
  else
    warn "Zip EGO introuvable, fallback GitHub…"
  fi
  popd >/dev/null || true
  rm -rf "$tmpdir"

  if [[ ! -d "$EXT_DIR" ]]; then
    say "Installation depuis GitHub…"
    tmpdir="$(mktemp -d)"
    git clone --depth=1 https://github.com/home-sweet-gnome/dash-to-panel.git "$tmpdir/dtp"
    pushd "$tmpdir/dtp" >/dev/null || true
    make install
    popd >/dev/null || true
    rm -rf "$tmpdir"
  fi

  [[ -d "$EXT_DIR" ]] || err "Dash to Panel non installé."
  say "Dash to Panel installé."
}

apply_settings() {
  say "Activation: AppIndicators + Dash to Panel, désactivation: Ubuntu Dock…"
  gnome-extensions enable "$APPI_UUID" 2>/dev/null || true
  gnome-extensions disable "$DOCK_UUID" 2>/dev/null || true
  gnome-extensions enable "$EXT_UUID"

  say "Réglages 'Cinnamon-like'…"
  gsettings set org.gnome.shell.extensions.dash-to-panel panel-position 'BOTTOM'
  gsettings set org.gnome.shell.extensions.dash-to-panel panel-size 38
  gsettings set org.gnome.shell.extensions.dash-to-panel show-activities-button false
  gsettings set org.gnome.shell.extensions.dash-to-panel show-apps-button true
  gsettings set org.gnome.shell.extensions.dash-to-panel show-window-previews true
  gsettings set org.gnome.shell.extensions.dash-to-panel group-apps true
  gsettings set org.gnome.shell.extensions.dash-to-panel isolate-monitors false
  gsettings set org.gnome.shell.extensions.dash-to-panel transparency-mode 'FIXED'
  gsettings set org.gnome.shell.extensions.dash-to-panel panel-opacity 0.9
}

install_cinnamon_menu_icon() {
  say "Icône du menu: Cinnamon officiel…"
  local ICON_DIR="$HOME/.local/share/icons"
  local ICON_SVG="$ICON_DIR/cinnamon-logo.svg"
  local ICON_PNG32="$ICON_DIR/cinnamon-logo-32.png"

  mkdir -p "$ICON_DIR"

  if [[ ! -s "$ICON_SVG" ]]; then
    say "Téléchargement de l’icône depuis Wikimedia…"
    wget -q -O "$ICON_SVG" "https://commons.wikimedia.org/wiki/Special:FilePath/Cinnamon-logo.svg" || \
      warn "Téléchargement SVG échoué (mode offline ?), on continue si déjà présent."
  fi

  if [[ -s "$ICON_SVG" ]]; then
    dconf write /org/gnome/shell/extensions/dash-to-panel/show-apps-custom-icon true
    dconf write /org/gnome/shell/extensions/dash-to-panel/show-apps-icon-file "'$ICON_SVG'"
  fi

  if ! command -v rsvg-convert >/dev/null 2>&1; then
    sudo apt-get update -y >/dev/null 2>&1 || true
    sudo apt-get install -y librsvg2-bin >/dev/null 2>&1 || true
  fi
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 32 -h 32 -o "$ICON_PNG32" "$ICON_SVG" 2>/dev/null || true
    if [[ "${FORCE_MENU_ICON_PNG:-0}" == "1" && -s "$ICON_PNG32" ]]; then
      dconf write /org/gnome/shell/extensions/dash-to-panel/show-apps-icon-file "'$ICON_PNG32'"
    fi
  fi
}

backup_settings() {
  mkdir -p "$PRESET_DIR"
  dconf dump /org/gnome/shell/extensions/dash-to-panel/ > "$PRESET_FILE" || true
  say "Preset sauvegardé: $PRESET_FILE"
}

restore_settings() {
  if [[ -s "$PRESET_FILE" ]]; then
    dconf load /org/gnome/shell/extensions/dash-to-panel/ < "$PRESET_FILE"
    say "Preset restauré."
  else
    warn "Aucun preset à restaurer: $PRESET_FILE"
  fi
}

install_systemd_guard() {
  say "Garde-fou systemd user…"
  mkdir -p "$HOME/.config/systemd/user"
  cat > "$HOME/.config/systemd/user/gnome-dtp-ensure.service" <<'UNIT'
[Unit]
Description=Ensure Dash to Panel active and Ubuntu Dock disabled at login
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=/usr/bin/gnome-extensions enable dash-to-panel@jderose9.github.com
ExecStart=/usr/bin/gnome-extensions enable ubuntu-appindicators@ubuntu.com
ExecStart=/usr/bin/gnome-extensions disable ubuntu-dock@ubuntu.com
UNIT

  cat > "$HOME/.config/systemd/user/gnome-dtp-ensure.timer" <<'UNIT'
[Unit]
Description=Run gnome-dtp-ensure at login

[Timer]
OnBootSec=20
OnUnitActiveSec=0

[Install]
WantedBy=default.target
UNIT

  systemctl --user daemon-reload
  systemctl --user enable --now gnome-dtp-ensure.timer
  say "Timer activé."
}

revert_gnome_stock() {
  say "Revert GNOME stock…"
  gnome-extensions disable "$EXT_UUID" 2>/dev/null || true
  gnome-extensions enable "$DOCK_UUID" 2>/dev/null || true
  gnome-extensions disable "$APPI_UUID" 2>/dev/null || true
  dconf write /org/gnome/shell/extensions/dash-to-panel/show-apps-custom-icon false
  systemctl --user disable --now gnome-dtp-ensure.timer 2>/dev/null || true
  say "OK. Reconnecte la session (Wayland) ou Alt+F2,r (Xorg)."
}

post_hint() {
  if [[ "${XDG_SESSION_TYPE:-}" == "x11" ]]; then
    echo "Xorg: Alt+F2, tape 'r', Entrée pour recharger GNOME Shell."
  else
    echo "Wayland: déconnecte/reconnecte ta session."
  fi
  echo "Extensions actives:"
  gnome-extensions list --enabled | grep -E 'dash-to-panel|ubuntu-dock|appindicators' || true
}

ensure() {
  gnome-extensions enable "$EXT_UUID" 2>/dev/null || true
  gnome-extensions enable "$APPI_UUID" 2>/dev/null || true
  gnome-extensions disable "$DOCK_UUID" 2>/dev/null || true
}

main() {
  ensure_session_bus
  case "${1:-}" in
    restore) require_cmds; restore_settings; post_hint; exit 0;;
    revert)  require_cmds; revert_gnome_stock; exit 0;;
    backup)  require_cmds; backup_settings; exit 0;;
    ensure)  require_cmds; ensure; exit 0;;
  esac

  require_cmds
  install_dash_to_panel
  apply_settings
  install_cinnamon_menu_icon
  backup_settings
  install_systemd_guard
  post_hint
}

main "$@"

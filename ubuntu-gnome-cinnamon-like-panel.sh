#!/usr/bin/env bash
# ubuntu-gnome-cinnamon-like-panel.sh — GNOME façon Cinnamon (VM/desktop)
set -euo pipefail

EXT_UUID="dash-to-panel@jderose9.github.com"
DOCK_UUID="ubuntu-dock@ubuntu.com"
APPI_UUID="ubuntu-appindicators@ubuntu.com"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$EXT_UUID"
SCHEMA_DIR="$EXT_DIR/schemas"
PRESET_DIR="$HOME/.config/ubcynt"
PRESET_FILE="$PRESET_DIR/dtp.dconf"

say()  { printf "\033[1;32m[+] %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m[!] %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m[x] %s\033[0m\n" "$*"; exit 1; }

# gsettings wrapper pointant sur le schéma de l’extension
gset() { GSETTINGS_SCHEMA_DIR="$SCHEMA_DIR" gsettings "$@"; }
has_key() {
  GSETTINGS_SCHEMA_DIR="$SCHEMA_DIR" gsettings list-keys org.gnome.shell.extensions.dash-to-panel \
    | grep -qx "$1"
}
gset_if() {
  local key="$1"; shift
  if has_key "$key"; then
    gset set org.gnome.shell.extensions.dash-to-panel "$key" "$@"
  else
    warn "Clé absente: $key (ignorée)"
  fi
}

ensure_session_bus() {
  if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
  fi
}

require_cmds() {
  local need=(curl wget unzip git make gettext gsettings gnome-extensions dconf glib-compile-schemas)
  local miss=()
  for c in "${need[@]}"; do command -v "$c" >/dev/null 2>&1 || miss+=("$c"); done
  if ((${#miss[@]})); then
    say "APT: ${miss[*]}"
    sudo apt update
    sudo apt install -y "${miss[@]}" libglib2.0-bin librsvg2-bin
  fi
}

compile_schema_if_needed() {
  mkdir -p "$SCHEMA_DIR"
  [[ -f "$SCHEMA_DIR/gschemas.compiled" ]] || {
    say "Compilation du schéma GLib…"
    glib-compile-schemas "$SCHEMA_DIR" || true
  }
}

install_dash_to_panel() {
  if [[ -d "$EXT_DIR" ]]; then
    say "Dash to Panel déjà présent."
    compile_schema_if_needed
    return
  fi

  say "Installation via extensions.gnome.org (EGO)…"
  local tmpdir; tmpdir="$(mktemp -d)"; pushd "$tmpdir" >/dev/null || true
  local page zipurl zipfile
  page="$(curl -fsSL https://extensions.gnome.org/extension/1160/dash-to-panel/ || true)"
  zipurl="$(printf "%s" "$page" | grep -oE \
    'https://extensions.gnome.org/extension-data/dash-to-paneljderose9.github.com.v[0-9]+\.shell-extension\.zip' \
    | head -n1 || true)"
  if [[ -n "${zipurl:-}" ]]; then
    say "Téléchargement: $zipurl"
    curl -fSLO "$zipurl"; zipfile="$(basename "$zipurl")"
    gnome-extensions install "$zipfile" --force
  else
    warn "Zip EGO introuvable, fallback GitHub…"
  fi
  popd >/dev/null || true; rm -rf "$tmpdir"

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
  compile_schema_if_needed
  say "Dash to Panel installé."
}

detect_keys() {
  # Gère les variantes de noms selon versions
  # bouton “Afficher les applications”
  for k in show-show-apps-button show-apps-button; do
    if has_key "$k"; then KEY_SHOW_APPS="$k"; break; fi
  done
  # position du panneau
  if has_key panel-position; then KEY_PANEL_POS="panel-position"
  elif has_key panel-position; then KEY_PANEL_POS="panel-position" # fallback identique par sécurité
  else KEY_PANEL_POS=""; fi
  # taille
  if has_key panel-size; then KEY_PANEL_SIZE="panel-size"; else KEY_PANEL_SIZE=""; fi
  # autres réglages usuels
  has_key show-activities-button && KEY_ACT="show-activities-button" || KEY_ACT=""
  has_key show-window-previews && KEY_PREV="show-window-previews" || KEY_PREV=""
  has_key group-apps && KEY_GROUP="group-apps" || KEY_GROUP=""
  has_key isolate-monitors && KEY_ISO="isolate-monitors" || KEY_ISO=""
  has_key transparency-mode && KEY_TRMODE="transparency-mode" || KEY_TRMODE=""
  has_key panel-opacity && KEY_PANOP="panel-opacity" || KEY_PANOP=""
  has_key taskbar-position && KEY_TASKPOS="taskbar-position" || KEY_TASKPOS=""
  has_key appicon-margin && KEY_APP_MARGIN="appicon-margin" || KEY_APP_MARGIN=""
  # icône personnalisée
  has_key show-apps-custom-icon && KEY_APPS_CUSTOM="show-apps-custom-icon" || KEY_APPS_CUSTOM=""
  has_key show-apps-icon-file   && KEY_APPS_ICON="show-apps-icon-file"       || KEY_APPS_ICON=""
}

apply_settings() {
  say "Activation: AppIndicators + Dash to Panel, désactivation: Ubuntu Dock…"
  gnome-extensions enable "$APPI_UUID" 2>/dev/null || true
  gnome-extensions disable "$DOCK_UUID" 2>/dev/null || true
  gnome-extensions enable "$EXT_UUID"

  sleep 1  # laisse DTP s’initialiser
  detect_keys

  say "Réglages 'Cinnamon-like' (barre EN BAS + menu Apps)…"
  [[ -n "${KEY_PANEL_POS:-}" ]] && gset_if "$KEY_PANEL_POS" 'BOTTOM'
  [[ -n "${KEY_PANEL_SIZE:-}" ]] && gset_if "$KEY_PANEL_SIZE" 38
  [[ -n "${KEY_ACT:-}"       ]] && gset_if "$KEY_ACT" false
  [[ -n "${KEY_PREV:-}"      ]] && gset_if "$KEY_PREV" true
  [[ -n "${KEY_GROUP:-}"     ]] && gset_if "$KEY_GROUP" true
  [[ -n "${KEY_ISO:-}"       ]] && gset_if "$KEY_ISO" false
  [[ -n "${KEY_TRMODE:-}"    ]] && gset_if "$KEY_TRMODE" 'FIXED'
  [[ -n "${KEY_PANOP:-}"     ]] && gset_if "$KEY_PANOP" 0.9
  [[ -n "${KEY_TASKPOS:-}"   ]] && gset_if "$KEY_TASKPOS" 'CENTER' || true
  [[ -n "${KEY_APP_MARGIN:-}" ]] && gset_if "$KEY_APP_MARGIN" 6 || true

  # S’assurer que le bouton “Applications” est visible (clé selon version)
  if [[ -n "${KEY_SHOW_APPS:-}" ]]; then
    gset_if "$KEY_SHOW_APPS" true
  else
    warn "Aucune clé ‘show-…apps…button’ détectée — bouton Applications laissé par défaut."
  fi
}

install_cinnamon_menu_icon() {
  say "Icône du menu: Cinnamon…"
  local ICON_DIR="$HOME/.local/share/icons"
  local ICON_SVG="$ICON_DIR/cinnamon-logo.svg"
  local ICON_PNG32="$ICON_DIR/cinnamon-logo-32.png"
  mkdir -p "$ICON_DIR"

  if [[ ! -s "$ICON_SVG" ]]; then
    wget -q -O "$ICON_SVG" "https://commons.wikimedia.org/wiki/Special:FilePath/Cinnamon-logo.svg" \
      || warn "Téléchargement SVG échoué (mode offline ?)"
  fi

  if [[ -s "$ICON_SVG" ]]; then
    [[ -n "${KEY_APPS_CUSTOM:-}" ]] && gset_if "$KEY_APPS_CUSTOM" true
    [[ -n "${KEY_APPS_ICON:-}"   ]] && gset_if "$KEY_APPS_ICON" "$ICON_SVG"
  fi

  if command -v rsvg-convert >/dev/null 2>&1 && [[ -s "$ICON_SVG" ]]; then
    rsvg-convert -w 32 -h 32 -o "$ICON_PNG32" "$ICON_SVG" 2>/dev/null || true
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
  has_key show-apps-custom-icon && gset_if show-apps-custom-icon false || true
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
    restore) require_cmds; compile_schema_if_needed; restore_settings; post_hint; exit 0;;
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

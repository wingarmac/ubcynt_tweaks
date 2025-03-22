#!/bin/bash

### --- ENVIRONNEMENT VISUEL ---

# Appliquer le thème GTK courant
export GTK_THEME=$(gsettings get org.cinnamon.desktop.interface gtk-theme | tr -d \')
export XDG_CURRENT_DESKTOP="X-Cinnamon"

### --- CENTRAGE DE FENÊTRE ---

center_window() {
    win_width=$1
    win_height=$2

    resolution=$(xrandr | grep '*' | awk '{print $1}' | head -n1)
    screen_width=$(echo "$resolution" | cut -d'x' -f1)
    screen_height=$(echo "$resolution" | cut -d'x' -f2)

    pos_x=$(( (screen_width - win_width) / 2 ))
    pos_y=$(( (screen_height - win_height) / 2 ))

    sleep 0.2
    wmctrl -r :ACTIVE: -e 0,$pos_x,$pos_y,$win_width,$win_height
}

### --- EXTRACTION DES PANELS ACTIFS ---

applets_raw=$(gsettings get org.cinnamon enabled-applets)
panels=$(echo "$applets_raw" | grep -oE "panel[0-9]+" | sort -u)
panel_positions=$(gsettings get org.cinnamon panels-enabled | tr -d "[]',")

declare -a panel_list=()
for panel in $panels; do
    panel_num=$(echo "$panel" | grep -oE '[0-9]+')
    position="unknown"

    for entry in $panel_positions; do
        entry_panel=$(echo "$entry" | cut -d':' -f1)
        entry_position=$(echo "$entry" | cut -d':' -f3)
        if [ "$entry_panel" = "$panel_num" ]; then
            position="$entry_position"
            break
        fi
    done

    zone=$(echo "$applets_raw" | grep -oE "$panel:(left|center|right)" | head -n1 | cut -d':' -f2)
    [ -z "$zone" ] && zone="unknown"

    label="${panel} (${zone} ${position})"
    panel_list+=("$label")
done

enabled_applets=$(gsettings get org.cinnamon enabled-applets)

### --- SÉLECTEUR PRINCIPAL ---

(center_window 400 200) &
action=$(zenity --list \
    --title="Gestion des barres Cinnamon" \
    --column="Action" "Cloner" "Réinitialiser" \
    --width=400 --height=200)

[ -z "$action" ] && exit 1

### --- CLONAGE ---

if [[ "$action" == "Cloner" ]]; then

    (center_window 400 300) &
    source_panel=$(zenity --list \
        --title="Barre Source" \
        --column="Barres disponibles" "${panel_list[@]}" \
        --width=400 --height=300)

    [ -z "$source_panel" ] && exit 1

    (center_window 400 300) &
    target_panel=$(zenity --list \
        --title="Barre Cible" \
        --column="Barres disponibles" "${panel_list[@]}" \
        --width=400 --height=300)

    [ -z "$target_panel" ] && exit 1

    source_id=$(echo "$source_panel" | cut -d' ' -f1)
    target_id=$(echo "$target_panel" | cut -d' ' -f1)

    source_items=$(echo "$enabled_applets" | sed "s/['\[\]]//g" | tr ',' '\n' | grep "$source_id" | sed 's/^ *//')
    cloned_items=$(echo "$source_items" | sed "s/$source_id/$target_id/")
    cleaned=$(echo "$enabled_applets" | sed "s/['\[\]]//g" | tr ',' '\n' | grep -v "$target_id" | sed 's/^ *//')
    final=$(printf "%s\n%s" "$cleaned" "$cloned_items" | paste -sd "," -)
    gsettings set org.cinnamon enabled-applets "[$final]"

    zenity --info --text="Barre $target_id clonée à partir de $source_id."

### --- RÉINITIALISATION ---

elif [[ "$action" == "Réinitialiser" ]]; then

    (center_window 400 300) &
    target_panel=$(zenity --list \
        --title="Réinitialiser une barre" \
        --column="Barres disponibles" "${panel_list[@]}" \
        --width=400 --height=300)

    [ -z "$target_panel" ] && exit 1

    target_id=$(echo "$target_panel" | cut -d' ' -f1)
    new_list=$(echo "$enabled_applets" | sed "s/['\[\]]//g" | tr ',' '\n' | grep -v "$target_id" | sed 's/^ *//' | paste -sd "," -)
    gsettings set org.cinnamon enabled-applets "[$new_list]"

    zenity --info --text="Barre $target_id réinitialisée."
fi

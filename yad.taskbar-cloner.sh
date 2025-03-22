#!/bin/bash

# Lire les applets actifs
applets_raw=$(gsettings get org.cinnamon enabled-applets)

# Extraire les panels actifs
panels=$(echo "$applets_raw" | grep -oE "panel[0-9]+" | sort -u)

# Préparer la liste informative + dropdown
info_text="		 		                Welcome to Task-Bar Cloner!\n\nAvailable bars detected:\n"
dropdown_list=""

# Extraire la disposition des panels

panel_positions=$(gsettings get org.cinnamon panels-enabled | tr -d "[]',")

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

    # Zone (left, center, right) selon les applets
    zone=$(echo "$applets_raw" | grep -oE "$panel:(left|center|right)" | head -n1 | cut -d':' -f2)
    [ -z "$zone" ] && zone="unknown"

    info_text+=" - ${panel} : ${zone} ${position}\n"
    dropdown_list+="${panel} (${zone} ${position})!"
done


# Nettoyage final
dropdown_list="${dropdown_list%!}"

# Interface principale YAD
selection=$(yad --form \
    --title="Cloner ou Réinitialiser une barre Cinnamon" \
    --text="$info_text" \
    --field="Barre Source:CB" "$dropdown_list" \
    --field="Barre Cible:CB" "$dropdown_list" \
    --field="Action:CB" "Cloner!Réinitialiser" \
    --width=450 --height=300 --center)

# Si annulation
[ $? -ne 0 ] && exit 1

# Analyse des choix
IFS="|" read -r source_label target_label action <<< "$selection"
source_panel=$(echo "$source_label" | cut -d' ' -f1)
target_panel=$(echo "$target_label" | cut -d' ' -f1)

# Lire les applets actuels
enabled_applets=$(gsettings get org.cinnamon enabled-applets)

if [ "$action" = "Réinitialiser" ]; then
    new_list=$(echo "$enabled_applets" | sed "s/['\[\]]//g" | tr ',' '\n' | grep -v "$target_panel" | sed 's/^ *//' | paste -sd "," -)
    gsettings set org.cinnamon enabled-applets "[$new_list]"
    yad --info --text="Barre $target_panel réinitialisée."
else
    source_items=$(echo "$enabled_applets" | sed "s/['\[\]]//g" | tr ',' '\n' | grep "$source_panel" | sed 's/^ *//')
    cloned_items=$(echo "$source_items" | sed "s/$source_panel/$target_panel/")
    cleaned=$(echo "$enabled_applets" | sed "s/['\[\]]//g" | tr ',' '\n' | grep -v "$target_panel" | sed 's/^ *//')
    final=$(printf "%s\n%s" "$cleaned" "$cloned_items" | paste -sd "," -)
    gsettings set org.cinnamon enabled-applets "[$final]"
    yad --info --text="Barre $target_panel clonée à partir de $source_panel."
fi

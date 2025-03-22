#!/bin/bash

PROFILE_FILE="$HOME/.profile"

# Fonction pour insérer ou mettre à jour le segment dans .profile
update_profile_segment() {
    local TMP_SEGMENT
    TMP_SEGMENT=$(mktemp)

    cat > "$TMP_SEGMENT" <<EOF
# Set wallpaper feh variables
# START
export WALL_PATH_A="$WALL_PATH_A"
export WALL_PATH_B="$WALL_PATH_B"
export IMG_A_MODE="$IMG_A_MODE"
export IMG_B_MODE="$IMG_B_MODE"
# END
EOF

    if grep -q "# START" "$PROFILE_FILE" && grep -q "# END" "$PROFILE_FILE"; then
        # Remplace le bloc existant
        awk -v file="$TMP_SEGMENT" '
            BEGIN { while ((getline line < file) > 0) lines[++n] = line; close(file) }
            /# START/ { in_block = 1; print lines[1]; for (i = 2; i <= n; i++) print lines[i]; next }
            /# END/ && in_block { in_block = 0; next }
            !in_block
        ' "$PROFILE_FILE" > "${PROFILE_FILE}.tmp" && mv "${PROFILE_FILE}.tmp" "$PROFILE_FILE"
    else
        # Ajoute le bloc à la fin
        echo -e "\n$(cat "$TMP_SEGMENT")" >> "$PROFILE_FILE"
    fi

    rm -f "$TMP_SEGMENT"
}


# Variables temporaires
TMP_PATH_A=""
TMP_PATH_B=""
TMP_A_MODE=""
TMP_B_MODE=""

# Sélection image A
TMP_PATH_A=$(yad --file-selection --title="Sélectionner un fond d'écran pour A" \
    --file-filter="Images | *.jpg *.png *.jpeg" --width=800 --height=600 --center)
if [[ -z "$TMP_PATH_A" ]]; then
    yad --info --text="Procédure annulée. Aucune variable n'a été modifiée." --title="Annulé" --center
    exit 0
fi

# Sélection image B
TMP_PATH_B=$(yad --file-selection --title="Sélectionner un fond d'écran pour B" \
    --file-filter="Images | *.jpg *.png *.jpeg" --width=800 --height=600 --center)
if [[ -z "$TMP_PATH_B" ]]; then
    yad --info --text="Procédure annulée. Aucune variable n'a été modifiée." --title="Annulé" --center
    exit 0
fi

# Mode image A
TMP_A_MODE=$(yad --list --title="Mode d'affichage pour A" --column="Modes" \
    --text="Choisissez le mode d'affichage pour A :" \
    "bg-scale" "bg-fill" "bg-center" "bg-max" "bg-tile" --center --width=300 --height=250)
if [[ -z "$TMP_A_MODE" ]]; then
    yad --info --text="Procédure annulée. Aucune variable n'a été modifiée." --title="Annulé" --center
    exit 0
fi

# Mode image B
TMP_B_MODE=$(yad --list --title="Mode d'affichage pour B" --column="Modes" \
    --text="Choisissez le mode d'affichage pour B :" \
    "bg-scale" "bg-fill" "bg-center" "bg-max" "bg-tile" --center --width=300 --height=250)
if [[ -z "$TMP_B_MODE" ]]; then
    yad --info --text="Procédure annulée. Aucune variable n'a été modifiée." --title="Annulé" --center
    exit 0
fi

# Nettoyage sécurité
TMP_A_MODE=$(echo "$TMP_A_MODE" | tr -d '|')
TMP_B_MODE=$(echo "$TMP_B_MODE" | tr -d '|')

# Transfert vers variables finales
WALL_PATH_A="$TMP_PATH_A"
WALL_PATH_B="$TMP_PATH_B"
IMG_A_MODE="$TMP_A_MODE"
IMG_B_MODE="$TMP_B_MODE"

# Mise à jour du fichier .profile
update_profile_segment

# Demande d'application immédiate
yad --question --text="Les variables ont été mises à jour. Voulez-vous appliquer les changements maintenant ou attendre la prochaine connexion ?" \
    --title="Appliquer maintenant ou attendre ?" --button="Appliquer maintenant":0 --button="Attendre":1

if [ $? -eq 0 ]; then
    source "$PROFILE_FILE" && feh --"$IMG_A_MODE" "$WALL_PATH_A" --"$IMG_B_MODE" "$WALL_PATH_B"
    yad --info --text="Les changements ont été appliqués immédiatement !" --title="Succès" --center
else
    yad --info --text="Les changements seront appliqués lors de la prochaine connexion." --title="Succès" --center
fi

#!/bin/bash

CONFIG_FILE="$HOME/.config/wallpapers.conf"
WALLPAPER_DIR="$HOME/Wallpapers"
DEFAULT_WALLPAPER="$WALLPAPER_DIR/default.jpg"

# Liste les écrans connectés
SCREENS=$(xrandr --listmonitors | awk '{print $4}' | grep -v '^$')

# Effacer le fichier de config existant
echo "# Wallpaper configuration per screen" > "$CONFIG_FILE"

# Variables temporaires pour éviter d'appliquer si l'utilisateur annule
TEMP_IMAGE_A=""
TEMP_IMAGE_B=""
TEMP_MODE_IMG_A=""
TEMP_MODE_IMG_B=""
COUNT=1

# Créer une fenêtre zenity en plein écran
zenity --info --text="La fenêtre Zenity sera en plein écran." --title="Informations" --width=100 --height=100 --fullscreen

for SCREEN in $SCREENS; do
    # Demander à l'utilisateur de choisir un fichier image avec une fenêtre plus grande
    IMAGE=$(zenity --file-selection --title="Sélectionner un fond d'écran pour $SCREEN" \
        --file-filter="Images | *.jpg *.png *.jpeg" \
        --fullscreen)

    # Si l'utilisateur annule (aucune image sélectionnée), afficher un message et sortir du script
    if [[ -z "$IMAGE" ]]; then
        zenity --info --text="Aucun changement effectué. Procédure annulée." --title="Annulation" --fullscreen
        exit 0  # Arrêter le script sans effectuer de modifications
    fi

    # Demander à l'utilisateur quel mode appliquer
    MODE=$(zenity --list --title="Mode d'affichage pour $SCREEN" --column="Modes" --hide-header \
        --text="Choisissez comment afficher le fond d'écran sur $SCREEN :" \
        "bg-scale" "bg-fill" "bg-center" "bg-max" "bg-tile" --fullscreen)

    # Si l'utilisateur annule, afficher un message et sortir du script
    if [[ -z "$MODE" ]]; then
        zenity --info --text="Aucun changement effectué. Procédure annulée." --title="Annulation" --fullscreen
        exit 0  # Arrêter le script sans effectuer de modifications
    fi

    # Enregistrer les choix temporairement pour chaque écran
    if [[ "$COUNT" -eq 1 ]]; then
        TEMP_IMAGE_A="$IMAGE"
        TEMP_MODE_IMG_A="$MODE"
    elif [[ "$COUNT" -eq 2 ]]; then
        TEMP_IMAGE_B="$IMAGE"
        TEMP_MODE_IMG_B="$MODE"
    fi

    # Sauvegarder la configuration dans le fichier seulement après tous les choix
    if [[ "$COUNT" -eq 1 ]]; then
        echo "export WALL_PATH_A=\"$TEMP_IMAGE_A\"" >> "$HOME/.profile"
        echo "$SCREEN=$TEMP_IMAGE_A $TEMP_MODE_IMG_A" >> "$CONFIG_FILE"
    elif [[ "$COUNT" -eq 2 ]]; then
        echo "export WALL_PATH_B=\"$TEMP_IMAGE_B\"" >> "$HOME/.profile"
        echo "$SCREEN=$TEMP_IMAGE_B $TEMP_MODE_IMG_B" >> "$CONFIG_FILE"
    fi

    ((COUNT++))
done

# Finalisation
zenity --info --text="Configuration enregistrée ! Les nouvelles valeurs seront appliquées à la prochaine connexion." --title="Succès" --fullscreen

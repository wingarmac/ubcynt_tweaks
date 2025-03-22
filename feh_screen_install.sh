#!/bin/bash

# Définir les répertoires d'installation
DIR_A="/usr/local/bin"
DIR_B="$HOME/.config/autostart"
DESKTOP_DIR="$HOME/Desktop"

# Vérification de l'existence des répertoires
echo "Vérification des répertoires d'installation..."

# Créer le répertoire d'autostart si nécessaire (pas de sudo requis)
if [ ! -d "$DIR_B" ]; then
    mkdir -p "$DIR_B"
    echo "Création du répertoire $DIR_B"
fi

# Créer le répertoire Desktop si nécessaire (pas de sudo requis)
if [ ! -d "$DESKTOP_DIR" ]; then
    mkdir -p "$DESKTOP_DIR"
    echo "Création du répertoire $DESKTOP_DIR"
fi

# Créer le répertoire /usr/local/bin si nécessaire (sudo requis)
if [ ! -d "$DIR_A" ]; then
    echo "Le répertoire $DIR_A n'existe pas, il va être créé avec sudo."
    sudo mkdir -p "$DIR_A"
    sudo chown $USER:$USER "$DIR_A"  # Assurer que l'utilisateur peut écrire dans le répertoire
    echo "Création du répertoire $DIR_A avec sudo."
fi

# Copier les fichiers dans les répertoires appropriés
echo "Copie des fichiers dans les répertoires appropriés..."

# Copier set-wallpaper-gui.sh dans /usr/local/bin
cp ./set-wallpaper-gui.sh $DIR_A/set-wallpaper-gui.sh
echo "Copié set-wallpaper-gui.sh dans $DIR_A"

# Copier feh.desktop dans ~/.config/autostart
cp ./feh.desktop $DIR_B/feh.desktop
echo "Copié feh.desktop dans $DIR_B"

# Créer le fichier Feh_screen.desktop sur le bureau de l'utilisateur
echo "Création du fichier Feh_screen.desktop sur le bureau..."

cat << EOF > $DESKTOP_DIR/Feh_screen.desktop
[Desktop Entry]
Type=Application
Name=Feh-screen
GenericName=Feh-screen
X-GNOME-FullName=Feh-screen-wallpaper-setup
Exec=/usr/local/bin/set-wallpaper-gui.sh
Icon=system-config-display
Terminal=false
Categories=Display-settings;
EOF
echo "Fichier Feh_screen.desktop créé sur le bureau."

# Appliquer chmod si sudo a été utilisé pour créer le répertoire /usr/local/bin
if [ ! -d "$DIR_A" ]; then
    sudo chmod +x $DIR_A/set-wallpaper-gui.sh
    sudo chmod +x $DIR_B/feh.desktop
    sudo chmod +x $DESKTOP_DIR/Feh_screen.desktop
    echo "Fichiers rendus exécutables avec sudo."
else
    chmod +x $DIR_A/set-wallpaper-gui.sh
    chmod +x $DIR_B/feh.desktop
    chmod +x $DESKTOP_DIR/Feh_screen.desktop
    echo "Fichiers rendus exécutables."
fi

# Terminer avec un message de succès
echo "Installation terminée avec succès !"

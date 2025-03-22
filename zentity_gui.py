import gi
import subprocess
import os

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk

class AppWindow(Gtk.Window):

    def __init__(self):
        Gtk.Window.__init__(self, title="Message")

        # Créer une boîte verticale pour contenir le contenu
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.add(box)

        # Ajouter un label pour afficher le message
        self.message_label = Gtk.Label(label="Bonjour, voulez-vous procéder ?")
        box.add(self.message_label)

        # Ajouter un bouton pour répondre "OUI"
        self.button_yes = Gtk.Button(label="OUI")
        self.button_yes.connect("clicked", self.on_button_yes_clicked)
        box.add(self.button_yes)

        # Ajouter un bouton pour répondre "NON"
        self.button_no = Gtk.Button(label="NON")
        self.button_no.connect("clicked", self.on_button_no_clicked)
        box.add(self.button_no)

        # Centrer la fenêtre au lancement
        self.set_position(Gtk.WindowPosition.CENTER)

        # Afficher tous les composants
        self.show_all()

    def on_button_yes_clicked(self, widget):
        # Récupérer la position de la fenêtre
        x, y = self.get_position()

        # Définir le chemin du fichier zen.feh.vars
        zen_feh_vars_path = os.path.expanduser("~/feh_screen/zen.feh.vars")

        # Sauvegarder les coordonnées dans ~/feh_screen/zen.feh.vars
        with open(zen_feh_vars_path, "w") as file:
            file.write(f"Zenity_X={x}\nZenity_Y={y}\n")

        # Fermer la fenêtre
        self.close()

        # Lancer le script pour configurer le fond d'écran
        subprocess.run(["/usr/local/bin/set-wallpaper-gui.sh"])

        # Quitter le programme Python après l'exécution du script
        Gtk.main_quit()

    def on_button_no_clicked(self, widget):
        # Fermer la fenêtre si l'utilisateur clique sur "NON"
        self.close()

        # Quitter le programme Python sans lancer le script
        Gtk.main_quit()

# Créer la fenêtre et démarrer l'application GTK
win = AppWindow()
Gtk.main()

# PowerPolicyManager

Un gestionnaire interactif de politiques d'inactivité et d'économie d'énergie pour les systèmes Linux, permettant de configurer rapidement et facilement les comportements de mise en veille, d'hibernation, et de gestion d'alimentation.

![Version](https://img.shields.io/badge/version-1.1-blue.svg)
![Platform](https://img.shields.io/badge/platform-Linux-green.svg)
![GNOME](https://img.shields.io/badge/GNOME-Compatible-orange.svg)
![systemd](https://img.shields.io/badge/systemd-Compatible-purple.svg)

## 📋 Fonctionnalités

- ⚡ Configuration complète des paramètres d'économie d'énergie GNOME
- 🔄 Gestion des comportements sur batterie et sur secteur
- 💤 Configuration des actions à la fermeture du capot
- ⏱️ Paramétrage des délais de mise en veille
- 🛠️ Configuration de systemd-logind (actions sur bouton d'alimentation, etc.)
- 📱 Profils préconfigurés pour portables et PC fixes
- 📤 Export des configurations pour sauvegarde ou partage

## 🖼️ Captures d'écran

<center>
<em>Menu principal de l'application</em>
</center>

## 🚀 Installation

### Méthode simple

```bash
# Télécharger le script
wget https://raw.githubusercontent.com/votre-nom/PowerPolicyManager/main/power-policy-manager.sh

# Rendre le script exécutable
chmod +x power-policy-manager.sh

# Lancer le script
./power-policy-manager.sh
```

### Depuis les sources

```bash
# Cloner le dépôt
git clone https://github.com/votre-nom/PowerPolicyManager.git

# Entrer dans le répertoire
cd PowerPolicyManager

# Rendre le script exécutable
chmod +x power-policy-manager.sh

# Lancer le script
./power-policy-manager.sh
```

## 📝 Prérequis

- Un système Linux avec GNOME et/ou systemd
- Le paquet `gsettings-desktop-schemas` ou `gnome-settings-daemon`
- Droits sudo pour modifier les paramètres systemd-logind

## 🔧 Utilisation

L'interface est entièrement interactive et guidée. Après avoir lancé le script, vous pourrez :

1. Parcourir les paramètres disponibles sur votre système
2. Modifier individuellement chaque paramètre
3. Appliquer des configurations prédéfinies (portable ou PC fixe)
4. Consulter des conseils de configuration adaptés à votre matériel
5. Exporter votre configuration actuelle

## 📚 Paramètres configurables

### Paramètres GNOME

- Délais de mise en veille (secteur et batterie)
- Actions après inactivité (veille, hibernation, extinction...)
- Comportement à la fermeture du capot
- Atténuation de l'écran en cas d'inactivité
- Profil d'économie d'énergie sur batterie faible

### Paramètres systemd-logind

- Actions sur pression du bouton d'alimentation
- Actions sur fermeture du capot (avec ou sans écran externe)
- Actions après inactivité prolongée
- Comportement des touches de mise en veille/hibernation

## 🔍 Conseils d'utilisation

- Sur un portable, privilégiez des délais courts sur batterie (5-10 minutes)
- Pour économiser la batterie, utilisez l'action "suspend" après inactivité
- Pour la sécurité, configurez au moins le verrouillage de l'écran
- Sur un PC fixe, des délais plus longs sont généralement préférables

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :

1. Fork le projet
2. Créer une branche pour votre fonctionnalité (`git checkout -b feature/AmazingFeature`)
3. Commit vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

## 📄 Licence

Ce projet est distribué sous licence MIT. Voir le fichier `LICENSE` pour plus d'informations.

## 🙏 Remerciements

- Merci à la communauté GNOME pour la documentation sur GSettings
- Merci à la communauté systemd pour la documentation sur logind.conf

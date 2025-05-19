#!/bin/bash

# ==============================================================================
# Script de gestion des politiques d'inactivité système
# Permet de configurer les paramètres de mise en veille et d'économie d'énergie
# sur les systèmes GNOME et via logind.conf
# ==============================================================================

# === CONFIGURATION TERMINAL ET COULEURS ===
if [ -t 1 ]; then
    NC="\e[0m";      # Normal
    RED="\e[1;31m";  # Rouge en gras
    GREEN="\e[1;32m"; # Vert en gras
    YELLOW="\e[1;33m"; # Jaune en gras
    BLUE="\e[1;34m"; # Bleu en gras
    PURPLE="\e[1;35m"; # Violet en gras
    CYAN="\e[1;36m"; # Cyan en gras
    BOLD="\e[1m";    # Gras
    DIM="\e[2m";     # Estompé
    BLINK="\e[5m";   # Clignotant
    INVERT="\e[7m";  # Inversé
    UNDERLINE="\e[4m"; # Souligné
else
    NC=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; PURPLE=""; CYAN=""; BOLD=""; DIM=""; BLINK=""; INVERT=""; UNDERLINE=""
fi

# === VARIABLES GLOBALES ===
SCHEMA="org.gnome.settings-daemon.plugins.power"
LOGIND_CONF="/etc/systemd/logind.conf"
TEMP_FILE="/tmp/logind.conf.tmp"
VERSION="1.1"

# === CLÉS GSETTINGS COMPLÈTES (toutes versions GNOME) ===
ALL_KEYS=(
  "ambient-enabled"                              # capteur de lumière ambiante
  "idle-dim"                                     # atténuer l'écran au repos
  "idle-brightness"                              # niveau de luminosité quand idle
  "power-saver-profile-on-low-battery"           # profil économie quand batterie faible
  "sleep-inactive-ac-timeout"                    # délai avant arrêt sur secteur (s)
  "sleep-inactive-ac-type"                       # action après délai sur secteur
  "sleep-inactive-battery-timeout"               # délai avant arrêt sur batterie (s)
  "sleep-inactive-battery-type"                  # action après délai sur batterie
  "power-button-action"                          # action appui bouton marche
  "lid-close-ac-action"                          # action fermeture capot sur secteur
  "lid-close-battery-action"                     # action fermeture capot sur batterie
  "lid-close-suspend-with-external-monitor"      # suspendre malgré écran externe
)

# === TABLE DE CORRESPONDANCE GSETTINGS → logind.conf ===
declare -A GNOME_TO_LOGIND=(
  ["power-button-action"]="HandlePowerKey"
  ["sleep-inactive-ac-type"]="IdleAction"
  ["sleep-inactive-battery-type"]="IdleAction"
  ["lid-close-ac-action"]="HandleLidSwitchExternalPower"
  ["lid-close-battery-action"]="HandleLidSwitch"
  ["lid-close-suspend-with-external-monitor"]="HandleLidSwitchDocked"
)

# === CLÉS logind.conf COMPLÈTES (man logind.conf) ===
ALL_LOGIND_KEYS=(
  "NAutoVTs"
  "ReserveVT"
  "KillUserProcesses"
  "KillOnlyUsers"
  "KillExcludeUsers"
  "InhibitDelayMaxSec"
  "UserStopDelaySec"
  "SleepOperation"
  "HandlePowerKey"
  "HandlePowerKeyLongPress"
  "HandleSuspendKey"
  "HandleSuspendKeyLongPress"
  "HandleHibernateKey"
  "HandleHibernateKeyLongPress"
  "HandleRebootKey"
  "HandleRebootKeyLongPress"
  "HandleLidSwitch"
  "HandleLidSwitchExternalPower"
  "HandleLidSwitchDocked"
  "PowerKeyIgnoreInhibited"
  "SuspendKeyIgnoreInhibited"
  "HibernateKeyIgnoreInhibited"
  "LidSwitchIgnoreInhibited"
  "RebootKeyIgnoreInhibited"
  "HoldoffTimeoutSec"
  "IdleAction"
  "IdleActionSec"
  "RuntimeDirectorySize"
  "RuntimeDirectoryInodesMax"
  "RemoveIPC"
  "InhibitorsMax"
  "SessionsMax"
  "StopIdleSessionSec"
  "DesignatedMaintenanceTime"
)

# === VALEURS POSSIBLES POUR logind.conf ===
declare -A LOGIND_OPTIONS=(
  ["HandlePowerKey"]="ignore poweroff reboot halt kexec suspend hibernate hybrid-sleep"
  ["HandlePowerKeyLongPress"]="ignore poweroff reboot halt kexec suspend hibernate hybrid-sleep"
  ["HandleSuspendKey"]="ignore suspend hibernate hybrid-sleep"
  ["HandleSuspendKeyLongPress"]="ignore suspend hibernate hybrid-sleep"
  ["HandleHibernateKey"]="ignore hibernate hybrid-sleep"
  ["HandleHibernateKeyLongPress"]="ignore hibernate hybrid-sleep"
  ["HandleRebootKey"]="ignore reboot"
  ["HandleRebootKeyLongPress"]="ignore reboot"
  ["HandleLidSwitch"]="ignore poweroff reboot halt kexec suspend hibernate hybrid-sleep lock"
  ["HandleLidSwitchExternalPower"]="ignore poweroff reboot halt kexec suspend hibernate hybrid-sleep lock"
  ["HandleLidSwitchDocked"]="ignore poweroff reboot halt kexec suspend hibernate hybrid-sleep lock"
  ["IdleAction"]="ignore poweroff reboot halt kexec suspend hibernate hybrid-sleep lock"
  # pour les clés temps / numériques, pas de liste : on laisse vide ou on indique 'seconds'
  ["IdleActionSec"]="seconds"
  ["HoldoffTimeoutSec"]="seconds"
  ["UserStopDelaySec"]="seconds"
)

# === DESCRIPTIONS GSETTINGS ===
declare -A KEY_DESCRIPTIONS=(
  ["ambient-enabled"]="Active le capteur de lumière ambiante"
  ["idle-dim"]="Atténue l'écran après inactivité"
  ["idle-brightness"]="Luminosité de l'écran une fois inactif"
  ["power-saver-profile-on-low-battery"]="Active le profil économie d'énergie quand la batterie est faible"
  ["sleep-inactive-ac-timeout"]="Temps avant mise en veille (secteur), en secondes"
  ["sleep-inactive-ac-type"]="Action après délai (secteur) : suspend, hibernate, nothing"
  ["sleep-inactive-battery-timeout"]="Temps avant mise en veille (batterie), en secondes"
  ["sleep-inactive-battery-type"]="Action après délai (batterie) : suspend, hibernate, nothing"
  ["power-button-action"]="Action lors d'un appui sur le bouton d'alimentation"
  ["lid-close-ac-action"]="Action à la fermeture du capot (secteur)"
  ["lid-close-battery-action"]="Action à la fermeture du capot (batterie)"
  ["lid-close-suspend-with-external-monitor"]="Suspendre même si un écran externe est connecté"
)

# === DESCRIPTIONS logind.conf ===
declare -A LOGIND_DESCRIPTIONS=(
  ["HandlePowerKey"]="Définit l'action du bouton d'alimentation"
  ["HandlePowerKeyLongPress"]="Action pour un appui long sur le bouton d'alimentation"
  ["HandleSuspendKey"]="Action sur la touche de suspension"
  ["HandleSuspendKeyLongPress"]="Action sur un appui long de la touche suspension"
  ["HandleHibernateKey"]="Action sur la touche d'hibernation"
  ["HandleHibernateKeyLongPress"]="Action sur un appui long de la touche d'hibernation"
  ["HandleRebootKey"]="Action sur la touche de redémarrage"
  ["HandleRebootKeyLongPress"]="Action sur un appui long de la touche de redémarrage"
  ["HandleLidSwitch"]="Action à la fermeture du capot (toutes sources d'alimentation)"
  ["HandleLidSwitchExternalPower"]="Action à la fermeture du capot (secteur uniquement)"
  ["HandleLidSwitchDocked"]="Action si le capot est fermé et un écran externe est connecté"
  ["IdleAction"]="Action après période d'inactivité (suspend, hibernate, nothing)"
  ["IdleActionSec"]="Temps avant déclenchement de l'action d'inactivité (ex: 10min, 1h)"
  ["LidSwitchIgnoreInhibited"]="Ignore les inhibitions de capot (ex: vidéos plein écran)"
  ["PowerKeyIgnoreInhibited"]="Ignore les inhibitions du bouton d'alimentation"
  ["SuspendKeyIgnoreInhibited"]="Ignore les inhibitions de la touche de suspension"
  ["HibernateKeyIgnoreInhibited"]="Ignore les inhibitions de la touche d'hibernation"
  ["RebootKeyIgnoreInhibited"]="Ignore les inhibitions de la touche de redémarrage"
  ["NAutoVTs"]="Nombre de consoles virtuelles à créer automatiquement"
  ["ReserveVT"]="Quel TTY est réservé pour Xorg"
  ["KillUserProcesses"]="Tue les processus utilisateur à la fermeture de session"
  ["KillOnlyUsers"]="Utilisateurs affectés par KillUserProcesses"
  ["KillExcludeUsers"]="Utilisateurs exclus de KillUserProcesses"
  ["InhibitDelayMaxSec"]="Délai maximal autorisé avant action inhibée"
  ["UserStopDelaySec"]="Délai avant arrêt des sessions utilisateur"
  ["SleepOperation"]="Spécifie une opération de mise en veille personnalisée"
  ["HoldoffTimeoutSec"]="Délai avant une action critique système"
  ["RuntimeDirectorySize"]="Taille maximale des répertoires temporaires /run"
  ["RuntimeDirectoryInodesMax"]="Nombre maximum d'inodes dans /run"
  ["RemoveIPC"]="Supprimer la mémoire IPC à la déconnexion"
  ["InhibitorsMax"]="Nombre maximum d'inhibiteurs"
  ["SessionsMax"]="Nombre maximal de sessions utilisateur"
  ["StopIdleSessionSec"]="Temps avant fermeture d'une session inactive"
  ["DesignatedMaintenanceTime"]="Heure désignée pour maintenance planifiée"
)

# === VARIABLES GLOBALES À INITIALISER ===
AVAILABLE_KEYS=()
MISSING_KEYS=()
declare -A CURRENT_VALUES
AVAILABLE_LOGIND_KEYS=()
SYSTEM_INFO=""

# === FONCTIONS UTILITAIRES ===

# Affiche une barre de progression pendant l'exécution d'une commande
show_spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf "\r[%c] " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
  done
  printf "\r    \r"
}

# Formate le temps en secondes dans un format lisible
format_time_seconds() {
  local seconds=$1
  if [[ $seconds -eq 0 ]]; then
    echo "Désactivé"
    return
  fi
  
  local days=$((seconds / 86400))
  local hours=$(( (seconds % 86400) / 3600 ))
  local minutes=$(( (seconds % 3600) / 60 ))
  local secs=$((seconds % 60))
  
  local result=""
  [[ $days -gt 0 ]] && result+="${days}j "
  [[ $hours -gt 0 ]] && result+="${hours}h "
  [[ $minutes -gt 0 ]] && result+="${minutes}m "
  [[ $secs -gt 0 || -z "$result" ]] && result+="${secs}s"
  
  echo "$result"
}

# Vérifie si une clé GSettings existe
key_exists() {
  gsettings list-keys "$SCHEMA" 2>/dev/null | grep -qx "$1"
}

# Obtient la valeur actuelle d'une clé GSettings
get_current_value() {
  local key=$1
  local val
  val=$(gsettings get "$SCHEMA" "$key" 2>/dev/null)
  
  # Si c'est une string entourée de quotes, on enlève les quotes
  if [[ "$val" =~ ^\'.*\'$ ]]; then
    val="${val:1:-1}"
  elif [[ "$val" == *"uint32"* ]]; then
    val=$(echo "$val" | sed 's/uint32 //g')
  fi
  
  # Formatage des valeurs temporelles pour une meilleure lisibilité
  if [[ "$key" == *timeout* && "$val" =~ ^[0-9]+$ ]]; then
    CURRENT_VALUES["$key"]="$val ($(format_time_seconds "$val"))"
  else
    CURRENT_VALUES["$key"]="$val"
  fi
}

# Vérifie si une clé logind existe dans la configuration
logind_key_exists() {
  grep -q "^\s*$1=" "$LOGIND_CONF" 2>/dev/null
}

# Obtient la valeur actuelle d'une clé logind
get_logind_value() {
  local key=$1
  local val
  val=$(grep "^\s*$key=" "$LOGIND_CONF" 2>/dev/null | cut -d'=' -f2-)
  echo "$val"
}

# Modifie une clé dans logind.conf
edit_logind_action() {
  local key=$1 val=$2
  local temp_file=$(mktemp)
  local found=0
  
  echo -e "\n${YELLOW}[LOGIND]${NC} Configuration: ${CYAN}${key}=${val}${NC}"
  
  # Vérifier si le fichier existe
  if [ ! -f "$LOGIND_CONF" ]; then
    echo -e "${RED}✘ Fichier $LOGIND_CONF n'existe pas.${NC}"
    echo -e "${YELLOW}► Création du fichier...${NC}"
    sudo mkdir -p "$(dirname "$LOGIND_CONF")"
    echo "[Login]" | sudo tee "$LOGIND_CONF" > /dev/null
  fi
  
  # Lire le fichier et remplacer ou décommenter la ligne si elle existe
  cat "$LOGIND_CONF" | while IFS= read -r line; do
    if [[ "$line" =~ ^#?[[:space:]]*"$key"= ]]; then
      echo "$key=$val" >> "$temp_file"
      found=1
    else
      echo "$line" >> "$temp_file"
    fi
  done
  
  # Si la clé n'a pas été trouvée, l'ajouter à la fin
  if [ "$found" -eq 0 ]; then
    # S'assurer qu'il y a une section [Login]
    if ! grep -q '^\[Login\]' "$temp_file"; then
      echo "[Login]" >> "$temp_file"
    fi
    echo "$key=$val" >> "$temp_file"
  fi
  
  # Appliquer les modifications
  sudo cp "$temp_file" "$LOGIND_CONF"
  rm "$temp_file"
  
  echo -e "${GREEN}✔ Modifié/ajouté dans logind.conf${NC}"
  echo -e "${YELLOW}► Redémarrage du service logind nécessaire pour appliquer les changements.${NC}"
  
  read -p "$(echo -e "${BLUE}Redémarrer logind maintenant ? [o/N] :${NC} ")" restart
  if [[ "$restart" =~ ^[Oo]$ ]]; then
    echo -e "${YELLOW}► Redémarrage de systemd-logind...${NC}"
    sudo systemctl restart systemd-logind && echo -e "${GREEN}✔ Service redémarré avec succès.${NC}" || echo -e "${RED}✘ Échec du redémarrage du service.${NC}"
  fi
  
  read -p "$(echo -e "${DIM}Appuyer sur Entrée pour continuer...${NC}")"
}

# Demande confirmation et exécute une commande
confirm_and_run() {
  local cmd="$1"
  local title="${2:-Commande}"
  
  echo -e "\n${YELLOW}➤ $title:${NC} ${CYAN}${cmd}${NC}"
  read -p "$(echo -e "   ${BLUE}Exécuter ? [o/N] :${NC} ")" rep
  
  if [[ "$rep" =~ ^[Oo]$ ]]; then
    echo -e "${YELLOW}► Exécution...${NC}"
    eval "$cmd" && echo -e "${GREEN}✔ Succès${NC}" || echo -e "${RED}✘ Échec${NC}"
  else
    echo -e "${RED}✘ Annulé${NC}"
  fi
  
  echo; read -p "$(echo -e "${DIM}Appuyer sur Entrée pour continuer...${NC}")"
}

# Configure un paramètre (GSettings ou logind)
set_parameter() {
  local key="$1"
  
  # Afficher l'en-tête
  show_header "Configuration du paramètre"
  
  if key_exists "$key"; then
    echo -e "${CYAN}➤ [GSettings] Paramètre : $key${NC}"
    echo -e "${YELLOW}Description : ${KEY_DESCRIPTIONS[$key]:-Aucune description disponible}${NC}"
    echo -e "${GREEN}Valeur actuelle : ${CURRENT_VALUES[$key]}${NC}"
    
    # Afficher des informations supplémentaires selon le type de paramètre
    if [[ "$key" == *timeout* ]]; then
      echo -e "${YELLOW}Type attendu : ${UNDERLINE}entier (secondes)${NC}"
      echo -e "${DIM}Exemples: 60 (1 minute), 300 (5 minutes), 1800 (30 minutes), 3600 (1 heure)${NC}"
    elif [[ "$key" == *type* || "$key" == *action* ]]; then
      echo -e "${YELLOW}Type attendu : ${UNDERLINE}chaîne${NC}"
      echo -e "${DIM}Valeurs typiques: suspend, hibernate, nothing, poweroff, interactive${NC}"
    elif [[ "$key" == *enabled* || "$key" == *-dim ]]; then
      echo -e "${YELLOW}Type attendu : ${UNDERLINE}booléen${NC}"
      echo -e "${DIM}Valeurs: true, false${NC}"
    elif [[ "$key" == *brightness* ]]; then
      echo -e "${YELLOW}Type attendu : ${UNDERLINE}double${NC}"
      echo -e "${DIM}Valeurs: 0.0 - 1.0${NC}"
    fi
    
    read -p "$(echo -e "${BLUE}Nouvelle valeur : ${NC}")" new_val
    if [[ -n "$new_val" ]]; then
      confirm_and_run "gsettings set $SCHEMA $key '$new_val'" "Mise à jour GSettings"
    else
      echo -e "${RED}✘ Opération annulée - valeur vide${NC}"
      read -p "$(echo -e "${DIM}Appuyer sur Entrée pour continuer...${NC}")"
    fi
    return
  fi
  
  if [[ -n "${GNOME_TO_LOGIND[$key]}" ]]; then
    logind_key="${GNOME_TO_LOGIND[$key]}"
    echo -e "${CYAN}➤ [Conversion] Clé GNOME '$key' absente, utilisation de la clé logind '$logind_key'${NC}"
    echo -e "${YELLOW}Description : ${LOGIND_DESCRIPTIONS[$logind_key]:-Aucune description disponible}${NC}"
    
    # Afficher les valeurs possibles
    if [[ -n "${LOGIND_OPTIONS[$logind_key]}" ]]; then
      echo -e "${GREEN}Valeurs possibles : ${LOGIND_OPTIONS[$logind_key]}${NC}"
    fi
    
    read -p "$(echo -e "${BLUE}Nouvelle valeur pour $logind_key : ${NC}")" log_val
    if [[ -n "$log_val" ]]; then
      edit_logind_action "$logind_key" "$log_val"
    else
      echo -e "${RED}✘ Opération annulée - valeur vide${NC}"
      read -p "$(echo -e "${DIM}Appuyer sur Entrée pour continuer...${NC}")"
    fi
    return
  fi
  
  echo -e "${RED}✘ Clé $key non disponible dans votre version de GNOME, et aucune correspondance logind connue.${NC}"
  read -p "$(echo -e "${DIM}Appuyer sur Entrée pour continuer...${NC}")"
}

# Charge les clés GSettings disponibles
load_keys() {
  AVAILABLE_KEYS=()
  MISSING_KEYS=()
  
  for key in "${ALL_KEYS[@]}"; do
    if key_exists "$key"; then
      AVAILABLE_KEYS+=("$key")
      get_current_value "$key"
    else
      MISSING_KEYS+=("$key")
    fi
  done
}

# Charge les clés logind disponibles
load_logind_keys() {
  AVAILABLE_LOGIND_KEYS=()
  
  # Vérifier si le fichier logind.conf existe
  if [ ! -f "$LOGIND_CONF" ]; then
    return
  fi
  
  for key in "${ALL_LOGIND_KEYS[@]}"; do
    if logind_key_exists "$key"; then
      AVAILABLE_LOGIND_KEYS+=("$key")
    fi
  done
}

# Affiche un en-tête stylisé
show_header() {
  local title="$1"
  local width=72
  local padding=$(( (width - ${#title} - 2) / 2 ))
  local left_padding=$padding
  local right_padding=$padding
  
  # Ajuster si la longueur du titre est impaire
  if [ $(( (width - ${#title} - 2) % 2 )) -ne 0 ]; then
    right_padding=$((right_padding + 1))
  fi
  
  echo
  echo -e "${BLUE}╔$(printf '═%.0s' $(seq 1 $width))╗${NC}"
  echo -e "${BLUE}║$(printf ' %.0s' $(seq 1 $left_padding)) ${BOLD}${title}${NC}${BLUE} $(printf ' %.0s' $(seq 1 $right_padding))║${NC}"
  echo -e "${BLUE}╚$(printf '═%.0s' $(seq 1 $width))╝${NC}"
  echo
}

# Collecte des informations système
collect_system_info() {
  local gnome_version=$(gnome-shell --version 2>/dev/null | cut -d' ' -f3 || echo "Non installé")
  local kernel_version=$(uname -r)
  local distro=$(lsb_release -sd 2>/dev/null || cat /etc/*release | head -n 1 || echo "Distribution inconnue")
  local power_supply=$(ls /sys/class/power_supply/ 2>/dev/null | grep -i bat | wc -l)
  
  # Déterminer si c'est un portable ou un PC fixe
  local system_type="PC Fixe"
  if [ "$power_supply" -gt 0 ]; then
    system_type="Portable"
  fi
  
  SYSTEM_INFO="GNOME: $gnome_version | Kernel: $kernel_version | Système: $system_type | Distro: $distro"
}

# Afficher l'interface d'aide
show_help() {
  show_header "Aide et Documentation"
  
  echo -e "${BOLD}${UNDERLINE}À propos de cet outil:${NC}"
  echo -e "Ce script permet de configurer les politiques d'inactivité et de gestion d'énergie"
  echo -e "sur les systèmes Linux utilisant GNOME ou systemd-logind."
  echo
  
  echo -e "${BOLD}${UNDERLINE}Fonctionnalités principales:${NC}"
  echo -e "1. ${BOLD}Configuration des paramètres GNOME:${NC}"
  echo -e "   - Délais de mise en veille (secteur et batterie)"
  echo -e "   - Actions de mise en veille (suspend, hibernate, nothing)"
  echo -e "   - Comportement à la fermeture du capot"
  echo
  
  echo -e "2. ${BOLD}Configuration de systemd-logind:${NC}"
  echo -e "   - Actions sur pression des boutons (alimentation, veille)"
  echo -e "   - Comportement à la fermeture du capot"
  echo -e "   - Gestion des périodes d'inactivité"
  echo
  
  echo -e "${BOLD}${UNDERLINE}Conseils d'utilisation:${NC}"
  echo -e "• ${YELLOW}Délais de mise en veille:${NC} Valeurs en secondes"
  echo -e "  Exemples: 300 (5min), 1800 (30min), 3600 (1h), 0 (désactivé)"
  echo
  echo -e "• ${YELLOW}Types d'actions:${NC}"
  echo -e "  - ${GREEN}nothing${NC}: Ne rien faire"
  echo -e "  - ${GREEN}suspend${NC}: Mise en veille (RAM)"
  echo -e "  - ${GREEN}hibernate${NC}: Hibernation (disque)"
  echo -e "  - ${GREEN}hybrid-sleep${NC}: Veille hybride"
  echo -e "  - ${GREEN}poweroff${NC}: Extinction"
  echo -e "  - ${GREEN}lock${NC}: Verrouiller l'écran"
  echo -e "  - ${GREEN}ignore${NC}: Ignorer l'événement"
  echo
  
  echo -e "${BOLD}${UNDERLINE}Conseils de configuration:${NC}"
  echo -e "• Pour un portable: configurez les actions sur secteur et sur batterie"
  echo -e "• Pour économiser l'énergie: utilisez suspend ou hibernate sur batterie"
  echo -e "• Pour la sécurité: configurez au moins le verrouillage sur inactivité"
  echo
  
  read -p "$(echo -e "${DIM}Appuyer sur Entrée pour revenir au menu principal...${NC}")"
}

# Exporter la configuration actuelle
export_config() {
  show_header "Exporter la configuration"
  
  local export_file="$HOME/power-policy-export-$(date +%Y%m%d-%H%M%S).conf"
  echo -e "${YELLOW}► Exportation vers ${export_file}...${NC}"
  
  # Créer le fichier d'export
  echo "# Configuration des politiques d'inactivité" > "$export_file"
  echo "# Exporté le $(date)" >> "$export_file"
  echo "# Système: $SYSTEM_INFO" >> "$export_file"
  echo "" >> "$export_file"
  
  # Exporter les paramètres GSettings
  echo "[GSettings: $SCHEMA]" >> "$export_file"
  for key in "${AVAILABLE_KEYS[@]}"; do
    value=$(gsettings get "$SCHEMA" "$key" 2>/dev/null)
    echo "$key = $value" >> "$export_file"
  done
  
  # Exporter les paramètres logind si le fichier existe
  if [ -f "$LOGIND_CONF" ]; then
    echo "" >> "$export_file"
    echo "[logind.conf]" >> "$export_file"
    for key in "${AVAILABLE_LOGIND_KEYS[@]}"; do
      value=$(get_logind_value "$key")
      echo "$key = $value" >> "$export_file"
    done
  fi
  
  echo -e "${GREEN}✔ Configuration exportée avec succès vers: ${export_file}${NC}"
  read -p "$(echo -e "${DIM}Appuyer sur Entrée pour continuer...${NC}")"
}

# Affiche les conseils de configuration
show_tips() {
  show_header "Conseils de Configuration"
  
  echo -e "${BOLD}${UNDERLINE}Conseils généraux:${NC}"
  echo -e "• ${YELLOW}Pour économiser la batterie:${NC}"
  echo -e "  - Définissez un délai de mise en veille plus court sur batterie (ex: 600s = 10min)"
  echo -e "  - Utilisez 'suspend' plutôt que 'nothing' pour l'action sur batterie"
  echo -e "  - Activez 'power-saver-profile-on-low-battery'"
  echo
  
  echo -e "• ${YELLOW}Pour la sécurité:${NC}"
  echo -e "  - Configurez le comportement à la fermeture du capot ('suspend' recommandé)"
  echo -e "  - Assurez-vous que le système se verrouille après inactivité"
  echo
  
  echo -e "• ${YELLOW}Pour un portable:${NC}"
  echo -e "  - Différenciez les comportements secteur/batterie"
  echo -e "  - Sur batterie: timeouts plus courts et suspend agressif"
  echo -e "  - Sur secteur: timeouts plus longs ou 'nothing'"
  echo
  
  echo -e "${BOLD}${UNDERLINE}Configuration recommandée pour un portable:${NC}"
  echo -e "${CYAN}sleep-inactive-battery-timeout = 600${NC} (10 minutes)"
  echo -e "${CYAN}sleep-inactive-battery-type = suspend${NC}"
  echo -e "${CYAN}sleep-inactive-ac-timeout = 1800${NC} (30 minutes)"
  echo -e "${CYAN}sleep-inactive-ac-type = suspend${NC}"
  echo -e "${CYAN}lid-close-battery-action = suspend${NC}"
  echo -e "${CYAN}lid-close-ac-action = suspend${NC}"
  echo
  
  echo -e "${BOLD}${UNDERLINE}Configuration recommandée pour un PC fixe:${NC}"
  echo -e "${CYAN}sleep-inactive-ac-timeout = 3600${NC} (1 heure)"
  echo -e "${CYAN}sleep-inactive-ac-type = suspend${NC}"
  echo -e "${CYAN}power-button-action = interactive${NC}"
  echo
  
  read -p "$(echo -e "${DIM}Appuyer sur Entrée pour revenir au menu principal...${NC}")"
}

# Menu de configuration rapide pour portables
quick_laptop_config() {
  show_header "Configuration Rapide pour Portable"
  
  echo -e "${YELLOW}Cette option va configurer automatiquement les paramètres recommandés pour un portable:${NC}"
  echo -e "• Mise en veille après 10 minutes sur batterie"
  echo -e "• Mise en veille après 30 minutes sur secteur" 
  echo -e "• Mise en veille à la fermeture du capot (batterie et secteur)"
  echo -e "• Atténuation de l'écran en cas d'inactivité"
  echo -e "• Profil d'économie d'énergie sur batterie faible"
  echo
  
  read -p "$(echo -e "${BLUE}Appliquer cette configuration ? [o/N] : ${NC}")" confirm
  
  if [[ "$confirm" =~ ^[Oo]$ ]]; then
    echo -e "${YELLOW}► Application de la configuration pour portable...${NC}"
    
    # Configurer les paramètres GSettings
    if key_exists "sleep-inactive-battery-timeout"; then
      gsettings set "$SCHEMA" "sleep-inactive-battery-timeout" 600
      echo -e "${GREEN}✔ Délai de mise en veille sur batterie: 10 minutes${NC}"
    fi
    
    if key_exists "sleep-inactive-battery-type"; then
      gsettings set "$SCHEMA" "sleep-inactive-battery-type" 'suspend'
      echo -e "${GREEN}✔ Action sur batterie: mise en veille${NC}"
    fi
    
    if key_exists "sleep-inactive-ac-timeout"; then
      gsettings set "$SCHEMA" "sleep-inactive-ac-timeout" 1800
      echo -e "${GREEN}✔ Délai de mise en veille sur secteur: 30 minutes${NC}"
    fi
    
    if key_exists "sleep-inactive-ac-type"; then
      gsettings set "$SCHEMA" "sleep-inactive-ac-type" 'suspend'
      echo -e "${GREEN}✔ Action sur secteur: mise en veille${NC}"
    fi
    
    if key_exists "lid-close-battery-action"; then
      gsettings set "$SCHEMA" "lid-close-battery-action" 'suspend'
      echo -e "${GREEN}✔ Action à la fermeture du capot (batterie): mise en veille${NC}"
    else
      edit_logind_action "HandleLidSwitch" "suspend"
    fi
    
    if key_exists "lid-close-ac-action"; then
      gsettings set "$SCHEMA" "lid-close-ac-action" 'suspend'
      echo -e "${GREEN}✔ Action à la fermeture du capot (secteur): mise en veille${NC}"
    else
      edit_logind_action "HandleLidSwitchExternalPower" "suspend"
    fi
    
    if key_exists "idle-dim"; then
      gsettings set "$SCHEMA" "idle-dim" 'true'
      echo -e "${GREEN}✔ Atténuation de l'écran en cas d'inactivité: activée${NC}"
    fi
    
    if key_exists "power-saver-profile-on-low-battery"; then
      gsettings set "$SCHEMA" "power-saver-profile-on-low-battery" 'true'
      echo -e "${GREEN}✔ Profil d'économie d'énergie sur batterie faible: activé${NC}"
    fi
    
    echo -e "${GREEN}✅ Configuration pour portable appliquée avec succès!${NC}"
  else
    echo -e "${RED}✘ Configuration annulée${NC}"
  fi
  
  read -p "$(echo -e "${DIM}Appuyer sur Entrée pour revenir au menu principal...${NC}")"
}

# Menu de configuration rapide pour PC fixe
quick_desktop_config() {
  show_header "Configuration Rapide pour PC Fixe"
  
  echo -e "${YELLOW}Cette option va configurer automatiquement les paramètres recommandés pour un PC fixe:${NC}"
  echo -e "• Mise en veille après 1 heure d'inactivité"
  echo -e "• Bouton d'alimentation: menu interactif"
  echo
  
  read -p "$(echo -e "${BLUE}Appliquer cette configuration ? [o/N] : ${NC}")" confirm
  
  if [[ "$confirm" =~ ^[Oo]$ ]]; then
    echo -e "${YELLOW}► Application de la configuration pour PC fixe...${NC}"
    
    # Configurer les paramètres GSettings
    if key_exists "sleep-inactive-ac-timeout"; then
      gsettings set "$SCHEMA" "sleep-inactive-ac-timeout" 3600
      echo -e "${GREEN}✔ Délai de mise en veille: 1 heure${NC}"
    fi
    
    if key_exists "sleep-inactive-ac-type"; then
      gsettings set "$SCHEMA" "sleep-inactive-ac-type" 'suspend'
      echo -e "${GREEN}✔ Action après inactivité: mise en veille${NC}"
    fi
    
    if key_exists "power-button-action"; then
      gsettings set "$SCHEMA" "power-button-action" 'interactive'
      echo -e "${GREEN}✔ Action bouton d'alimentation: menu interactif${NC}"
    else
      edit_logind_action "HandlePowerKey" "ignore"
      echo -e "${GREEN}✔ Action bouton d'alimentation: ignoré (configurer dans l'interface)${NC}"
    fi
    
    if key_exists "idle-dim"; then
      gsettings set "$SCHEMA" "idle-dim" 'true'
      echo -e "${GREEN}✔ Atténuation de l'écran en cas d'inactivité: activée${NC}"
    fi
    
    echo -e "${GREEN}✅ Configuration pour PC fixe appliquée avec succès!${NC}"
  else
    echo -e "${RED}✘ Configuration annulée${NC}"
  fi
  
  read -p "$(echo -e "${DIM}Appuyer sur Entrée pour revenir au menu principal...${NC}")"
}

# === MENU PRINCIPAL ===
main_menu() {
  while true; do
    load_keys
    load_logind_keys
    collect_system_info

    clear
    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                GESTIONNAIRE DE POLITIQUES D'INACTIVITÉ                 ║"
    echo -e "╠══════════════════════════════════════════════════════════════════════════╣"
    echo -e "║ ${GREEN}v${VERSION}${BLUE}                                                               ║"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}$SYSTEM_INFO${NC}\n"

    echo -e "${BOLD}${UNDERLINE}Paramètres GNOME disponibles:${NC}"
    echo -e "${CYAN}───────────────────────────────────────────────────────────────────────────${NC}"
    printf "${BOLD}%-3s %-42s %-35s${NC}\n" "ID" "Paramètre" "Valeur actuelle"
    echo -e "${DIM}───────────────────────────────────────────────────────────────────────────${NC}"
    
    i=1
    declare -A MENU
    for key in "${AVAILABLE_KEYS[@]}"; do
      MENU[$i]="$key"
      printf "%-3s ${YELLOW}%-42s${NC} ${GREEN}%-35s${NC}\n" "$i)" "$key" "${CURRENT_VALUES[$key]}"
      ((i++))
    done

    echo -e "\n${BOLD}${UNDERLINE}Options:${NC}"
    echo -e "${CYAN}───────────────────────────────────────────────────────────────────────────${NC}"
    
    MENU[$i]="show_missing"
    echo -e "$i) ${BLUE}Afficher les paramètres GNOME manquants${NC}"
    ((i++))

    MENU[$i]="logind"
    echo -e "$i) ${BLUE}Configurer systemd-logind${NC}"
    ((i++))

    MENU[$i]="laptop_config"
    echo -e "$i) ${PURPLE}Configuration rapide pour portable${NC}"
    ((i++))

    MENU[$i]="desktop_config"
    echo -e "$i) ${PURPLE}Configuration rapide pour PC fixe${NC}"
    ((i++))

    MENU[$i]="export"
    echo -e "$i) ${GREEN}Exporter la configuration actuelle${NC}"
    ((i++))

    MENU[$i]="help"
    echo -e "$i) ${CYAN}Aide et conseils${NC}"
    ((i++))

    MENU[$i]="quit"
    echo -e "$i) ${RED}Quitter${NC}"

    echo
    read -p "$(echo -e "${BOLD}Choix (1-$i) : ${NC}")" opt

    case "${MENU[$opt]}" in
      "quit")
        echo -e "${GREEN}Au revoir.${NC}"
        exit 0
        ;;
      "show_missing")
        show_header "Paramètres GNOME manquants"
        
        if [ ${#MISSING_KEYS[@]} -eq 0 ]; then
          echo -e "${GREEN}✔ Toutes les clés GNOME sont disponibles sur votre système.${NC}"
        else
          echo -e "${YELLOW}Clés GNOME absentes sur votre système :${NC}"
          for key in "${MISSING_KEYS[@]}"; do
            if [[ -n "${GNOME_TO_LOGIND[$key]}" ]]; then
              echo -e " ${YELLOW}•${NC} ${key} ${GREEN}→ alternative logind:${NC} ${GNOME_TO_LOGIND[$key]}"
            else
              echo -e " ${RED}•${NC} ${key} ${DIM}(aucune alternative connue)${NC}"
            fi
          done
        fi
        
        read -p "$(echo -e "${DIM}Appuyer sur Entrée pour continuer...${NC}")"
        ;;
      "logind")
        show_header "Configuration systemd-logind"
        
        if [ ! -f "$LOGIND_CONF" ]; then
          echo -e "${YELLOW}⚠ Le fichier $LOGIND_CONF n'existe pas encore.${NC}"
          echo -e "${DIM}Il sera créé lors de la première modification.${NC}"
          echo
        fi
        
        echo -e "${BOLD}${UNDERLINE}Clés logind.conf disponibles:${NC}"
        for key in "${ALL_LOGIND_KEYS[@]}"; do
          local current_val=$(get_logind_value "$key")
          local desc="${LOGIND_DESCRIPTIONS[$key]}"
          
          if logind_key_exists "$key"; then
            printf " ${GREEN}•${NC} %-30s : %s ${DIM}[%s]${NC}\n" "$key" "$current_val" "${desc:-Aucune description}"
          else
            printf " ${DIM}◦ %-30s : %s${NC}\n" "$key" "${desc:-Aucune description}"
          fi
        done
        
        echo
        read -p "$(echo -e "${BLUE}Clé à modifier (ou Entrée pour revenir): ${NC}")" log_key
        
        if [[ -n "$log_key" ]]; then
          # Vérifier si la clé existe dans notre liste
          if [[ " ${ALL_LOGIND_KEYS[*]} " =~ " ${log_key} " ]]; then
            # Affiche les valeurs possibles si on en a listé
            opts="${LOGIND_OPTIONS[$log_key]}"
            if [[ -n "$opts" ]]; then
              echo -e "${YELLOW}Valeurs possibles pour ${log_key} :${NC} $opts"
            else
              echo -e "${YELLOW}Cette clé attend une valeur numérique (secondes) ou libre${NC}"
            fi
            
            read -p "$(echo -e "${BLUE}Nouvelle valeur : ${NC}")" log_val
            if [[ -n "$log_val" ]]; then
              edit_logind_action "$log_key" "$log_val"
            else
              echo -e "${RED}✘ Opération annulée - valeur vide${NC}"
              read -p "$(echo -e "${DIM}Appuyer sur Entrée pour continuer...${NC}")"
            fi
          else
            echo -e "${RED}✘ Clé '$log_key' inconnue ou non prise en charge${NC}"
            read -p "$(echo -e "${DIM}Appuyer sur Entrée pour continuer...${NC}")"
          fi
        fi
        ;;
      "laptop_config")
        quick_laptop_config
        ;;
      "desktop_config")
        quick_desktop_config
        ;;
      "export")
        export_config
        ;;
      "help")
        show_tips
        ;;
      *)
        if [[ -n "${MENU[$opt]}" ]]; then
          set_parameter "${MENU[$opt]}"
        else
          echo -e "${RED}✘ Choix invalide.${NC}"
          sleep 1
        fi
        ;;
    esac
  done
}

# === VÉRIFICATIONS INITIALES ===
check_requirements() {
  local missing_deps=()
  
  # Vérifier que gsettings est installé
  if ! command -v gsettings &> /dev/null; then
    missing_deps+=("gsettings (paquet 'gsettings-desktop-schemas' ou 'gnome-settings-daemon')")
  fi
  
  # Vérifier sudo
  if ! command -v sudo &> /dev/null; then
    missing_deps+=("sudo")
  fi
  
  # Si des dépendances sont manquantes
  if [ ${#missing_deps[@]} -gt 0 ]; then
    echo -e "${RED}✘ Dépendances manquantes :${NC}"
    for dep in "${missing_deps[@]}"; do
      echo -e " - $dep"
    done
    echo -e "${YELLOW}Veuillez installer les dépendances manquantes et relancer le script.${NC}"
    exit 1
  fi
  
  # Vérifier les permissions sudo sans demander de mot de passe
  if ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}⚠ Ce script nécessite des privilèges administrateur pour modifier logind.conf${NC}"
    echo -e "${YELLOW}⚠ Vous pourrez être invité à saisir votre mot de passe pendant l'exécution${NC}"
    sudo true || { echo -e "${RED}✘ Échec d'authentification sudo, certaines fonctionnalités seront limitées.${NC}"; }
  fi
}

# === EXÉCUTION PRINCIPALE ===
show_banner() {
  clear
  echo -e "${BLUE}"
  echo -e "┌────────────────────┐\n│Don't buy me coffee.│\n└────────────────────┘"
  echo -e "${NC}"
  echo -e "${BOLD}Gestionnaire de politiques d'inactivité pour Linux v${VERSION}${NC}"
  echo -e "${DIM}Configurez facilement vos paramètres d'économie d'énergie${NC}"
  echo
  echo -e "${YELLOW}► Initialisation...${NC}"
  sleep 1
}

# Fonction principale
main() {
  # Afficher la bannière
  show_banner
  
  # Vérifier les prérequis
  check_requirements
  
  # Lancer le menu principal
  main_menu
}

# Démarrer le script
main


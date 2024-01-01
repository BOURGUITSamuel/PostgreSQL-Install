#!/bin/bash

# Chemin du fichier journal (log)
LOG_FILE="/var/log/postgresql_install.log"

# Horodatage
current_date_time=$(date +"%Y-%m-%d")

# Fonction pour enregistrer les erreurs dans le fichier journal avec horodatage 
function gestion_erreur {
    local MESSAGE="$1"
    local TIMESTAMP=$(date +'%Y-%m-%d %H:%M:%S')
    echo "ERREUR [$TIMESTAMP]: $MESSAGE" >&2
    echo "ERREUR [$TIMESTAMP]: $MESSAGE" >> "$LOG_FILE"
    exit 1  
}

# Vérification des privilèges de l'utilisateur
if [[ $EUID -ne 0 ]]; then
  gestion_erreur "Ce script doit être exécuté en tant que root."
else 
  echo "L'utilisateur connecté est bien root." | tee -a "$LOG_FILE"
fi

echo "1.Initialistion du repository de PostgreSQL." | tee -a "$LOG_FILE"

# Installation du package gnupg (permet l'encryption et la signature des communications) et de l'outil wget
apt-get -y install gnupg > /dev/null && apt-get -y install wget > /dev/null
if [[ $? -ne 0 ]]; then
  gestion_erreur "Une erreur s'est produite lors de l'installation des packages gnupg et wget."
else 
  echo "l'installation des packages gnupg et wget s'est déroulée avec succès." | tee -a "$LOG_FILE"
fi

# Vérification de la disponibilité du paquet d'installation de PostgreSQL 15
if apt-cache policy postgres-sql-15 > /dev/null; then
  echo "Le paquet postgresql-15 est disponible." | tee -a "$LOG_FILE"
else 
  gestion_erreur "Le paquet postgresql-15 est introuvable."
fi

echo "2.Installation des utilitaires de PostgreSQL." | tee -a "$LOG_FILE"

# Installation des utilitaires de PotsgreSQL
apt-get -y update > /dev/null && apt-get -y install postgresql-contrib-15 postgresql-common postgresql-15-orafce > /dev/null
if [[ $? -ne 0 ]]; then
  gestion_erreur "Une erreur s'est produite lors de l'installation des utilitaires de PostgreSQL."
else 
  echo "l'installation des utilitaires de PostgreSQL s'est déroulée avec succès." | tee -a "$LOG_FILE"
fi

echo "3.Installation de PostgreSQL." | tee -a "$LOG_FILE"

# Installation de PostgreSQL 15
apt-get -y update > /dev/null && apt-get -y install postgresql-15 > /dev/null
if [[ $? -ne 0 ]]; then
  gestion_erreur "Une erreur s'est produite lors de l'installation de PostgreSQL 15."
else 
  echo "L'Installation de PostgreSQL s'est déroulée avec succès." | tee -a "$LOG_FILE"
fi

# Vérification de la version installée
pg_version=$(psql --version | awk '{print $3}' | awk -F "." '{print $1}')
if [[ $pg_version -ne 15 ]]; then
  gestion_erreur "La version installée de PostgreSQL n'est pas la version 15 !"
else
  echo "La version 15 de PostGreSQL est bien installée sur le système." | tee -a "$LOG_FILE"
fi

echo "4.Gestion du service PostgreSQL." | tee -a "$LOG_FILE"

# Activation du service postgresql au démarrage 
systemctl enable --quiet postgresql
service_enabled=$(systemctl is-enabled --quiet postgresql)
if [[ $service_enabled -ne "enabled" ]]; then
  gestion_erreur "Le service PostgreSQL n'est pas activé au démarrage du système."
else 
  echo "Le service PostgreSQL a bien été activé au démarrage du système." | tee -a "$LOG_FILE"
fi

# Démarrage du service PostgreSQL
systemctl start postgresql
if [[ $? -ne 0 ]]; then
  gestion_erreur "Une erreur s'est produite lors du démarrage du service PostgreSQL."
else
  echo "Le démarrage du service PostgreSQL a bien été effectué." | tee -a "$LOG_FILE"
fi

# Vérification de l'état du service postgresql
service_status=$(systemctl is-active --quiet postgresql)
if [[ $service_status -ne "active" ]]; then
  gestion_erreur "Le service PostgreSQL n'est pas en cours d'exécution."
else : 
  echo "Le service PostgreSQL est bien en cours d'exécution." | tee -a "$LOG_FILE"
fi

echo "5.Sauvegarde des fichiers de configuration de PostgreSQL." | tee -a "$LOG_FILE"

# Sauvegarde des fichiers de configuration de PostgreSQL
if [[ -f /etc/postgresql/15/main/postgresql.conf.bak ]]; then
    echo "le fichier postgresql.conf.bak existe déjà , ajout d'un nouveau fichier main.cf.bak avec horodatage." | tee -a "$LOG_FILE"
    cp /etc/postgresql/15/main/postgresql.conf /etc/postgresql/15/main/postgresql.conf_${current_date_time}.bak
else
    echo "Sauvegarde du fichier postgresql.conf." | tee -a "$LOG_FILE"
    cp /etc/postgresql/15/main/postgresql.conf /etc/postgresql/15/main/postgresql.conf_${current_date_time}.bak
fi

if [[ -f /etc/postgresql/15/main/pg_hba.conf.bak ]]; then
    echo "le fichier pg_hba.conf existe déjà , ajout d'un nouveau fichier main.cf.bak avec horodatage." | tee -a "$LOG_FILE"
    cp /etc/postgresql/15/main/pg_hba.conf /etc/postgresql/15/main/pg_hba.conf_${current_date_time}.bak
else
    echo "Sauvegarde du fichier pg_hba.conf." | tee -a "$LOG_FILE"
    cp /etc/postgresql/15/main/pg_hba.conf /etc/postgresql/15/main/pg_hba.conf_${current_date_time}.bak
fi

echo "6.Sauvegarde des fichiers de configuration de PostgreSQL." | tee -a "$LOG_FILE"

# Création d'un lien symbolique pour l'extension orafce
echo "Création d'un lien symbolique pour l'extension orafce." | tee -a "$LOG_FILE"
if ls /usr/lib/postgresql/15/lib/ | grep -i "orafunc.so"; then
  echo "Le lien symbolique orafce existe déjà." | tee -a "$LOG_FILE"
else
  echo "Le lien symbolique orafce n'existe pas,ajout en cours..." | tee -a "$LOG_FILE"
  ln -s /usr/lib/postgresql/15/lib/orafce.so /usr/lib/postgresql/15/lib/orafunc.so
fi

echo "7.Test de connexion." | tee -a "$LOG_FILE"
       
# Test de connexion 
su - postgres -c 'psql -c "SELECT version();" postgres' > /dev/null 
if [[ $? -ne 0 ]]; then
  gestion_erreur "Le test de connexion a échoué."
else
  echo "Le test de connexion a réussi." | tee -a "$LOG_FILE"
fi

# Enregistrement d'un message de succès dans le fichier journal
echo "[Succès] $current_date_time - PostgreSQL 15 a été installé avec succès, les fichiers de configuration ont été sauvegardés et le service est en cours d'exécution." | tee -a "$LOG_FILE"

exit 0

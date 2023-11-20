#!/bin/bash

# Emplacement du fichier journal (log)
LOG_FILE="/var/log/postgresql_conf.log"

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
  gestion_erreur "Ce script doit être exécuté en tant qu'utilisateur root."
else
  echo "L'utilisateur root est bien connecté" | tee -a "$LOG_FILE"
fi

# Vérification de la présence du dossier postgresql_conf_files
postgresql_conf_folder="/tmp/postgresql_conf_files"
if [[ -d $postgresql_conf_folder ]]; then
  echo "le dossier $postgresql_conf_folder est bien présent."
else
  echo "Le dossier $postgresql_conf_folder est introuvanble!"
fi

# Changement du mot de passe de l'utilisateur "postgres"
pg_password="/tmp/postgresql_conf_files/pg_password.sql"
if [[ -f /tmp/postgresql_conf_files/pg_password.sql ]]; then
  echo "Le fichier pg_password.sql est bien présent." | tee -a "$LOG_FILE"
  su - postgres -c "psql -U postgres -d postgres -f $pg_password"
  if [[ $? -ne 0 ]]; then
    gestion_erreur "Une erreur s'est produite lors du changement du mot de passe de l'utilisateur postgres."
  else 
    echo "Le changement de mot de passe a été effectué avec succès." | tee -a "$LOG_FILE"
  fi
else
  gestion_erreur "Le fichier pg_password.sql est introuvable!"
fi

# Création des extensions
extensions="/tmp/postgresql_conf_files/create_extensions.sql"
if [[ -f /tmp/postgresql_conf_files/create_extensions.sql ]]; then
  echo "Le fichier create_extensions.sql est bien présent." | tee -a "$LOG_FILE"
  su - postgres -c "psql -U postgres -d postgres -f $extensions"
  if su - postgres -c "psql -c \"select * FROM pg_extension where extname in ('orafce', 'pgcrypto', 'uuid-ossp', 'unaccent');\"" > /dev/null; then
    echo "Les extensions ont étés crées avec succès" | tee -a "$LOG_FILE"
  else
    gestion_erreur "Une erreur s'est produite lors de la création des extensions."
  fi
else 
  gestion_erreur "Le fichier create_extensions.sql est introuvable!"
fi

# Fin de la journalisation et du script 
echo "[Succès] $current_date_time - La création des extensions s'est déroulée avec succcès." | tee -a "$LOG_FILE"

exit 0

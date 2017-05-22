#!/bin/bash

MONGODB_HOST=${MONGODB_PORT_27017_TCP_ADDR:-${MONGODB_HOST}}
MONGODB_HOST=${MONGODB_PORT_1_27017_TCP_ADDR:-${MONGODB_HOST}}
MONGODB_PORT=${MONGODB_PORT_27017_TCP_PORT:-${MONGODB_PORT}}
MONGODB_PORT=${MONGODB_PORT_1_27017_TCP_PORT:-${MONGODB_PORT}}
MONGODB_USER=${MONGODB_USER:-${MONGODB_ENV_MONGODB_USER}}
MONGODB_PASS=${MONGODB_PASS:-${MONGODB_ENV_MONGODB_PASS}}
MYSQL_HOST=${MYSQL_PORT_3306_TCP_ADDR:-${MYSQL_HOST}}
MYSQL_HOST=${MYSQL_PORT_1_3306_TCP_ADDR:-${MYSQL_HOST}}
MYSQL_PORT=${MYSQL_PORT_3306_TCP_PORT:-${MYSQL_PORT}}
MYSQL_PORT=${MYSQL_PORT_1_3306_TCP_PORT:-${MYSQL_PORT}}
MYSQL_USER=${MYSQL_USER:-${MYSQL_ENV_MYSQL_USER}}
MYSQL_PASS=${MYSQL_PASS:-${MYSQL_ENV_MYSQL_PASS}}

FTP_HOST=${FTP_HOST}
FTP_PORT=${FTP_PORT}
FTP_USER=${FTP_USER}
FTP_PASS=${FTP_PASS}
FTP_DIRECTORY=${FTP_DIRECTORY}

[[ ( -z "${MONGODB_USER}" ) && ( -n "${MONGODB_PASS}" ) ]] && MONGODB_USER='admin'

[[ ( -n "${MONGODB_USER}" ) ]] && USER_STR=" --username ${MONGODB_USER}"
[[ ( -n "${MONGODB_PASS}" ) ]] && PASS_STR=" --password ${MONGODB_PASS}"
[[ ( -n "${MONGODB_DB}" ) ]] && USER_STR=" --db ${MONGODB_DB}"

[ -z "${MYSQL_HOST}" ] && { echo "=> MYSQL_HOST cannot be empty" && exit 1; }
[ -z "${MYSQL_PORT}" ] && { echo "=> MYSQL_PORT cannot be empty" && exit 1; }
[ -z "${MYSQL_USER}" ] && { echo "=> MYSQL_USER cannot be empty" && exit 1; }
[ -z "${MYSQL_PASS}" ] && { echo "=> MYSQL_PASS cannot be empty" && exit 1; }

[ -z "${FTP_HOST}" ] && { echo "=> FTP_HOST cannot be empty" && exit 1; }
[ -z "${FTP_PORT}" ] && { echo "=> FTP_PORT cannot be empty" && exit 1; }
[ -z "${FTP_USER}" ] && { echo "=> FTP_USER cannot be empty" && exit 1; }
[ -z "${FTP_PASS}" ] && { echo "=> FTP_PASS cannot be empty" && exit 1; }
[ -z "${FTP_DIRECTORY}" ] && { echo "=> FTP_DIRECTORY cannot be empty" && exit 1; }

BACKUP_MONGO_CMD="mongodump --out /backup/"'${BACKUP_NAME}'"/MONGO --host ${MONGODB_HOST} --port ${MONGODB_PORT} ${USER_STR}${PASS_STR}${DB_STR} ${EXTRA_OPTS}"

BACKUP_MYSQL_CMD="echo 'show databases;' | mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASS} | grep -v 'Database\|information_schema\|mysql\|performance_schema'"
BACKUP_MYSQL_DUMP="mysqldump -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASS} ${EXTRA_OPTS} "'${i}'" > /backup/"'${BACKUP_NAME}'"/MYSQL/"'${i}'".sql"

BACKUP_FTP="curl -T /backup/"'${BACKUP_NAME}'".tar.gz ftp://${FTP_HOST}${FTP_DIRECTORY}/ --user ${FTP_USER}:${FTP_PASS}"
BACKUP_FTP_NB="curl -l -s ftp://${FTP_HOST}${FTP_DIRECTORY}/ --user ${FTP_USER}:${FTP_PASS} | grep backup | wc -l"
BACKUP_FTP_TOBED="curl -l -s ftp://${FTP_HOST}${FTP_DIRECTORY}/ --user ${FTP_USER}:${FTP_PASS} | grep backup | head -1"
BACKUP_FTP_DELETE=" curl ftp://${FTP_HOST} -X \"DELE ${FTP_DIRECTORY}/"'${BACKUP_TO_BE_DELETED}'"\" --user ${FTP_USER}:${FTP_PASS}"


echo "=> Creating backup script"
rm -f /backup.sh
cat <<EOF >> /backup.sh
#!/bin/bash
MAX_BACKUPS=${MAX_BACKUPS}

echo "=> Backup started"
BACKUP_NAME=backup_\$(date +\%Y.\%m.\%d.\%H)

mkdir -p /backup/\${BACKUP_NAME}/MONGO
mkdir -p /backup/\${BACKUP_NAME}/MYSQL
mkdir -p /backup/\${BACKUP_NAME}/FILES

if ${BACKUP_MONGO_CMD} ;then
    echo "   Dump Mongo succeeded"
else
    echo "   Dump Mongo failed"
fi

for i in BACKUP_MYSQL_CMD; do
  if ${BACKUP_MYSQL_DUMP} ;then
    echo "Dump Mysql succeeded"
  else
    echo "Dump Mysql failed"
done

cp -R /exports /backup/\${BACKUP_NAME}/FILES/

tar czvf /backup/\${BACKUP_NAME}.tar.gz /backup/\${BACKUP_NAME}

echo "   Compression du dossier \${BACKUP_NAME} > \${BACKUP_NAME}.tar.gz"
sleep 30

${BACKUP_FTP}
echo "   FTP upload succeeded"

echo "   Verification et nettoyage des backups"
sleep 5

if [ -n "\${MAX_BACKUPS}" ]; then
    BACKUP_TOTAL_DIR=\${BACKUP_FTP_NB}
    echo "  Total Backup : \${BACKUP_TOTAL_DIR}"

    if [ \${BACKUP_TOTAL_DIR} -gt \${MAX_BACKUPS} ];then
        BACKUP_TO_BE_DELETED=\$BACKUP_FTP_TOBED
        if [ -n "\${BACKUP_TO_BE_DELETED}" ] ;then
          echo "   Deleting backup \${BACKUP_TO_BE_DELETED}"
          $BACKUP_FTP_DELETE
        else
          echo "    No backup to delete..."
        fi
    else
      echo "    No backup to delete..."
    fi
fi

echo "=> Remove Backup Directory"
rm -rf /backup/\${BACKUP_NAME}
rm -rf /backup/\${BACKUP_NAME}.tar.gz

echo "=> Backup done"
EOF
chmod +x /backup.sh

echo "=> Creating restore script"
rm -f /restore.sh
cat <<EOF >> /restore.sh
#!/bin/bash
echo "=> Restore database from \$1"
if mongorestore --host ${MONGODB_HOST} --port ${MONGODB_PORT} ${USER_STR}${PASS_STR} \$1; then
    echo "   Restore succeeded"
else
    echo "   Restore failed"
fi
echo "=> Done"
EOF
chmod +x /restore.sh

touch /backup.log
tail -F /backup.log &

# if [ -n "${INIT_BACKUP}" ]; then
#    echo "=> Create a backup on the startup"
#    /backup.sh
# fi

echo "${CRON_TIME} /backup.sh >> /backup.log 2>&1" > /crontab.conf
crontab  /crontab.conf
echo "=> Running cron job"
exec cron -f


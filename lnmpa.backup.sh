#!/bin/bash

#Funciont: Backup website and mysql database
#Author: Ray.
#Website: http://love4026.org

#IMPORTANT!!!Please Setting the following Values!
# crontab -e
# 0 3 */3 * * /root/backup.sh

# Configure
DB_DIR='/usr/local/mysql/var'
NGINX_CONF_DIR='/usr/local/nginx/conf'
APACHE_CONF_DIR='/usr/local/apache/conf'
FILE_DIR='/home/wwwroot'

######~Set FTP Information~######
FTP_HostName='your_ftp_hostname'
FTP_UserName='your_ftp_username'
FTP_PassWord='your_ftp_password'
FTP_BackupDir='backupdir/targetdir'

#Values Setting END!

TodayBackup=*-$(date +"%Y%m%d").tar.gz
OldBackup=*-$(date -d -3day +"%Y%m%d").tar.gz

tar zcf /home/backup/wwwroot-$(date +"%Y%m%d").tar.gz $FILE_DIR --exclude=phpmyadmin
tar zcf /home/backup/database-$(date +"%Y%m%d").tar.gz $DB_DIR
tar zcf /home/backup/nginx-conf-$(date +"%Y%m%d").tar.gz $NGINX_CONF_DIR
tar zcf /home/backup/apache-conf-$(date +"%Y%m%d").tar.gz $APACHE_CONF_DIR

rm -f /home/backup/$OldBackup

cd /home/backup/

lftp $FTP_HostName -u $FTP_UserName,$FTP_PassWord << EOF
cd $FTP_BackupDir
mrm $OldBackup
mput $TodayBackup
bye
EOF
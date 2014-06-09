#!/bin/bash

################################################################################
# Auto add ftp and mysql account to domain
# Author: Ray Chang <http://www.love4026.org>
# 
# Version: 2.0.2
#
# License: ;)
#
# This Script is used for LNMP(http://www.lnmp.org/), FTP Service must be pureftpd.
# Latest version can be found at http://soft.shibangsoft.com
#
# Usage:
#  ./path/to/addftpmysql.sh [domain-name] [root-password]
#
# For more information please visit http://www.love4026.org/
#
################################################################################

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, use sudo sh $0"
    exit 1
fi

clear

if [ "$1" != "--help" ]; then
	get_char()
	{
	SAVEDSTTY=`stty -g`
	stty -echo
	stty cbreak
	dd if=/dev/tty bs=1 count=1 2> /dev/null
	stty -raw
	stty echo
	stty $SAVEDSTTY
	}
	if [ $# == 2 ]; then
		domain=$1
		mysqlrootpwd=$2
		echo "==========================="
		echo "Domain name:$domain"
		echo "MySQL root password:$mysqlrootpwd"
		echo "==========================="
		echo ""
		echo "Press any key to continue..."
		char=`get_char`
	else
		#set domain name
		
		domain=""
		read -p "Please input your domain:" domain
		if [ "$domain" = "" ]; then
			echo "Error: Domain Name Can't be empty!!"
			exit 1
		fi

		#set mysql root password

		mysqlrootpwd=""
		read -p "Please input the root password of mysql:" mysqlrootpwd
		if [ "$mysqlrootpwd" = "" ]; then
			echo "MySQL root password can't be NULL!"
			exit 1
		fi
	fi	

	vhostdir="/home/wwwroot/$domain"
	MYSQL=`which mysql`

	if [ ! -f "/usr/local/nginx/conf/vhost/$domain.conf" ]; then
		echo "==========================="
		echo "Domain:$domain is not exist, please add domain first!"
		echo "==========================="	
		exit 1
	fi
	# is it necessary to do ?
	if [ ! -d $vhostdir ]; then
		echo "==========================="
		echo "Directory:$vhostdir not found, please check your domain!"
		echo "==========================="	
		exit 1
	fi
	
	#add FTP account
	
	echo "Do you want to add ftp account? (y/n)"
	read allow_ftp

	if [ "$allow_ftp" == 'n' ]; then
		echo "You will NOT add ftp account!"
	else
		echo "You will add ftp account"

		#set ftp username
	
		ftpusername=""
		echo "Please input your username of FTP(max length 16,default is domain name):"
		read ftpusername
		if [ "$ftpusername" = "" ]; then
			echo "==========================="
			echo "FTP username can't be NULL!"
			echo "script will auto generated a ftp username!"
			#ftpusername="${domain:0:16}"
			#ftpusername=$(echo ${domain:0:16} | tr -d '.')
			ftpusername=`expr substr $(echo $domain | tr -d '.') 1 16`
			echo "Your username of ftp user was:$ftpusername"
			echo "==========================="
		fi

		#set ftp password

		ftppwd=""
		read -p "Please input password of ftp user:" ftppwd
		if [ "$ftppwd" = "" ]; then
			echo "==========================="
			echo "FTP password can't be NULL!"
			echo "script will randomly generated a password!"
			#ftppwd=`cat /dev/urandom | head -1 | md5sum | head -c 8`
			ftppwd=`head -c 500 /dev/urandom | tr -dc a-z0-9A-Z | head -c 12`
			echo "Your password of ftp user was:$ftppwd"
			echo "==========================="
		fi
	fi
	
	echo ""

	#add MYSQL database name
	
	echo "Do you want to add mysql database? (n/y)"
	read allow_mysql

	if [ "$allow_mysql" == 'y' ]; then
		echo "You will add MYSQL database"

		#set database name
		read -p "Type database name(Default name:$domain):" db_name
		if [ "$db_name" = "" ]; then
			db_name="$domain"
		fi
		echo "==========================="
		echo "Database name can't be NULL!"
		echo "script will auto generated a database name!"
		echo Your database name="$db_name"
		echo "==========================="
		#set database username
		db_username=""
		read -p "Please input your username of database(max length 16):" db_username
		if [ "$db_username" = "" ]; then
			echo "==========================="
			echo "Database username can't be NULL!"
			echo "script will auto generated a database username!"
			#db_username="${domain:0-1:16}"
			db_username=$(echo ${domain%.*} | cut -b 1-10)$(date +"%y%m%d")
			echo "Your username of database was:$db_username"
			echo "==========================="
		fi
		#set database user password
		db_password=""
		read -p "Please input password of database user:" db_password
		if [ "$db_password" = "" ]; then
			echo "==========================="
			echo "Database password can't be NULL!"
			echo "script will randomly generated a password!"
			#db_password=`cat /dev/urandom | head -1 | md5sum | head -c 8`
			db_password=`head -c 500 /dev/urandom | tr -dc a-z0-9A-Z | head -c 16`
			echo "Your password of database user was:$db_password"
			echo "==========================="
		fi
	fi

	echo ""
	echo "Press any key to start add account..."
	char=`get_char`

	ftp_status=0
	db_status=0

	#start add ftp user
	if [ "$allow_ftp" != 'n' ]; then
		echo ""
		echo "Start add a FTP user..."
		$MYSQL -u root -p$mysqlrootpwd<<EOF
		INSERT INTO ftpusers.users VALUES ('$ftpusername',MD5('$ftppwd'),501, 501, '$vhostdir', 100, 50, 1000, 1000, '*', 'by shell script added, $(date +"%Y-%m-%d")', '1', 0, 0);
EOF
		if [ $? -ne 0 ]; then
			echo -e "\e[1;31mAdd ftp user failure! \e[0m"
		else
			ftp_status=1
		fi
	fi

	#start add mysql database
	if [ "$allow_mysql" == 'y' ]; then
		echo "Start add a mysql database..."
		$MYSQL -u root -p$mysqlrootpwd<<EOF
		CREATE DATABASE \`$db_name\` CHARACTER SET utf8 COLLATE utf8_general_ci;
		GRANT ALL ON \`$db_name\`.* TO \`$db_username\`@localhost IDENTIFIED BY '$db_password';
		FLUSH PRIVILEGES;
EOF
		if [ $? -ne 0 ]; then
			echo -e "\e[1;31mAdd mysql database failure! \e[0m"
		else
			db_status=1
		fi
	fi

	function PrintFtpResult()
	{
		echo "Your domain was:$domain"
		echo "Your domain ip was:$hostip"
		echo "------------------FTP------------------"
		echo "Your hostname of FTP was:$hostip"
		echo "Your username of FTP was:$ftpusername"
		echo "Your password of FTP was:$ftppwd"
		echo "Directory of FTP user:$vhostdir"
	}
	function PrintMysqlResult()
	{
		echo "-----------------MYSQL-----------------"
		echo "Your host of Database was:localhost($hostip)"
		echo "Your name of Database was:$db_name"
		echo "Your username of Database was:$db_username"
		echo "Your password of Database was:$db_password"
	}

	hostip="$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
	account_file=$vhostdir"/.ftp-mysql-account.txt"

	if [ $ftp_status -eq 0 -a $db_status -eq 0 ]; then
		echo "======================================================================="
		echo "Add account failure, Please check your server status!"
		echo "Script Written by Ray, used for lnmp/lnmpa with Pureftpd! "
		echo "For more information please visit http://www.love4026.org/"
		echo ""
		# below can be delete
		service pureftpd
		cat /etc/issue
		uname -a
		MemTotal=`free -m | grep Mem | awk '{print  $2}'`  
		echo -e "\nMemory is: ${MemTotal} MB "
		echo "======================================================================="
		exit 1
	else
		echo "======================================================================="
		echo "Add account completed!  ,  Script Written by Ray "
		printf "Account information was saved in:\n $account_file"
		echo "======================================================================="
		echo -e "\e[1;31mPlease copy and save the following content! \e[0m"
		echo ""
		if [ "$allow_ftp" != 'n' -a $ftp_status -eq 1 ]; then
			PrintFtpResult 2>&1 | tee $account_file
		fi

		if [ "$allow_mysql" == 'y' -a $db_status -eq 1 ]; then
			PrintMysqlResult 2>&1 | tee -a $account_file
		fi

		# save log
		echo "########################################" >> /root/ftp_mysql_add.log
		cat $account_file >> /root/ftp_mysql_add.log

		echo "Created by script in $(date +"%Y-%m-%d %T %:z")" | tee -a $account_file
		echo "======================================================================="
		#chmod 755 $account_file
		#chown www:www $account_file
	fi

	#start web app install
	if [ "$allow_mysql" == 'y' -a $db_status -eq 1 ]; then
		#read allow_webapp
		echo "Would you like to install web application(wordpress etc.) to this domain? (n/y)"
		read allow_webapp
		#read -p "Would you like to install web application(wordpress etc.) to this domain? (n/y)" allow_webapp

		if [ "$allow_webapp" == 'y' ]; then
			#set directory
			cd $vhostdir
			echo "Your current directory was:${PWD}"
			echo ""
			echo "Press any key to start install web app to ${PWD}..."
			char=`get_char`

			echo "Please select the web application you want to install:"
			echo "wordpress,empirecms."
			read -p "(Default web app: wordpress):" webapp			

			if [ "$webapp" = "wordpress" -o "$webapp" = "" ]; then
				#install wordpress app
				echo "Installing wordpress..."
				if [ -f "wp-config.php" ]; then
					echo "Find a wp-config.php, wordpress may have been installed!"
					exit 1
				fi
				# Download latest WordPress and uncompress
				wget -c http://wordpress.org/latest.tar.gz
				tar zxf latest.tar.gz
				mv wordpress/* ./
				# Grab our Salt Keys
				wget -O /tmp/wp.keys https://api.wordpress.org/secret-key/1.1/salt/
				# Butcher our wp-config.php file
				sed -e "s/database_name_here/"$db_name"/" -e "s/username_here/"$db_username"/" -e "s/password_here/"$db_password"/" wp-config-sample.php > wp-config.php
				sed -i '/#@-/r /tmp/wp.keys' wp-config.php
				sed -i "/#@+/,/#@-/d" wp-config.php
				# Tidy up
				rmdir wordpress
				rm latest.tar.gz
				rm /tmp/wp.keys
				# Install wordpress plugins
				cd wp-content/plugins
				rm -rf akismet
				rm hello.php
				plugins=(fv-all-in-one-seo-pack yet-another-related-posts-plugin.4.1.2 disabler.3.0.0 google-sitemap-plugin.2.8.7)
				for plugin in plugins; do
					echo "Installing plugin: $plugin..."
					#mkdir $plugin; cd $plugin
					curl -H "Accept-Encoding: gzip,deflate" http://downloads.wordpress.org/plugin/$plugin.zip > $plugin.zip
					unzip $plugin.zip
					rm $plugin.zip
				done
				#set permission
				cd $vhostdir
				chmod -R 755 ./
				chmod 770 wp-config.php
				chown -R www:www ./
				echo "======================================================================="
				echo "Wordpress install completed!"
				echo "Note: wordpress user and password was not set."
				echo "Please visit http://$domain/wp-admin/install.php, follow installation prompts continually."
				echo "======================================================================="
			elif [ "$webapp" = "empirecms" ]; then
				echo "Installing EmpireCMS..."
				wget "http://www.phome.net/ecms7/download/EmpireCMS_7.0_SC_UTF8.zip"
				unzip -q EmpireCMS_7.0_SC_UTF8.zip
				mv upload/* ./
				rmdir upload
				chmod -R 777 ./
				chown -R www:www ./
				echo "======================================================================="
				echo "EmpireCMS install completed!"
				echo "Please visit http://$domain/e/install/index.php, follow installation prompts continually."
				echo "======================================================================="
			fi
		fi

	fi
	#end web app install
else
	echo "Usage: $0 [argument1] [argument2]"
	echo "  1: domain name to add account to. (e.g. example.com)"
	echo "  2: MySQL root password (to create account)"
	echo ""
	echo "Domain directory must created in /home/wwwroot/, root password must correct. "
	echo "FTP service must be pureftpd."
	echo "This script is used for LNMPA V1.0  ,  Written by Ray"
fi
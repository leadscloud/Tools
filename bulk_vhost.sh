#!/bin/bash
#
################################################################################
# Bulk add vhost, FTP, MYSQL and Web Application for LNMP/LNMPA by licess
# LNMP is a tool to auto-compile & install Nginx+MySQL+PHP+Apache on Linux
# For more information please visit http://www.lnmp.org/
# 
# Author: Ray Chang <http://www.love4026.org>
# 
# Version: 1.0.1
#
# FTP Service must be pureftpd.
#
# Usage:
# 
#
# For more information please visit http://www.love4026.org/
#
################################################################################
#

function die {
    echo "ERROR: $1" > /dev/null 1>&2
    exit 1
}

function print_info {
    echo -n -e '\e[1;36m'
    echo -n $1
    echo -e '\e[0m'
}
function print_warn {
    echo -n -e '\e[1;33m'
    echo -n $1
    echo -e '\e[0m'
}
function print_error {
    echo -n -e '\e[1;31m'
    echo -n $1
    echo -e '\e[0m'
}

function install_lnmp_vhost {
    if [ ! -z "$1" ]; then
        domain=$1
        moredomainame=" www.$domain"
        vhostdir="/home/wwwroot/$domain"
    fi

    if [ "$access_log" != 'y' ]; then
      al="access_log off;"
    else
      echo "Default access log file:$domain.log"
      alf="log_format  $domain  '\$remote_addr - \$remote_user [\$time_local] \"\$request\" '
             '\$status \$body_bytes_sent \"\$http_referer\" '
             '\"\$http_user_agent\" \$http_x_forwarded_for';"
      al="access_log  /home/wwwlogs/$domain.log  $domain;"
      touch /home/wwwlogs/$domain.log
    fi

    if [ -d /home/wwwroot ]; then
        mkdir -p $vhostdir
        chmod -R 755 $vhostdir
        chown -R www:www $vhostdir

        if [ -z $rewrite ]; then
            rewrite="none"
        fi
        if [ ! -f /usr/local/nginx/conf/$rewrite.conf ]; then
            touch /usr/local/nginx/conf/$rewrite.conf
        fi
        
        cat >/usr/local/nginx/conf/vhost/$domain.conf<<eof
$alf
server
    {
        listen       80;
        server_name $domain$moredomainame;
        index index.html index.htm index.php default.html default.htm default.php;
        root  $vhostdir;
        
        #@+ 301 redirect
        if ( \$request_uri ~* /index\.(html|htm|php)$ ) {
            rewrite ^(.*)index\.(html|htm|php)$ \$1 permanent;
        }
        if (\$host !~* ^www\.) {
            rewrite ^/(.*)$ \$scheme://www.\$host/\$1 permanent;
        }
        #@- 301 redirect

        include $rewrite.conf;
        location ~ .*\.(php|php5)?$
            {
                try_files \$uri =404;
                fastcgi_pass  unix:/tmp/php-cgi.sock;
                fastcgi_index index.php;
                include fcgi.conf;
            }

        location ~ .*\.(gif|jpg|jpeg|png|bmp|swf)$
            {
                expires      30d;
            }

        location ~ .*\.(js|css)?$
            {
                expires      12h;
            }

        $al
    }
eof
        cur_php_version=`/usr/local/php/bin/php -r 'echo PHP_VERSION;'`

        if echo "$cur_php_version" | grep -q "5.3."
        then
            cat >>/usr/local/php/etc/php.ini<<eof
[HOST=$domain]
open_basedir=$vhostdir/:/tmp/
[PATH=$vhostdir]
open_basedir=$vhostdir/:/tmp/
eof
        fi
    fi
}


function install_lnmpa_vhost {
    if [ ! -z "$1" ]; then
        domain=$1
        moredomainame=" www.$domain"
        vhostdir="/home/wwwroot/$domain"
    fi

    if [ "$access_log" != 'y' ]; then
      al="access_log off;"
    else
      alf="log_format  $domain  '\$remote_addr - \$remote_user [\$time_local] \"\$request\" '
             '\$status \$body_bytes_sent \"\$http_referer\" '
             '\"\$http_user_agent\" \$http_x_forwarded_for';"
      al="access_log  /home/wwwlogs/$domain.log  $domain;"
      touch /home/wwwlogs/$domain.log
    fi

    if [ -d /home/wwwroot ]; then
        mkdir -p $vhostdir
        chmod -R 755 $vhostdir
        chown -R www:www $vhostdir

        if [ "$rewrite" != 'none' ] && [ ! -z $rewrite ]; then
            if [ ! -f /usr/local/nginx/conf/$rewrite.conf ]; then
                echo "Create Virtul Host ReWrite file......"
                touch /usr/local/nginx/conf/$rewrite.conf
                echo "Create rewirte file successful,now you can add rewrite rule into /usr/local/nginx/conf/$rewrite.conf."
            else
                echo "You select the exist rewrite rule:/usr/local/nginx/conf/$rewrite.conf"
            fi
        fi
        
        cat >/usr/local/nginx/conf/vhost/$domain.conf<<eof
$alf
server
    {
        listen       80;
        server_name $domain$moredomainame;
        index index.html index.htm index.php default.html default.htm default.php;
        root  $vhostdir;

        location / {
            try_files \$uri @apache;
            }

        location @apache {
            internal;
            proxy_pass http://127.0.0.1:88;
            include proxy.conf;
            }

        location ~ .*\.(php|php5)?$
            {
                proxy_pass http://127.0.0.1:88;
                include proxy.conf;
            }

        location ~ .*\.(gif|jpg|jpeg|png|bmp|swf)$
            {
                expires      30d;
            }

        location ~ .*\.(js|css)?$
            {
                expires      7d;
            }

        $al
    }
eof

        cat >/usr/local/apache/conf/vhost/$domain.conf<<eof
<VirtualHost *:88>
ServerAdmin webmaster@example.com
php_admin_value open_basedir "$vhostdir:/tmp/:/var/tmp/:/proc/"
DocumentRoot "$vhostdir"
ServerName $domain
ServerAlias $moredomainame
ErrorLog "logs/$domain-error_log"
CustomLog "logs/$domain-access_log" common
</VirtualHost>
eof

        if [ "$access_log" != 'y' ]; then
            sed -i 's/ErrorLog/#ErrorLog/g' /usr/local/apache/conf/vhost/$domain.conf
            sed -i 's/CustomLog/#CustomLog/g' /usr/local/apache/conf/vhost/$domain.conf
        fi
    fi
}

function check_mycnf() {
    if ! mysql -u root -e ";" ; then
        print_warn "Your are not set your mysql permissions"
        mysqlrootpwd=""
        read -p "Please input the root password of mysql:" mysqlrootpwd
        while ! mysql -u root -p$mysqlrootpwd  -e ";" ; do
            read -p "Can't connect to Mysql, please retry: " mysqlrootpwd
        done
        cat > ~/.my.cnf <<END
[client]
user = root
password = $mysqlrootpwd
END
        chmod 600 ~/.my.cnf
    fi
}

function get_domain_name() {
    # Getting rid of the lowest part.
    domain=${1%.*}
    lowest=`expr "$domain" : '.*\.\([a-z][a-z]*\)'`
    case "$lowest" in
    com|net|org|gov|edu|co)
        domain=${domain%.*}
        ;;
    esac
    lowest=`expr "$domain" : '.*\.\([a-z][a-z]*\)'`
    [ -z "$lowest" ] && echo "$domain" || echo "$lowest"
}
function get_password() {
    # Check whether our local salt is present.
    SALT=/var/lib/radom_salt
    if [ ! -f "$SALT" ]
    then
        head -c 512 /dev/urandom > "$SALT"
        chmod 400 "$SALT"
    fi
    password=`(cat "$SALT"; echo $1) | md5sum | base64`
    echo ${password:0:13}
}

function add_ftp {
    check_mycnf
    ftpusername=`expr substr $(echo $1 | tr -d '.') 1 16`
    ftppwd=`get_password "$ftpusername@ftp"`
    mysql -u root <<EOF
INSERT INTO ftpusers.users VALUES ('$ftpusername',MD5('$ftppwd'),501, 501, '$vhostdir', 100, 50, 1000, 1000, '*', 'by shell script added, $(date +"%Y-%m-%d")', '1', 0, 0);
EOF
    if [ $? -ne 0 ]; then
        print_error "Add ftp user failure!"
    fi
    cat >> "/home/wwwroot/$1/$1.ftp.txt" <<END
[$1.ftp]
domainname = $1
username = $ftpusername
password = $ftppwd
END
}

function add_mysql {
    check_mycnf
    # Setting up the MySQL database
    dbname=`echo $1 | tr . _`
    userid=`get_domain_name $1`
    userid=$userid$(date +"%y%m%d")
    # MySQL userid cannot be more than 15 characters long
    userid="${userid:0:15}"
    passwd=`get_password "$userid@mysql"`

    echo "CREATE DATABASE IF NOT EXISTS \`$dbname\` CHARACTER SET utf8 COLLATE utf8_general_ci;" | mysql
    echo "GRANT ALL PRIVILEGES ON \`$dbname\`.* TO \`$userid\`@localhost IDENTIFIED BY '$passwd';" | \
        mysql

    if [ $? -ne 0 ]; then
        print_error "Add mysql database failure!"
    fi

    cat >> "/home/wwwroot/$1/$1.mysql.txt" <<END
[$1.myqsl]
dbname = $dbname
username = $userid
password = $passwd
END

}


function install_wordpress {
    check_mycnf
    if [ ! -d "/tmp/wordpress.$$" ]; then
        # Downloading the WordPress' latest and greatest distribution.
        mkdir /tmp/wordpress.$$
        wget -O - http://wordpress.org/latest.tar.gz | \
            tar zxf - -C /tmp/wordpress.$$
    fi
    cp -r /tmp/wordpress.$$/wordpress/* "/home/wwwroot/$1"
    chown -R www:www "/home/wwwroot/$1"
    chmod -R 755 "/home/wwwroot/$1"

    # Setting up the MySQL database
    dbname=`echo $1 | tr . _`
    userid=`get_domain_name $1`
    # MySQL userid cannot be more than 15 characters long
    userid="${userid:0:15}"
    userid=$userid$(date +"%y%m%d")
    passwd=`get_password "$userid@mysql"`
    cp "/home/wwwroot/$1/wp-config-sample.php" "/home/wwwroot/$1/wp-config.php"
    sed -i "s/database_name_here/$dbname/; s/username_here/$userid/; s/password_here/$passwd/" \
        "/home/wwwroot/$1/wp-config.php"
    sed -i "31a define(\'WP_CACHE\', true);"  "/home/wwwroot/$1/wp-config.php"
    # Grab WordPress Salt Keys
    wget -O /tmp/wp.keys -q https://api.wordpress.org/secret-key/1.1/salt/
    sed -i '/#@-/r /tmp/wp.keys' "/home/wwwroot/$1/wp-config.php"
    sed -i "/#@+/,/#@-/d" "/home/wwwroot/$1/wp-config.php"
    rm /tmp/wp.keys
    # chown -R www:www "/home/wwwroot/$1/wp-config.php"
    echo "CREATE DATABASE IF NOT EXISTS \`$dbname\` CHARACTER SET utf8 COLLATE utf8_general_ci;" | mysql
    echo "GRANT ALL PRIVILEGES ON \`$dbname\`.* TO \`$userid\`@localhost IDENTIFIED BY '$passwd';" | \
        mysql
    cat >> "/home/wwwroot/$1/$1.mysql.txt" <<END
[$1.wordpress_myqsl]
dbname = $dbname
username = $userid
password = $passwd
END
}

function install_typecho {
    check_mycnf
    if [ ! -d "/tmp/typecho.$$" ]; then
        # Downloading typecho build version
        mkdir /tmp/typecho.$$
        wget -O - "http://typecho.org/build.tar.gz" | \
            tar zxf - -C /tmp/typecho.$$
    fi
    cp -r /tmp/typecho.$$/build/* "/home/wwwroot/$1"
    chown -R www "/home/wwwroot/$1"
    chmod -R 755 "/home/wwwroot/$1"
}

function install_empirecms {
    check_mycnf
    if [ ! -d "/tmp/empirecms.$$" ]; then
        # Downloading the EmpireCMS
        mkdir /tmp/empirecms.$$
        wget -O - https://github.com/sbmzhcn/EmpireCMS/archive/v7.0.tar.gz | \
            tar zxf - -C /tmp/empirecms.$$
    fi
    cp -r /tmp/empirecms.$$/EmpireCMS-7.0/upload/* "/home/wwwroot/$1"
    sed -i "s/value=\"username\"/value=\"$userid\"/; s/value=\"empirecms\"/value=\"$dbname\"/; s/id=\"mydbpassword\"/& value=\"$passwd\"/" \
        "/home/wwwroot/$1/e/install/index.php"
    sed -i "s/想[^<]*/请尽忙完成安装，以免被人窥探到数据库信息/" "/home/wwwroot/$1/e/install/index.php"
    chown -R www:www "/home/wwwroot/$1"
    chmod -R 755 "/home/wwwroot/$1"
    cat >> "/home/wwwroot/$1/$1.mysql.txt" <<END
[$1.empirecms.install.url]
# Please enter the url in your brower and install it ASAP
http://www.$1/e/install/index.php?enews=setdb&f=4
END
}

if [ "$#" = "2" ] && [ "$1" = "--remove" ]; then
    check_mycnf
    echo "Now removing vhost: $2, contain ftp,mysql,vhost ..."
    dbname=`echo $2 | tr . _`
    ftpusername=`expr substr $(echo $2 | tr -d '.') 1 16`
    rm -rf "/home/wwwroot/$2"
    echo "DROP DATABASE $dbname" | mysql
    echo "DELETE FROM ftpusers.users WHERE User='$ftpusername'" | mysql
    rm -rf "/usr/local/nginx/conf/vhost/$2.conf"
    rm -rf "/usr/local/apache/conf/vhost/$2.conf"
    print_info "Remove $2 complete!"
    exit 1
fi

while getopts "d:rlfma:" arg #选项后面的冒号表示该选项需要参数
do
    case $arg in
    d) # domain list
        domainlist=$OPTARG
    ;;
    r) # allow rewrite
        if [ -z "$1" ];
            rewrite="none"
        then
            rewrite=$OPTARG
        fi
    ;;
    l) # enable access log
        access_log="y"
    ;;
    f) # add ftp
        check_mycnf
        add_ftp="y"
    ;;
    m) # add mysql
        check_mycnf
        add_mysql="y"
    ;;
    a) # install web app
        check_mycnf
        web_app=$OPTARG
    ;;
    ?)  #当有不认识的选项的时候arg为?
        echo "unkonw argument"
    exit 1
    ;;
    esac
done


for domain in $domainlist; do
    if [ ! -z "$domain" ]; then
        if [ -f "/usr/local/nginx/conf/vhost/$domain.conf" ]; then
            print_warn "$domain is exist! Please install it manual"
            break
        fi
        if [ -x /etc/init.d/httpd ]; then
            install_lnmpa_vhost $domain
        else
            install_lnmp_vhost $domain
        fi
        # add ftp account
        if [ "$add_ftp" == 'y' ]; then
            add_ftp $domain
        fi
        # add mysql account
        if [ "$add_mysql" == 'y' ]; then
            add_mysql $domain
        fi
        # install web application
        case "$web_app" in
        wordpress)
            install_wordpress $domain
            ;;
        typecho)
            install_typecho $domain
            ;;
        empirecms)
            install_empirecms $domain
            ;;
        esac

        print_info "Add vhost for domain:$domain successful"
        echo "================================================" | tee -a /root/all_domain_ftp_mysql.txt
        cat "/home/wwwroot/$domain/$domain.ftp.txt" | tee -a /root/all_domain_ftp_mysql.txt
        cat "/home/wwwroot/$domain/$domain.mysql.txt" 2>/dev/null | tee -a /root/all_domain_ftp_mysql.txt
        echo "================================================" | tee -a /root/all_domain_ftp_mysql.txt
        echo "" >>/root/all_domain_ftp_mysql.txt
    fi
done

# remove web app content
if [ -d "/tmp/$web_app.$$" ] && [ "$web_app" != "" ]; then
    rm -rf "/tmp/$web_app.$$"
fi

echo ""
if [ -x /etc/init.d/php-fpm ]; then
    /etc/init.d/php-fpm restart
fi
echo "Test Nginx configure file......"
/usr/local/nginx/sbin/nginx -t
echo ""
echo "Restart Nginx......"
/usr/local/nginx/sbin/nginx -s reload
if [ -x /etc/init.d/httpd ]; then
    echo "Restart Apache......"
    /etc/init.d/httpd restart
fi
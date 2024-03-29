#!/bin/bash

if [ $LANG="'echo $LANG | grep fr'" ]
then
	. fr.conf
else
	. en.conf
fi

# Verification if the current user is root (for all privileges)
if [ "$USER" != "root" ]; then
    echo "$ths_root"
    exit
fi

# Definition of the variable CFG to $CFG
CFG='$CFG'

# Definition of the loop to choose or not to secure the site in HTTPS
boucleSSL(){

	apt-get update -y && apt-get install openssl -y
	openssl genrsa -out /etc/ssl/private/moodle.key 2048
	openssl req -new -key /etc/ssl/private/moodle.key -out /etc/ssl/certs/moodle.csr
	openssl x509 -req -days 365 -in /etc/ssl/certs/moodle.csr -signkey /etc/ssl/private/moodle.key -out /etc/ssl/certs/moodle.crt
		
}

# Definition of the loop to setup the installation of the necessary packages
boucleInstall(){
	# Installation of the necessary packages
	apt-get install apache2 apache2-doc mariadb-server mariadb-client php php-apcu php-bcmath php-bz2 php-curl php-fpm php-gd php-geoip php-gmp php-imagick php-intl php-ldap php-mbstring php-memcached php-msgpack php-mysql php-pear php-soap php-xml php-xmlrpc php-zip libapache2-mod-php imagemagick net-tools wget -y && apt-get autoremove -y
}

# Definition of the loop to install Moodle
boucleMoodle(){
		
	read -p "$generate_ssl " ssl
	if [ "$ssl" = "o" -o "$ssl" = "O" -o "$ssl" = "y" -o "$ssl" = "Y" ]; then
		ssl="o"
		boucleSSL
	fi
	boucleInstall
		
	# Create database and user
	mysql -u root -e "CREATE DATABASE IF NOT EXISTS $dataname CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
	mysql -u root -e "CREATE USER $datauser@localhost IDENTIFIED BY '$datapdw';"
	mysql -u root -e "GRANT ALL PRIVILEGES ON $dataname.* TO $datauser@localhost;"
	mysql -u root -e "FLUSH PRIVILEGES;"
		
	# Create minimal configuration of apache
	if [ "$ssl" = "o" -o "$ssl" = "O" ]; then
		touch /etc/apache2/sites-available/moodle.conf
		echo "<VirtualHost *:80>\n   ServerName $ip\n   Redirect permanent / https://$ip/\n</VirtualHost>\n<VirtualHost *:443>\n   DocumentRoot /var/www/moodle/\n   ServerName $ip\n   <Directory /var/www/moodle/>\n        Options -Indexes +FollowSymlinks +MultiViews\n        AllowOverride None\n        Require all granted\n   </Directory>\n   ErrorLog /var/log/apache2/moodle.error.log\n   CustomLog /var/log/apache2/moodle.access.log combined\n   SSLEngine On\n   SSLOptions +FakeBasicAuth +ExportCertData +StrictRequire\n   SSLCertificateFile /etc/ssl/certs/moodle.crt\n   SSLCertificateKeyFile /etc/ssl/private/moodle.key\n</VirtualHost>\n" > /etc/apache2/sites-available/moodle.conf
		a2dissite 000-default && a2ensite moodle && a2enmod ssl
	elif [ "$ssl" = "n" -o "$ssl" = "N" -o "$ssl" = "" ]; then
		touch /etc/apache2/sites-available/moodle.conf
		echo "<VirtualHost *:80>\n   DocumentRoot /var/www/moodle/\n   ServerName $ip\n   <Directory /var/www/moodle/>\n        Options -Indexes +FollowSymlinks +MultiViews\n        AllowOverride None\n        Require all granted\n   </Directory>\n   ErrorLog /var/log/apache2/moodle.error.log\n   CustomLog /var/log/apache2/moodle.access.log combined\n</VirtualHost>\n" > /etc/apache2/sites-available/moodle.conf
		a2dissite 000-default && a2ensite moodle
	fi
		
	# Configuration of PHP
	echo "\nopcache.memory_consumption=128\nopcache.interned_strings_buffer=8\nopcache.max_accelerated_files=16229\nopcache.revalidate_freq=60\nopcache.fast_shutdown=1\nopcache.enable_cli=1" >> /etc/php/7.3/mods-available/opcache.ini
		
	sed -i 's/memory_limit = 128M/memory_limit = 96M/' "/etc/php/7.3/apache2/php.ini" && sed -i 's/;date.timezone =/date.timezone = "Europe/Paris"/' "/etc/php/7.3/apache2/php.ini" && sed -i 's/;opcache.enable=1/opcache.enable=1/' "/etc/php/7.3/apache2/php.ini"
		
	# Download Moodle
	wget https://github.com/MATAR0U/web_install/raw/main/sources/moodle.tgz && tar xzvf moodle.tgz && mv moodle/ /var/www/
		
	# Create Moodle user for data
	adduser --system moodle && mkdir /home/moodle/moodledata && chown -R www-data:www-data /home/moodle/moodledata/ && chmod 0777 /home/moodle/moodledata
		
	# Create the file for the configuration of database in the site
	touch /var/www/moodle/config.php
	if [ "$ssl" = "o" -o "$ssl" = "O" ]; then
		echo "<?php  // Moodle configuration file\nunset($CFG);\nglobal $CFG;\n$CFG = new stdClass();\n$CFG->dbtype    = 'mariadb';\n$CFG->dblibrary = 'native';\n$CFG->dbhost    = 'localhost';\n$CFG->dbname    = '$dataname';\n$CFG->dbuser    = '$datauser';\n$CFG->dbpass    = '$datapdw';\n$CFG->prefix    = 'mdl_';\n$CFG->dboptions = array (\n  'dbpersist' => 0,\n  'dbport' => '',\n  'dbsocket' => '',\n  'dbcollation' => 'utf8mb4_unicode_ci',\n);\n$CFG->wwwroot   = 'https://$ip';\n$CFG->dataroot  = '/home/moodle/moodledata';\n$CFG->admin     = 'admin';\n$CFG->directorypermissions = 0777;\nrequire_once(__DIR__ . '/lib/setup.php');\n// There is no php closing tag in this file,\n// it is intentional because it prevents trailing whitespace problems!" > /var/www/moodle/config.php
	else
		echo "<?php  // Moodle configuration file\nunset($CFG);\nglobal $CFG;\n$CFG = new stdClass();\n$CFG->dbtype    ='mariadb';\n$CFG->dblibrary = 'native';\n$CFG->dbhost    = 'localhost';\n$CFG->dbname    = '$dataname';\n$CFG->dbuser    = '$datauser';\n$CFG->dbpass    = '$datapdw';\n$CFG->prefix    = 'mdl_';\n$CFG->dboptions = array (\n  'dbpersist' => 0,\n  'dbport' => '',\n  'dbsocket' => '',\n  'dbcollation' => 'utf8mb4_unicode_ci',\n);\n$CFG->wwwroot   = 'http://$ip';\n$CFG->dataroot  = '/home/moodle/moodledata';\n$CFG->admin     = 'admin';\n$CFG->directorypermissions = 0777;\nrequire_once(__DIR__ . '/lib/setup.php');\n// There is no php closing tag in this file,\n// it is intentional because it prevents trailing whitespace problems!\n" > /var/www/moodle/config.php
		
	fi
		
	echo "\n[mysqld]\ncharacter-set-client-handshake = FALSE\ncharacter-set-server = utf8mb4\ncollation-server = utf8mb4_unicode_ci" >> /etc/mysql/my.cnf
		
	# Configuration of permissions
	chown -R root:www-data /var/www/moodle/ && chmod -R 0755 /var/www/moodle/
		
	# Restart service
	systemctl restart apache2 && systemctl restart mariadb
		
	# End
	if [ "$ssl" = "o" ]; then
		echo "\n\n$end_address"
		echo -e "${light_green}https://$ip${neutral}"
	else
		echo "\n\n$end_address"
		echo -e "${light_green}http://$ip${neutral}"
	fi
}

# Get and initialise in variable the options after the command to execute the script

required=0
rgxIP='^[0-9.]+$'
rgx='^[a-zA-Z0-9._]+$'

if [ "$1" = "-h" ] || [ "$1" = "--help" ]
then
	if [ $(grep " " <<<$2) ] || [ "$2" = "" ]
	then
		echo ""
		echo $this_is_setup
		echo $help_option
		echo $database_option
		echo $database_user_option
		echo $database_password_option
		echo $ip_option
		echo ""
		exit
	else
		echo ""
		echo $incorrect_setup
		echo -e "${light_green}$1${neutral}"
		echo $user_help_option
	fi
fi

number=$((($#/2)+1))

while [ "$number" -gt 0 ]
do
	if [ "$1" = "-d" ] || [ "$1" = "--data-base" ]
	then
		if [[ "$2" =~ $rgx ]]
		then
			dataname=$2
			required=$(($required+1))
			shift
			shift
		else
			echo ""
			echo  $incorrect_setup
			echo -e "${light_green}$1${neutral}"
			echo  $user_help_option
			echo ""
			exit
		fi
	fi

	if [ "$1" = "-u" ] || [ "$1" = "--user" ]
	then
		if [[ "$2" =~ $rgx ]]
		then
			datauser=$2
			required=$(($required+1))
			shift
			shift
		else
			echo ""
			echo $incorrect_setup
			echo -e "${light_green}$1${neutral}"
			echo $user_help_option
			echo ""
			exit
		fi
	fi

	if [ "$1" = "-p" ] || [ "$1" = "--password" ]
	then
		datapdw=$2
		required=$(($required+1))
		shift
		shift
	fi

	if [ "$1" = "--ip" ]
	then
		if [[ "$2" =~ $rgxIP ]]
		then
			ip=$2
			required=$(($required+1))
			shift 2
		else
			echo ""
			echo $incorrect_setup
			echo -e "${light_green}$1${neutral}"
			echo $user_help_option
			echo ""
			exit
		fi
	fi
	number=$(($number-1))

	if [ "$1" = "-i" ]
	then
		if [[ "$2" =~ $rgx ]]
		then
			interfaces=$2
			ip=$(ifconfig $interfaces | awk '/inet / {print $2}' | cut -d ':' -f2)
			required=$(($required+1))
			shift 2
		else
			echo ""
			echo $incorrect_setup
			echo -e "${light_green}$1${neutral}"
			echo $user_help_option
			echo ""
			exit
		fi
	fi
	number=$(($number-1))
done
if [ "$required" -lt 4 ]
then
	echo ""
	echo $option_required_blank
	echo "("$required $option_requierd_blank1
	echo $user_help_option
	echo ""
	exit
fi

echo ""
echo "$summary"
echo ""
echo -e $name_database
echo -e "${light_green}$dataname${neutral}"
echo -e $username
echo -e "${light_green}$datauser${neutral}"
echo -e $password
echo -e "${light_green}$datapdw${neutral}"
echo -e $resume_ip
echo -e "${light_green}$ip${neutral}"
echo ""
echo $correct_information
read valide
if [ "$valide" != "o" ] && [ "$valide" != "O" ] && [ "$valide" != "y" ] && [ "$valide" != "Y" ]
then
	exit
fi
	
boucleMoodle

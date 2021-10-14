#!/bin/sh

#Definition de la variable $CFG
CFG='$CFG'

#Verification de l'utilisateur
if [ "$USER" = "root" ]; then
    echo "OK"
else
    echo "Merci d'executer ce script en root pour avoir tout les droits"
    exit
fi

#Definition de la boucle pour choisir son interface reseau
boucleip(){
    clear
    ip a
    echo -n "\nQuel est ton interface reseau utiliser ? "
    read interfaces
}

#Definition de la boucle pour choisir ou non de securiser le site en HTTPS
boucleSSL(){

	apt-get update -y && apt-get install openssl -y
	openssl genrsa -out /etc/ssl/private/moodle.key 2048
	openssl req -new -key /etc/ssl/private/moodle.key -out /etc/ssl/certs/moodle.csr
	openssl x509 -req -days 365 -in /etc/ssl/certs/moodle.csr -signkey /etc/ssl/private/moodle.key -out /etc/ssl/certs/moodle.crt
		
}

#Definition de la boucle installation
boucleInstall(){
	#Installation de tous les composants utiles
	apt-get update -y && apt-get upgrade -y && apt-get install apache2 apache2-doc mariadb-server mariadb-client php php-apcu php-bcmath php-bz2 php-curl php-fpm php-gd php-geoip php-gmp php-imagick php-intl php-ldap php-mbstring php-memcached php-msgpack php-mysql php-pear php-soap php-xml php-xmlrpc php-zip libapache2-mod-php imagemagick net-tools wget -y && apt-get autoremove -y
}

#Definition de la boucle Moodle
boucleMoodle(){
		
		
	#Definition de la boucle pour choisir un nom pour la base de donnee
	boucleDATABASE(){
		echo -n "\nChoisi un nom pour la base de donnee : "
		read dataname
		echo -n "Etes vous sur de choisir $dataname (O/n) ? "
		read sure
		if [ "$sure" = "o" -o "$sure" = "O" -o "$sure" = "" ]; then
			echo "Le nom de votre base de donniee sera $dataname"
		elif [ "$sure" = "n" -o "$sure" = "N" ]; then
			boucleDATABASE
		fi
	}
		
	#Definition de la boucle pour le nom d'utilisateur de la base de donnee
	boucleUSER(){
		echo -n "\nChoisi un nom d'utilisateur pour la base de donnee $dataname : "
		read datauser
		echo -n "Etes vous sur de choisir $datauser (O/n) ? "
		read sure
		if [ "$sure" = "o" -o "$sure" = "O" -o "$sure" = "" ]; then
			echo "Le nom d'utilisateur pour la base de donnee $dataname sera $datauser"
		elif [ "$sure" = "n" -o "$sure" = "N" ]; then
			boucleUSER
		else
			boucleUSER
		fi
	}
		
	#Definition de la boucle pour le mot de passe de l'utilisateur de la base de donnee
	bouclePASSWD(){
		echo -n "\nChoisi un mot de passe pour l'utilisateur $datauser : "
		read datapdw
		echo -n "Etes vous sur de choisir $datapdw (O/n) ? "
		read sure
		if [ "$sure" = "o" -o "$sure" = "O" -o "$sure" = "" ]; then
			echo "Le mot de passe de l'utilisateur $datauser de la base de donnee $dataname sera $datapdw"
		elif [ "$sure" = "n" -o "$sure" = "N" ]; then
			bouclePASSWD
		else
			bouclePASSWD
		fi
	}
		
	#Lancement des boucles
	boucleip
	echo -n "Faut il generer une cle SSL (o/N) ? "
	read ssl
	if [ "$ssl" = "o" -o "$ssl" = "O" ]; then
		boucleSSL
	fi
	boucleDATABASE
	boucleUSER
	bouclePASSWD
	boucleInstall
		
	#Recuperation de l'ip
	ip=$(ifconfig $interfaces | awk '/inet / {print $2}' | cut -d ':' -f2)
		
	#Creation et configuration de la base de donnee
	mysql -u root -e "CREATE DATABASE IF NOT EXISTS $dataname CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
	mysql -u root -e "CREATE USER $datauser@localhost IDENTIFIED BY '$datapdw';"
	mysql -u root -e "GRANT ALL PRIVILEGES ON $dataname.* TO $datauser@localhost;"
	mysql -u root -e "FLUSH PRIVILEGES;"
		
	#Creation de la configuration apache minimal
	if [ "$ssl" = "o" -o "$ssl" = "O" ]; then
		touch /etc/apache2/sites-available/moodle.conf
		echo "<VirtualHost *:80>\n   ServerName $ip\n   Redirect permanent / https://$ip/\n</VirtualHost>\n<VirtualHost *:443>\n   DocumentRoot /var/www/moodle/\n   ServerName $ip\n   <Directory /var/www/moodle/>\n        Options -Indexes +FollowSymlinks +MultiViews\n        AllowOverride None\n        Require all granted\n   </Directory>\n   ErrorLog /var/log/apache2/moodle.error.log\n   CustomLog /var/log/apache2/moodle.access.log combined\n   SSLEngine On\n   SSLOptions +FakeBasicAuth +ExportCertData +StrictRequire\n   SSLCertificateFile /etc/ssl/certs/moodle.crt\n   SSLCertificateKeyFile /etc/ssl/private/moodle.key\n</VirtualHost>\n" > /etc/apache2/sites-available/moodle.conf
		a2dissite 000-default && a2ensite moodle && a2enmod ssl
	elif [ "$ssl" = "n" -o "$ssl" = "N" -o "$ssl" = "" ]; then
		touch /etc/apache2/sites-available/moodle.conf
		echo "<VirtualHost *:80>\n   DocumentRoot /var/www/moodle/\n   ServerName $ip\n   <Directory /var/www/moodle/>\n        Options -Indexes +FollowSymlinks +MultiViews\n        AllowOverride None\n        Require all granted\n   </Directory>\n   ErrorLog /var/log/apache2/moodle.error.log\n   CustomLog /var/log/apache2/moodle.access.log combined\n</VirtualHost>\n" > /etc/apache2/sites-available/moodle.conf
		a2dissite 000-default && a2ensite moodle
	fi
		
	#Configuration de PHP
	echo "\nopcache.memory_consumption=128\nopcache.interned_strings_buffer=8\nopcache.max_accelerated_files=16229\nopcache.revalidate_freq=60\nopcache.fast_shutdown=1\nopcache.enable_cli=1" >> /etc/php/7.3/mods-available/opcache.ini
		
	sed -i 's/memory_limit = 128M/memory_limit = 96M/' "/etc/php/7.3/apache2/php.ini" && sed -i 's/;date.timezone =/date.timezone = "Europe/Paris"/' "/etc/php/7.3/apache2/php.ini" && sed -i 's/;opcache.enable=1/opcache.enable=1/' "/etc/php/7.3/apache2/php.ini"
		
	#Telechargement de Moodle
	wget https://download.moodle.org/download.php/direct/stable39/moodle-latest-39.tgz && tar xzvf moodle-latest-39.tgz && mv moodle/ /var/www/
		
	#Creation d'un utilisateur Moodle pour stocker les donnees
	adduser --system moodle && mkdir /home/moodle/moodledata && chown -R www-data:www-data /home/moodle/moodledata/ && chmod 0777 /home/moodle/moodledata
		
	#Creation du fichier de configuration enter le site et la base de donnee de Moodle
	touch /var/www/moodle/config.php
	if [ "$ssl" = "o" -o "$ssl" = "O" ]; then
		echo "<?php  // Moodle configuration file\nunset($CFG);\nglobal $CFG;\n$CFG = new stdClass();\n$CFG->dbtype    = 'mariadb';\n$CFG->dblibrary = 'native';\n$CFG->dbhost    = 'localhost';\n$CFG->dbname    = '$dataname';\n$CFG->dbuser    = '$datauser';\n$CFG->dbpass    = '$datapdw';\n$CFG->prefix    = 'mdl_';\n$CFG->dboptions = array (\n  'dbpersist' => 0,\n  'dbport' => '',\n  'dbsocket' => '',\n  'dbcollation' => 'utf8mb4_unicode_ci',\n);\n$CFG->wwwroot   = 'https://$ip';\n$CFG->dataroot  = '/home/moodle/moodledata';\n$CFG->admin     = 'admin';\n$CFG->directorypermissions = 0777;\nrequire_once(__DIR__ . '/lib/setup.php');\n// There is no php closing tag in this file,\n// it is intentional because it prevents trailing whitespace problems!" > /var/www/moodle/config.php
	else
		echo "<?php  // Moodle configuration file\nunset($CFG);\nglobal $CFG;\n$CFG = new stdClass();\n$CFG->dbtype    ='mariadb';\n$CFG->dblibrary = 'native';\n$CFG->dbhost    = 'localhost';\n$CFG->dbname    = '$dataname';\n$CFG->dbuser    = '$datauser';\n$CFG->dbpass    = '$datapdw';\n$CFG->prefix    = 'mdl_';\n$CFG->dboptions = array (\n  'dbpersist' => 0,\n  'dbport' => '',\n  'dbsocket' => '',\n  'dbcollation' => 'utf8mb4_unicode_ci',\n);\n$CFG->wwwroot   = 'http://$ip';\n$CFG->dataroot  = '/home/moodle/moodledata';\n$CFG->admin     = 'admin';\n$CFG->directorypermissions = 0777;\nrequire_once(__DIR__ . '/lib/setup.php');\n// There is no php closing tag in this file,\n// it is intentional because it prevents trailing whitespace problems!\n" > /var/www/moodle/config.php
		
	fi
		
	echo "\n[mysqld]\ncharacter-set-client-handshake = FALSE\ncharacter-set-server = utf8mb4\ncollation-server = utf8mb4_unicode_ci" >> /etc/mysql/my.cnf
		
	#Modification des permissions
	chown -R root:www-data /var/www/moodle/ && chmod -R 0755 /var/www/moodle/
		
	#Redemarrage
	systemctl restart apache2 && systemctl restart mariadb
		
	#Fin
	if [ "$ssl" = "o" -o "$ssl" = "O" ]; then
		echo "\n\nVous pouvez maintenant acceder a Moodle a l'adresse suivant : https://$ip"
	else
		echo "\n\nVous pouvez maintenant acceder a Moodle a l'adresse suivant : http://$ip"
	fi
}

		
#Installer moodle ou juste HTTPS
boucleHTTPS(){
	echo -n "Faut il installer moodle ou seulement le sécuriser en HTTPS (moodle / https) ? "
	read https
	if [ "$https" = "moodle" ]; then
		boucleMoodle
	elif [ "$https" = "https" ]; then
		boucleip
		#Recuperation de l'ip
		ip=$(ifconfig $interfaces | awk '/inet / {print $2}' | cut -d ':' -f2)
				
		boucleSSL
		boucleInstall
		echo -n "\nQuel est le nom de la base de donnée ? "
		read dataname
		echo -n "\nQuel est l'utilisateur administrateur de $dataname ? "
		read datauser
		echo -n "\nQuel est le mot de passe de l'utilisateur $datauser ? "
		read datapdw
		touch /etc/apache2/sites-available/moodle.conf
		echo "<VirtualHost *:80>\n   ServerName $ip\n   Redirect permanent / https://$ip/\n</VirtualHost>\n<VirtualHost *:443>\n   DocumentRoot /var/www/moodle/\n   ServerName $ip\n   <Directory /var/www/moodle/>\n        Options -Indexes +FollowSymlinks +MultiViews\n        AllowOverride None\n        Require all granted\n   </Directory>\n   ErrorLog /var/log/apache2/moodle.error.log\n   CustomLog /var/log/apache2/moodle.access.log combined\n   SSLEngine On\n   SSLOptions +FakeBasicAuth +ExportCertData +StrictRequire\n   SSLCertificateFile /etc/ssl/certs/moodle.crt\n   SSLCertificateKeyFile /etc/ssl/private/moodle.key\n</VirtualHost>\n" > /etc/apache2/sites-available/moodle.conf
		a2dissite 000-default && a2ensite moodle && a2enmod ssl
				
		echo "<?php  // Moodle configuration file\nunset($CFG);\nglobal $CFG;\n$CFG = new stdClass();\n$CFG->dbtype    = 'mariadb';\n$CFG->dblibrary = 'native';\n$CFG->dbhost    = 'localhost';\n$CFG->dbname    = '$dataname';\n$CFG->dbuser    = '$datauser';\n$CFG->dbpass    = '$datapdw';\n$CFG->prefix    = 'mdl_';\n$CFG->dboptions = array (\n  'dbpersist' => 0,\n  'dbport' => '',\n  'dbsocket' => '',\n  'dbcollation' => 'utf8mb4_unicode_ci',\n);\n$CFG->wwwroot   = 'https://$ip';\n$CFG->dataroot  = '/home/moodle/moodledata';\n$CFG->admin     = 'admin';\n$CFG->directorypermissions = 0777;\nrequire_once(__DIR__ . '/lib/setup.php');\n// There is no php closing tag in this file,\n// it is intentional because it prevents trailing whitespace problems!" > /var/www/moodle/config.php
			
		chown -R root:www-data /var/www/moodle/ && chmod -R 0755 /var/www/moodle/
		systemctl restart apache2 && systemctl restart mariadb
		echo "\n\nVous pouvez maintenant acceder a Moodle a l'adresse suivant : https://$ip"
	fi
}

#Execution des boucle
boucleHTTPS
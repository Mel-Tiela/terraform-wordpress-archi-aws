#!/bin/bash
sudo apt update -y
sudo apt install -y apache2 
sudo apt install -y mysql-server
sudo apt install -y php
sudo apt install -y php-mysql
sudo ufw allow 'Apache'
sudo systemctl start apache2
sudo systemctl start mysql.service
cd /tmp/
curl -O https://wordpress.org/latest.tar.gz
tar xzvf latest.tar.gz
touch /tmp/wordpress/.htaccess
cp /tmp/wordpress/wp-config-sample.php /tmp/wordpress/wp-config.php
mkdir /tmp/wordpress/wp-content/upgrade
sudo cp -a /tmp/wordpress/. /var/www/html/wordpress
cd /var/www/html/
rm index.html
cd /home/ubuntu
sudo systemctl restart apache2

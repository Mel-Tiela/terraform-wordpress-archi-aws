#!/bin/bash
sudo apt update
sudo apt install apache2 \
                 ghostscript \
                 libapache2-mod-php \
                 mysql-server \
                 php \
                 php-curl \
                 php-json \
                 php-mbstring \
                 php-mysql \
                 php-xml \
               
sudo ufw allow 'Apache'
sudo systemctl start apache2
sudo systemctl start mysql.service
curl https://wordpress.org/latest.tar.gz 
tar -xzf latest.tar.gz 
cd wordpress
cp wp-config-sample.php wp-config.php
cd /home/ubuntu
sudo cp -r wordpress/* /var/www/html/
sudo systemctl restart apache2
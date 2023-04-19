#!/bin/bash
sudo apt-get update
sudo apt-get install mysql-client -y
sudo apt-get install unzip awscli -y
sudo apt-get install apache2 -y
sudo apt-get install libapache2-mod-wsgi-py3 -y
sudo systemctl start apache2.service
sudo apt-get install tidy -y
sudo apt-get update -y
sudo sudo apt-get install python3 -y
sudo apt-get install python3-flask -y
sudo apt install python3-pip -y
sudo apt-get install python3-pymysql -y
sudo apt-get install python3-boto3 -y
sudo apt-get install python3-venv -y
aws s3 cp s3://zehewebsite/website.zip ~/
cd ~/
unzip -o website.zip
cd website
python3.6 -m venv website
source website/bin/activate
pip install flask
pip install pymysql
pip install boto3
sudo cp website.conf /etc/apache2/sites-available/website.conf
sudo mkdir logs
sudo a2ensite website.conf
cd ..
sudo cp -r website /var/www/
cd
sudo cp -r /var/www/website ~/website
sudo cp -r /var/www/website /home/ubuntu/website
sudo systemctl reload apache2
sudo a2enmod wsgi
tidy -q -e *.html
sudo rm /etc/apache2/sites-available/000-default.conf 
sudo systemctl restart apache2.service
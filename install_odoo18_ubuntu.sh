#!/bin/bash

################################################################################
# Script for installing Odoo on 
#  Ubuntu   
# Author: 
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu server.  
#-------------------------------------------------------------------------------
# Make a new file:
# sudo nano install_odoo18_ubuntu.sh
# Place this content in it and then make the file executable:
# sudo chmod +x install_odoo18_ubuntu.sh
# Execute the script to install Odoo:
# ./install_odoo18_ubuntu.sh
################################################################################

### VARIABLES ###
OE_VERSION="18.0"  # Choose the Odoo version

INSTALL_NGINX="True"  # Set to True if you want to install Nginx
WEBSITE_NAME="WEBSITE_NAME"  # Set the domain name
ENABLE_SSL="True"  # Enable SSL
ADMIN_EMAIL="admin@WEBSITE_NAME"  # Email for SSL registration

INSTALL_POSTGRESQL="True"  # Install PostgreSQL
MAJOR_VERSION=${OE_VERSION%%.*}
OE_USER="odoo${MAJOR_VERSION}"
OE_HOME="/opt/$OE_USER"
OE_HOME_EXT="$OE_HOME/${OE_USER}-server"
INSTALL_WKHTMLTOPDF="True"  # Set to true if you want to install Wkhtmltopdf
OE_PORT="8069"  # Default Odoo port
OE_SUPERADMIN="admin"  # Superadmin password
DB_PASSWORD="123456" # for db_password
GENERATE_RANDOM_PASSWORD="True"  # Generate random password
OE_CONFIG="${OE_USER}"  # Odoo config name
LONGPOLLING_PORT="8072"  # Default longpolling port


# Get the Ubuntu version
version=$(lsb_release -rs)

# Check Ubuntu version
if [[ "$version" =~ ^(16.04|18.04|20.04|22.04|24.04)$ ]]; then
    echo -e "Run script on Ubuntu $version." 
else
    echo -e "\n--------"
    echo -e "ERROR: Not a supported version => exit"
    exit 1
fi

# Update and upgrade the system
echo -e "\n---- Update and upgrade the system ----"
sudo apt-get update
sudo apt-get upgrade -y

# Install Python 3 pip and other essential Python development libraries
echo -e "\n---- Install Python 3 pip and other essential Python development libraries ----"
sudo apt-get install -y python3-pip python3-dev libxml2-dev libxslt1-dev zlib1g-dev libsasl2-dev libldap2-dev build-essential libssl-dev libffi-dev libmysqlclient-dev libjpeg-dev libpq-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev

# Create a symbolic link for Node.js and install Less and Less plugins
sudo ln -s /usr/bin/nodejs /usr/bin/node
sudo npm install -g less less-plugin-clean-css
sudo apt-get install -y node-less
 
# Install PostgreSQL and create a new user for Odoo
if [ "$GENERATE_RANDOM_PASSWORD" = "True" ]; then
    echo -e "\n---- Generating random db password ----"
    DB_PASSWD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi

# Create the .pgpass file
echo -e "\n---- Setting up .pgpass file ----"
PGPASSFILE="$HOME/.pgpass"
echo "localhost:5432:*:$OE_USER:$DB_PASSWD" > $PGPASSFILE
chmod 600 $PGPASSFILE

# Install PostgreSQL
echo -e "\n---- Install PostgreSQL and create a new user for Odoo ----"
sudo apt-get install -y postgresql

# Create the user with the generated or fixed password
sudo -u postgres createuser --createdb --no-createrole --superuser $OE_USER
sudo -u postgres psql -c "ALTER USER $OE_USER WITH PASSWORD '$DB_PASSWD';"

# Check if the user exists
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$OE_USER'" | grep -q 1; then
    echo -e "\n---- New user PostgreSQL for Odoo created ----"
fi

# Create a system user for Odoo and install Git to clone the Odoo source code
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
#The user should also be added to the sudo'ers group.
sudo adduser $OE_USER sudo

sudo apt-get install -y git

echo -e "\n==== Installing ODOO Server with user $OE_USER ===="
sudo su - $OE_USER -c "git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/"

# Restart services using outdated libraries todo: check if necessary
echo -e "\n---- Install Python virtual environment and set up the Odoo environment ----"
sudo systemctl restart packagekit.service
sudo systemctl restart polkit.service
sudo systemctl restart systemd-journald.service
sudo systemctl restart systemd-networkd.service
sudo systemctl restart systemd-resolved.service
sudo systemctl restart systemd-timesyncd.service
sudo systemctl restart systemd-udevd.service

# Install Python virtual environment and set up the Odoo environment
echo -e "\n---- Install Python virtual environment and set up the Odoo environment ----"
sudo apt install -y python3-venv
sudo python3 -m venv $OE_HOME_EXT/venv


# Activate the virtual environment and install required Python packages
echo -e "\n---- Activate the virtual environment and install required Python packages ----"
cd $OE_HOME_EXT/
source $OE_HOME_EXT/venv/bin/activate
pip install -r https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt

# Install wkhtmltopdf and resolve any missing dependencies
if [ "$INSTALL_WKHTMLTOPDF" = "True" ]; then
    sudo wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb
    sudo wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
    sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb
    sudo apt-get install -y xfonts-75dpi
    sudo dpkg -i wkhtmltox_0.12.5-1.bionic_amd64.deb
    sudo apt install -f -y
fi

# Installing specific libraries in virtual environment
pip install psycopg2-binary pdfminer.six num2words ofxparse dbfread ebaysdk firebase_admin pyOpenSSL 
pip python-slugify google-auth

deactivate


echo -e "\n---- Create custom addons directory ----"
sudo su $OE_USER -c "mkdir $OE_HOME/custom"
sudo su $OE_USER -c "mkdir $OE_HOME/custom/addons"

echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "\n---- Configure the Odoo instance ----"
if [ $GENERATE_RANDOM_PASSWORD = "True" ]; then
    echo -e "* Generating random admin password"
    OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi

# Configure the Odoo instance
sudo cp $OE_HOME_EXT/debian/odoo.conf /etc/${OE_CONFIG}.conf
sudo bash -c "cat << EOF > /etc/${OE_CONFIG}.conf
[options]
; This is the password that allows database operations:
admin_passwd = $OE_SUPERADMIN
db_host = localhost
db_port = 5432
db_user = $OE_USER
db_password = $DB_PASSWD
addons_path = $OE_HOME_EXT/addons, $OE_HOME/custom/addons
default_productivity_apps = True
logfile = /var/log/odoo/${OE_CONFIG}.log
xmlrpc_interface = 127.0.0.1
netrpc_interface = 127.0.0.1
xmlrpc_port = 8069
gevent_port = 8072
limit_memory_hard = 1677721600
limit_memory_soft = 629145600
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200
max_cron_threads = 1
workers = 5
EOF"

# Replace http_port ou xmlrpc_port 
if [ "$OE_VERSION" > "11.0" ]; then
    # Replace or add http_port
    sudo sed -i "/^http_port/c\http_port = $OE_PORT" /etc/${OE_CONFIG}.conf || echo "http_port = $OE_PORT" | sudo tee -a /etc/${OE_CONFIG}.conf
else
    # Replace or add xmlrpc_port
    sudo sed -i "/^xmlrpc_port/c\xmlrpc_port = $OE_PORT" /etc/${OE_CONFIG}.conf || echo "xmlrpc_port = $OE_PORT" | sudo tee -a /etc/${OE_CONFIG}.conf
fi


echo -e "\n---- Set correct permissions on the Odoo configuration file ----"
# Set correct permissions on the Odoo configuration file
sudo chown $OE_USER: /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

# Create a directory for Odoo log files and set appropriate ownership
sudo mkdir /var/log/odoo
sudo chown $OE_USER:root /var/log/odoo

echo -e "\n---- Create a systemd service file for Odoo ----"
# Create a systemd service file for Odoo
sudo bash -c "cat << EOF > /etc/systemd/system/${OE_CONFIG}.service
[Unit]
Description=Odoo
Documentation=http://www.odoo.com
After=network.target

[Service]
Type=simple
User=$OE_USER
ExecStart=$OE_HOME_EXT/venv/bin/python3 $OE_HOME_EXT/odoo-bin -c /etc/${OE_CONFIG}.conf
Restart=always

[Install]
WantedBy=default.target
EOF"

# Set permissions and ownership on the systemd service file
sudo chmod 755 /etc/systemd/system/${OE_CONFIG}.service
sudo chown root: /etc/systemd/system/${OE_CONFIG}.service


# Reload systemd and enable the service
sudo systemctl daemon-reload
sudo systemctl enable ${OE_CONFIG}.service


#--------------------------------------------------
# Install Nginx if needed
#--------------------------------------------------
if [ "$INSTALL_NGINX" = "True" ]; then
  echo -e "\n---- Installing and setting up Nginx ----"
  sudo apt install nginx -y

  cat <<EOF > ~/odoo
server {
  listen 80;

  # Set proper server name after domain set
  server_name $WEBSITE_NAME;

  # Add headers for Odoo proxy mode
  proxy_set_header X-Forwarded-Host \$host;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header X-Real-IP \$remote_addr;
  add_header X-Frame-Options "SAMEORIGIN";
  add_header X-XSS-Protection "1; mode=block";
  proxy_set_header X-Client-IP \$remote_addr;
  proxy_set_header HTTP_X_FORWARDED_HOST \$remote_addr;

  # Odoo log files
  access_log  /var/log/nginx/$OE_USER-access.log;
  error_log   /var/log/nginx/$OE_USER-error.log;

  # Increase proxy buffer size
  proxy_buffers 16 64k;
  proxy_buffer_size 128k;

  proxy_read_timeout 900s;
  proxy_connect_timeout 900s;
  proxy_send_timeout 900s;

  # Force timeouts if the backend dies
  proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;

  types {
    text/less less;
    text/scss scss;
  }

  # Enable data compression
  gzip on;
  gzip_min_length 1100;
  gzip_buffers 4 32k;
  gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
  gzip_vary on;
  client_header_buffer_size 4k;
  large_client_header_buffers 4 64k;
  client_max_body_size 0;

  location / {
    proxy_pass http://127.0.0.1:$OE_PORT;
    # By default, do not forward anything
    proxy_redirect off;
  }

  location /longpolling {
    proxy_pass http://127.0.0.1:$LONGPOLLING_PORT;
  }

  location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
    expires 2d;
    proxy_pass http://127.0.0.1:$OE_PORT;
    add_header Cache-Control "public, no-transform";
  }

  # Cache some static data in memory for 60 minutes
  location ~ /[a-zA-Z0-9_-]*/static/ {
    proxy_cache_valid 200 302 60m;
    proxy_cache_valid 404 1m;
    proxy_buffering on;
    expires 864000;
    proxy_pass http://127.0.0.1:$OE_PORT;
  }
}
EOF
  sudo mv ~/odoo /etc/nginx/sites-available/$WEBSITE_NAME
  sudo ln -s /etc/nginx/sites-available/$WEBSITE_NAME /etc/nginx/sites-enabled/$WEBSITE_NAME
  sudo rm /etc/nginx/sites-enabled/default
  sudo service nginx reload
  sudo su root -c "printf 'proxy_mode = True\n' >> /etc/${OE_CONFIG}.conf"
  echo "Done! The Nginx server is up and running. Configuration can be found at /etc/nginx/sites-available/$WEBSITE_NAME"
else
  echo "Nginx isn't installed due to user choice!"
fi


#--------------------------------------------------
# Enable ssl with certbot
#--------------------------------------------------

if [ "$INSTALL_NGINX" = "True" ] && [ "$ENABLE_SSL" = "True" ] && [ "$ADMIN_EMAIL" != "odoo@example.com" ] && [ "$WEBSITE_NAME" != "_" ]; then
  sudo apt-get update -y
  sudo apt install snapd -y
  sudo snap install core
  sudo snap refresh core
  sudo snap install --classic certbot
  sudo apt-get install python3-certbot-nginx -y
  sudo certbot --nginx -d "$WEBSITE_NAME" --noninteractive --agree-tos --email "$ADMIN_EMAIL" --redirect
  sudo service nginx stop
  sudo certbot certonly --standalone -d "www.$WEBSITE_NAME" --noninteractive --agree-tos --email "$ADMIN_EMAIL" --redirect
  sudo service nginx start
  echo "SSL/HTTPS is enabled!"
  # Add cron job for certificate renewal
  (sudo crontab -l 2>/dev/null; echo "15 3 * * * /usr/bin/certbot renew --pre-hook 'systemctl stop nginx' --post-hook 'systemctl start nginx'") | sudo crontab -


#--------------------------------------------------
# Install new Nginx config
#--------------------------------------------------

if [ "$ENABLE_SSL" = "True" ]; then
  echo -e "\n---- Installing new Nginx config ----"
  sudo rm /etc/nginx/sites-available/$WEBSITE_NAME

  cat <<EOF > ~/odoo
#odoo server
upstream odoo {
  server 127.0.0.1:$OE_PORT;
}
upstream odoochat {
  server 127.0.0.1:$LONGPOLLING_PORT;
}
map \$http_upgrade \$connection_upgrade {
  default upgrade;
  ''      close;
}

map \$sent_http_content_type \$content_type_csp {
    default "";
    ~image/ "default-src 'none'";
}

server {
    # the rest of the configuration

    location @odoo {
        # copy-paste the content of the / location block
    }

    # Serve static files right away
    location ~ ^/[^/]+/static/.+$ {
        # root and try_files both depend on your addons paths
        root ...;
        try_files ... @odoo;
        expires 24h;
        add_header Content-Security-Policy \$content_type_csp;
    }
}

# http -> https
server {
  listen 80;
  server_name www.$WEBSITE_NAME $WEBSITE_NAME; 
  rewrite ^(.*) https://\$host$1 permanent;
}

# WWW -> NON WWW
server {
    listen 443 ssl http2;
    server_name www.$WEBSITE_NAME;

     ssl_certificate /etc/letsencrypt/live/www.$WEBSITE_NAME/fullchain.pem;
     ssl_certificate_key /etc/letsencrypt/live/www.$WEBSITE_NAME/privkey.pem;
     ssl_trusted_certificate /etc/letsencrypt/live/www.$WEBSITE_NAME/chain.pem;
     include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
     ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

    return 301 https://$WEBSITE_NAME\$request_uri;
}

server {
  listen 443 ssl http2;
  server_name $WEBSITE_NAME;
  proxy_read_timeout 720s;
  proxy_connect_timeout 720s;
  proxy_send_timeout 720s;


  ssl_certificate /etc/letsencrypt/live/$WEBSITE_NAME/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$WEBSITE_NAME/privkey.pem;
  ssl_trusted_certificate /etc/letsencrypt/live/$WEBSITE_NAME/chain.pem;
  include /etc/letsencrypt/options-ssl-nginx.conf;
  ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

  # log
  access_log /var/log/nginx/$OE_USER.access.log;
  error_log /var/log/nginx/$OE_USER.error.log;

  
  # Redirect websocket requests to odoo gevent port longpolling
  location /websocket {
    proxy_pass http://odoochat;	
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header Host \$host;	
    proxy_set_header X-Forwarded-Host \$http_host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;

    # Enable HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
    proxy_cookie_flags session_id samesite=lax secure;  # requires nginx 1.19.8
  }

  location /longpolling {
     proxy_pass http://odoochat;
     }


  # Redirect requests to odoo backend server
  location / {
    # Add Headers for odoo proxy mode
    proxy_set_header X-Forwarded-Host \$http_host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_redirect off;
    proxy_pass http://odoo;
    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;

    # Enable HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
    proxy_cookie_flags session_id samesite=lax secure;  # requires nginx 1.19.8
	}
	
	location /web/filestore {
		internal;
		alias /opt/odoo18/.local/share/Odoo/filestore;		
  }

  location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
    expires 2d;
    proxy_pass http://odoo;
    add_header Cache-Control "public, no-transform";
  }

    # Cache static files
    location ~ /[a-zA-Z0-9_-]*/static/ {
        proxy_cache_valid 200 302 60m;
        proxy_cache_valid 404 1m;
        proxy_buffering on;
        expires 864000;
        proxy_pass http://odoo;
    }

  # common gzip
  gzip on;
  gzip_min_length 1100;
  gzip_buffers    4   32k;
  gzip_types  text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
  gzip_vary   on;
  client_header_buffer_size 4k;
  large_client_header_buffers 4 64k;
  client_max_body_size 20M;
}
EOF

  sudo mv ~/odoo /etc/nginx/sites-available/$WEBSITE_NAME
  sudo service nginx reload

else
  echo "Nginx isn't installed due to user choice!"
fi

else
  echo "SSL/HTTPS isn't enabled due to user choice or misconfiguration!"
  if [ "$ADMIN_EMAIL" = "odoo@example.com" ]; then
    echo "Certbot does not support registering odoo@example.com. You should use a real email address."
  fi
  if [ "$WEBSITE_NAME" = "_" ]; then
    echo "Website name is set as _. Cannot obtain SSL Certificate for _. You should use a real website address."
  fi
fi


if [ $INSTALL_NGINX = "True" ]; then
  echo "Nginx configuration file: /etc/nginx/sites-available/$WEBSITE_NAME"
fi

# Start the Odoo service
echo -e "\n---- Start the Odoo service ----"
sudo systemctl restart ${OE_CONFIG}.service

sleep 5

# Check the status of the Odoo service
if ! sudo systemctl status ${OE_CONFIG}.service | grep -q "running"; then
    echo "Odoo failed to start. Check the logs for more details."
    exit 1
fi

# Final check for listening port
if ss -tuln | grep -q ":$OE_PORT"; then
  echo "Odoo ${OE_VERSION} installation completed. Access Odoo from your browser at http://${WEBSITE_NAME}:${OE_PORT}"
else
  echo "Odoo failed to start or is not listening on port: $OE_PORT"
  exit 1
fi
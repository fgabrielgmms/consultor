#!/bin/bash
################################################################################
# Script de instalación de Odoo 19 Community en Ubuntu 24.04 LTS
################################################################################

# Variables (cambia según tu caso)
ODOO_USER="odoo19"
ODOO_HOME="/opt/odoo19"
ODOO_CONFIG="/etc/odoo19.conf"
DOMAIN="mibarescool.com"
ADMIN_PASSWD="SARAH.mateo02"

# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Dependencias básicas
sudo apt install -y git python3 python3-pip python3-dev python3-venv \
    build-essential wget curl unzip gcc g++ make \
    libxml2-dev libxslt-dev libpq-dev libjpeg-dev libfreetype6-dev \
    libzip-dev libsasl2-dev libldap2-dev libtiff5-dev zlib1g-dev \
    libopenjp2-7-dev libssl-dev

# Instalar PostgreSQL
sudo apt install -y postgresql
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Crear usuario PostgreSQL
sudo -u postgres createuser --createdb --no-superuser --no-createrole $ODOO_USER || true

# Crear usuario de sistema
sudo adduser --system --home=$ODOO_HOME --group $ODOO_USER || true

# Descargar Odoo 19 Community
sudo -u $ODOO_USER -H git clone -b 19.0 https://github.com/odoo/odoo.git $ODOO_HOME/odoo

# Crear entorno virtual
sudo -u $ODOO_USER -H python3 -m venv $ODOO_HOME/venv
sudo -u $ODOO_USER -H $ODOO_HOME/venv/bin/pip install --upgrade pip wheel setuptools
sudo -u $ODOO_USER -H $ODOO_HOME/venv/bin/pip install -r $ODOO_HOME/odoo/requirements.txt

# Crear carpeta para addons personalizados
sudo -u $ODOO_USER -H mkdir $ODOO_HOME/custom_addons

# Archivo de configuración
sudo tee $ODOO_CONFIG > /dev/null <<EOF
[options]
admin_passwd = $ADMIN_PASSWD
db_host = False
db_port = False
db_user = $ODOO_USER
db_password = False
addons_path = $ODOO_HOME/odoo/addons,$ODOO_HOME/custom_addons
logfile = /var/log/odoo19/odoo.log
EOF

# Crear carpeta de logs
sudo mkdir -p /var/log/odoo19
sudo chown $ODOO_USER:$ODOO_USER /var/log/odoo19

# Crear servicio systemd
sudo tee /etc/systemd/system/odoo19.service > /dev/null <<EOF
[Unit]
Description=Odoo 19
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
User=$ODOO_USER
Group=$ODOO_USER
ExecStart=$ODOO_HOME/venv/bin/python3 $ODOO_HOME/odoo/odoo-bin -c $ODOO_CONFIG
WorkingDirectory=$ODOO_HOME
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

# Activar servicio
sudo systemctl daemon-reload
sudo systemctl enable odoo19
sudo systemctl start odoo19

# Instalar Nginx y Certbot
sudo apt install -y nginx certbot python3-certbot-nginx

# Configurar Nginx reverse proxy
sudo tee /etc/nginx/sites-available/odoo19 > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:8069;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/odoo19 /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# Certificado SSL con Let's Encrypt
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

echo "✅ Instalación completada. Accede a: https://$DOMAIN"

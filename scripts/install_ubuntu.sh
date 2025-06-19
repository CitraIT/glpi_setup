#!/bin/bash

echo "#########################################################"
echo " Script para Instalacao do GLPI no Ubuntu 22
echo "#########################################################"

# 1. Atualiza a lista de pacotes disponíveis no repositório.
sudo apt update  


# 2. Instala softwares necessários
sudo apt install -y \
	nginx \
	mariadb-server \
	mariadb-client \
	php-fpm \
	php-dom \
	php-fileinfo   \
	php-json \
	php-simplexml \
	php-xmlreader \
	php-xmlwriter \
	php-curl \
	php-gd \
	php-intl \
	php-mysqli   \
	php-bz2  \
	php-zip \
	php-exif \
	php-ldap  \
	php-opcache \
	php-mbstring

 # 3. Criar banco de dados do glpi
sudo mysql -e "CREATE DATABASE glpi"
sudo mysql -e "GRANT ALL PRIVILEGES ON glpi.* TO 'glpi'@'localhost' IDENTIFIED BY '1cd73cddc8dad1fef981391f'"
sudo mysql -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi'@'localhost'"
sudo mysql -e "FLUSH PRIVILEGES"

# 4. Carregar timezones no MySQL
mysql_tzinfo_to_sql /usr/share/zoneinfo | sudo mysql -u root mysql

# 5. Habilita session.cookie_httponly
sudo sed -i 's/^session.cookie_httponly =/session.cookie_httponly = on/' /etc/php/8.1/fpm/php.ini
sudo sed -i 's/^;date.timezone =/date.timezone = America\/Sao_Paulo/' /etc/php/8.1/fpm/php.ini

# 6. Criar o arquivo de configuração do servidor web (nginx) com o seguinte comando:
cat << "EOF" > /tmp/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;
events {
        worker_connections 768;
}
http {
        sendfile on;
        tcp_nopush on;
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;
        gzip on;
        gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

        server {
            listen 80;
            server_name _;
            root /var/www/glpi/public;
            index index.php;
            location / {
                try_files $uri /index.php$is_args$args;
            }
            location ~ ^/index\.php$ {
                fastcgi_split_path_info ^(.+\.php)(/.+)$;
                fastcgi_pass unix:/run/php/php8.1-fpm.sock;
                fastcgi_index index.php;
                include /etc/nginx/fastcgi.conf;
            }
        }
}
EOF
sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf

# 7. Reinicia os serviços necessários
sudo systemctl restart nginx php8.1-fpm mysql

# 8. Download do glpi
wget https://github.com/glpi-project/glpi/releases/download/10.0.15/glpi-10.0.15.tgz


# 9. Descompactar a pasta do GLPI
tar -zxf glpi-*

# 10. Mover a pasta do GLPI para a pasta htdocs
sudo mv glpi /var/www/glpi

# 11. Configura a permissão na pasta www/glpi
sudo chown -R www-data:www-data /var/www/glpi/


# 12. Finalizar setup do glpi pela linha de comando
sudo php /var/www/glpi/bin/console db:install \
	--default-language=pt_BR \
	--db-host=localhost \
	--db-port=3306 \
	--db-name=glpi \
	--db-user=glpi \
	--db-password=1cd73cddc8dad1fef981391f \
	--no-interaction


# 13. Ajustes de Segurança

# 13.1. Remover o arquivo de instalação
sudo rm /var/www/glpi/install/install.php


# 13.2. Mover pastas do GLPI de forma segura
sudo mv /var/www/glpi/files /var/lib/glpi
sudo mv /var/www/glpi/config /etc/glpi
sudo mkdir /var/log/glpi
sudo chown -R www-data:www-data /var/log/glpi

# 13.3. Criar o arquivo downstream.php com o seguinte conteúdo:
cat << "EOF" > /tmp/downstream.php
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
   require_once GLPI_CONFIG_DIR . '/local_define.php';
}
EOF
sudo mv /tmp/downstream.php /var/www/glpi/inc/downstream.php

# 13.4. Criar o Arquivo local_define.php com o seguinte conteúdo:
cat << "EOF" > /tmp/local_define.php
<?php
define('GLPI_VAR_DIR', '/var/lib/glpi');
define('GLPI_DOC_DIR', GLPI_VAR_DIR);
define('GLPI_CRON_DIR', GLPI_VAR_DIR . '/_cron');
define('GLPI_DUMP_DIR', GLPI_VAR_DIR . '/_dumps');
define('GLPI_GRAPH_DIR', GLPI_VAR_DIR . '/_graphs');
define('GLPI_LOCK_DIR', GLPI_VAR_DIR . '/_lock');
define('GLPI_PICTURE_DIR', GLPI_VAR_DIR . '/_pictures');
define('GLPI_PLUGIN_DOC_DIR', GLPI_VAR_DIR . '/_plugins');
define('GLPI_RSS_DIR', GLPI_VAR_DIR . '/_rss');
define('GLPI_SESSION_DIR', GLPI_VAR_DIR . '/_sessions');
define('GLPI_TMP_DIR', GLPI_VAR_DIR . '/_tmp');
define('GLPI_UPLOAD_DIR', GLPI_VAR_DIR . '/_uploads');
define('GLPI_CACHE_DIR', GLPI_VAR_DIR . '/_cache');
define('GLPI_LOG_DIR', '/var/log/glpi');
EOF
sudo mv /tmp/local_define.php /etc/glpi/local_define.php

# 14. Definir as permissões corretas dos arquivos 
sudo chown root:root /var/www/html/glpi/ -R
sudo chown www-data:www-data /etc/glpi -R
sudo chown www-data:www-data /var/lib/glpi -R
sudo chown www-data:www-data /var/log/glpi -R
sudo chown www-data:www-data /var/www/html/glpi/marketplace -Rf
sudo find /var/www/html/glpi/ -type f -exec chmod 0644 {} \;
sudo find /var/www/html/glpi/ -type d -exec chmod 0755 {} \;
sudo find /etc/glpi -type f -exec chmod 0644 {} \;
sudo find /etc/glpi -type d -exec chmod 0755 {} \;
sudo find /var/lib/glpi -type f -exec chmod 0644 {} \;
sudo find /var/lib/glpi -type d -exec chmod 0755 {} \;
sudo find /var/log/glpi -type f -exec chmod 0644 {} \;
sudo find /var/log/glpi -type d -exec chmod 0755 {} \;


# 14. FINALIZOU
echo "########  ###################"
echo " INSTALACAO FINALIZADA COM SUCESSO."
echo "Acesse o GLPI via navegador para realizar as configuracoes iniciais."


#4. Primeiros Passos
#4.1. Acessar o GLPI via web browser
#4.2. Criar um novo usuário com perfil super-admin
#4.3. Remover os usuários glpi, normal, post-only, tech.
#4.3.1. Enviar os usuários para a lixeira
#4.3.2. Remover permanentemente
#4.3.4. Configurar a url de acesso ao sistema em: Configurar -> Geral -> Configuração Geral -> URL da aplicação.

#5. Referências
#https://faq.teclib.com/03_knowledgebase/procedures/install_glpi/

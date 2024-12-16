# OWNCLOUD 3 CAPAS EN DOCKER

## Índice
1. [Introducción](#introducción)
2. [Docker Compose](#docker-compose)
3. [Contenedor Balanceador](#contenedor-balanceador)
4. [Contenedor PHP](#contenedor-php)
5. [Contenedor Web](#contenedor-web)
6. [Contenedor MariaDB](#contenedor-mariadb)

## Introducción
En esta práctica vamos a desplegar Owncloud en una infraestructura en alta disponibilidad de 3 capas basada en una pila LEMP en docker.

- Capa 1: Un contenedor con balanceador de carga Nginx.
- Capa 2: Dos contenedores con un servidor web nginx cada una y un contenedor Motor PHP-FPM.
- Capa 3: Base de datos MariaDB.

## Docker Compose
Para ejecutar varios contenedores en un fichero, he utilizado el docker-compose.
El fichero docker-compse.yml tiene una configuración básica , en la que le indicamos el nombre de contenedor, dockerfile que van a utilizar para crear la imagen, los puertos, la red y la ip que le queremos asignar . Además , le podemos asignar la opción de que dependa de otro contenedor, como en este caso hay algunos que dependen de otros para que funcionen correctamente.
````
version: '3.1'
services:
  balan:
    container_name: servidor_balanceador
    build: 
        context: ./servidor_balanceador/
        dockerfile: ./dockerfile_balan 
    restart: always
    ports:
      - 80:80
    networks:
      red_web:
        ipv4_address: 192.168.10.10
    hostname: servidor_balanceador
    depends_on: 
      - web1
      - web2
  
  web1:
    container_name: servidor_web1
    build: 
        context: ./servidor_web/
        dockerfile: ./dockerfile_web 
    restart: always
    networks:
      red_web:
        ipv4_address: 192.168.10.11
      red_interna:
        ipv4_address: 192.168.20.11
    hostname: servidor_web1
    depends_on: 
      - basededatos
      - nfsphp
    volumes:
      - web_data:/var/www/html  

  web2:
    container_name: servidor_web2
    build: 
        context: ./servidor_web/
        dockerfile: ./dockerfile_web 
    restart: always
    networks:
      red_web:
        ipv4_address: 192.168.10.12
      red_interna:
        ipv4_address: 192.168.20.12
    hostname: servidor_web2
    depends_on: 
      - basededatos
      - nfsphp
    volumes:
      - web_data:/var/www/html   

  nfsphp:
    container_name: servidor_php
    build: 
        context: ./servidor_php/
        dockerfile: ./dockerfile_nfsphp
    restart: always
    networks:
      red_interna:
        ipv4_address: 192.168.20.13
    hostname: servidor_php
    depends_on: 
      - basededatos
    volumes:
      - web_data:/var/www/html  

  basededatos:
    container_name: basededatos
    build: 
        context: ./basedatos/
        dockerfile: ./dockerfile_bd
    restart: always
    networks:
      red_interna:
        ipv4_address: 192.168.20.14
    hostname: basededatos
    volumes:
      - db_data:/var/lib/mysql

networks:
    red_web:
        ipam:
            config:
              - subnet: 192.168.10.0/24
    red_interna:
        ipam:
            config:
              - subnet: 192.168.20.0/24
volumes:
  web_data:  
  db_data:


````
## Contenedor Balanceador
Para el balanceador he utilizado el siguiente dockerfile y el fichero de configuración para que nginx pueda balancear a los 2 servidores web.
### DockerFile
````
FROM nginx:latest
# Copiar el archivo de configuración de Nginx 
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
````
### Fichero de configuración
````
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    upstream backend {
        server 192.168.10.11:80;
        server 192.168.10.12:80;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
````

## Contenedor PHP
En este contenedor tenemos que instalar php7.4 , que es compatible con Owncloud. Añadir el fichero de configuración para que se puedan conectar los servidores web.
### Dockerfile
````
FROM debian:latest

RUN apt-get update && apt-get install -y \
    lsb-release \
    apt-transport-https \
    ca-certificates \
    wget && \
    wget -O /etc/apt/trusted.gpg.d/sury-keyring.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/sury.list && \
    apt-get update

RUN apt-get install -y \
    php7.4-fpm \
    php7.4-mysql \
    php7.4-xml \
    php7.4-mbstring \
    php7.4-gd \
    php7.4-curl \
    php7.4-zip \
    php7.4-bz2 \
    php7.4-intl \
    nginx \
    && rm -rf /var/lib/apt/lists/*

# Configuración de PHP-FPM
COPY ./www.conf /etc/php/7.4/fpm/pool.d/www.conf

# Exponer el puerto usado por PHP-FPM
EXPOSE 9000

CMD php-fpm7.4 -D && nginx -g "daemon off;"

RUN chown -R www-data:www-data /var/www/html/

RUN chmod -R 770 /var/www/html/
````
### Fichero de configuración
Editamos el listen para que los servidores se puedan conectar mediante el puerto 9000.
````
[www]
listen = 192.168.20.13:9000
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
user = www-data
group = www-data
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
````
## Contenedor Web
Es parecido al del balanceador solo que en este el fichero de configuración es otra. Además dar permisos a la carpeta del owncloud.

### Docker File
````
FROM nginx:latest

# Copiar el archivo de configuración de Nginx 
COPY nginxweb.conf /etc/nginx/conf.d/default.conf

# Exponer el puerto 80 para Nginx
EXPOSE 80

# Iniciar Nginx y PHP-FPM
CMD ["nginx", "-g", "daemon off;"]

ADD ./owncloud /var/www/html
WORKDIR /var/www/html

RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html
````
### Fichero de configuración
````
server {
    listen 80;
    server_name localhost;
    root /var/www/html;

    index index.php;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        fastcgi_pass 192.168.20.13:9000;  
        fastcgi_index index.php;
        fastcgi_param REQUESTED_METHOD $request_method;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;

    }

    location ~ /\.ht {
        deny all;
    }
}
````
## Contenedor MariaDB
En este contenedor irá la base de datos del owncloud,este tendrá 2 archivos más para la configuración, el primero es el fichero de configuración . En donde cambiaremos el bind-address y el segundo es el script para crear los usuarios para que puedan accederse los contendores de la capa 2.

### Docker File
````
FROM mariadb
# Configuración inicial
ENV MYSQL_ROOT_PASSWORD=root_password
ENV MYSQL_DATABASE=owncloud
ENV MYSQL_USER=owncloud_user
ENV MYSQL_PASSWORD=owncloud_password

COPY ./mysqld.cnf /etc/mysql/conf.d/

# Script con la creacion de usuarios.
COPY script.sql /docker-entrypoint-initdb.d/

EXPOSE 3306
````

### Fichero de configuración
````
[mysqld]
user = mysql
pid-file = /var/run/mysqld/mysqld.pid
socket = /var/run/mysqld/mysqld.sock
port = 3306
datadir = /var/lib/mysql

# Permitir conexiones desde otros contenedores.
bind-address = 192.168.20.14

skip-networking = 0
max_connections = 100
connect_timeout = 10
wait_timeout = 600
max_allowed_packet = 16M
log_error = /var/log/mysql/error.log
general_log = 1
general_log_file = /var/log/mysql/general.log
````
### Script
````
CREATE USER 'owncloud_user'@'192.168.20.%' IDENTIFIED BY 'owncloud_password';
GRANT ALL PRIVILEGES ON owncloud.* TO 'owncloud_user'@'192.168.20.%';
FLUSH PRIVILEGES;
````

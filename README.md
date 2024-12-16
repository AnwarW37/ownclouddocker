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
- DockerFile
````
FROM nginx:latest
# Copiar el archivo de configuración de Nginx 
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
````
- Fichero de configuración
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
En este contenedor 

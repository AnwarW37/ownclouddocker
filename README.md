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
El fichero docker-compse.yml es el siguiente:
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

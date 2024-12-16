-- Crear el usuario
CREATE USER 'owncloud_user'@'192.168.20.13' IDENTIFIED BY 'owncloud_password';

-- Otorgar privilegios sobre la base de datos "owncloud"
GRANT ALL PRIVILEGES ON owncloud.* TO 'owncloud_user'@'192.168.20.13';

-- Recargar los privilegios
FLUSH PRIVILEGES;

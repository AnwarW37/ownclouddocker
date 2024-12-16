CREATE USER 'owncloud_user'@'192.168.20.%' IDENTIFIED BY 'owncloud_password';
GRANT ALL PRIVILEGES ON owncloud.* TO 'owncloud_user'@'192.168.20.%';
FLUSH PRIVILEGES;

CREATE DATABASE ;
CREATE USER ''@'localhost' IDENTIFIED BY '';
CREATE USER ''@'%' IDENTIFIED BY '';
GRANT ALL PRIVILEGES ON *.* TO ''@'localhost';
GRANT ALL PRIVILEGES ON *.* TO ''@'%';
FLUSH PRIVILEGES;
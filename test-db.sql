-- Base de datos aislada para las pruebas automatizadas (npm test).
-- Las pruebas cargan schema.sql y seed.sql aquí antes de ejecutarse.
CREATE DATABASE IF NOT EXISTS casino_test CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
GRANT ALL PRIVILEGES ON casino_test.* TO 'casino'@'%';
FLUSH PRIVILEGES;

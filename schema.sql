-- =============================================================
-- Casino Online - Equipo 08
-- Esquema de la base de datos (MySQL 8, 8 tablas en 3FN)
-- Sin sentencia USE: se ejecuta sobre la base de datos activa
-- (casino en desarrollo, casino_test en pruebas).
-- =============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS bitacora;
DROP TABLE IF EXISTS movimientos;
DROP TABLE IF EXISTS apuestas;
DROP TABLE IF EXISTS tipos_movimiento;
DROP TABLE IF EXISTS billeteras;
DROP TABLE IF EXISTS juegos;
DROP TABLE IF EXISTS usuarios;
DROP TABLE IF EXISTS roles;
SET FOREIGN_KEY_CHECKS = 1;

-- 1. Roles del sistema (catálogo)
CREATE TABLE roles (
  id      TINYINT UNSIGNED PRIMARY KEY,
  nombre  VARCHAR(20) NOT NULL,
  CONSTRAINT uq_roles_nombre UNIQUE (nombre)
) ENGINE=InnoDB;

-- 2. Usuarios (jugadores y administradores)
CREATE TABLE usuarios (
  id                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  rol_id            TINYINT UNSIGNED NOT NULL,
  nombre            VARCHAR(100) NOT NULL,
  correo            VARCHAR(120) NOT NULL,
  password_hash     CHAR(60) NOT NULL,
  fecha_nacimiento  DATE NOT NULL,
  activo            BOOLEAN NOT NULL DEFAULT TRUE,
  creado_en         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_usuarios_correo UNIQUE (correo),
  CONSTRAINT fk_usuarios_rol FOREIGN KEY (rol_id) REFERENCES roles(id),
  INDEX ix_usuarios_nombre (nombre),
  INDEX ix_usuarios_rol_activo (rol_id, activo)
) ENGINE=InnoDB;

-- 3. Billetera de créditos virtuales (una por jugador)
CREATE TABLE billeteras (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  usuario_id      INT UNSIGNED NOT NULL,
  saldo           DECIMAL(12,2) NOT NULL DEFAULT 0,
  actualizado_en  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT uq_billeteras_usuario UNIQUE (usuario_id),
  CONSTRAINT fk_billeteras_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
  -- RN-03: el saldo nunca puede ser negativo
  CONSTRAINT ck_billeteras_saldo CHECK (saldo >= 0)
) ENGINE=InnoDB;

-- 4. Juegos del casino
CREATE TABLE juegos (
  id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  slug         VARCHAR(30) NOT NULL,
  -- tipo = lógica que usa el servidor; permite variantes (p. ej. "Blackjack VIP" con otros límites)
  tipo         ENUM('blackjack','poker','ruleta','billar') NOT NULL,
  nombre       VARCHAR(60) NOT NULL,
  descripcion  VARCHAR(255) NOT NULL DEFAULT '',
  apuesta_min  DECIMAL(10,2) NOT NULL,
  apuesta_max  DECIMAL(10,2) NOT NULL,
  activo       BOOLEAN NOT NULL DEFAULT TRUE,
  creado_en    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_juegos_slug UNIQUE (slug),
  CONSTRAINT uq_juegos_nombre UNIQUE (nombre),
  CONSTRAINT ck_juegos_limites CHECK (apuesta_min > 0 AND apuesta_max >= apuesta_min)
) ENGINE=InnoDB;

-- 5. Tipos de movimiento de la billetera (catálogo)
CREATE TABLE tipos_movimiento (
  id      TINYINT UNSIGNED PRIMARY KEY,
  clave   VARCHAR(20) NOT NULL,
  nombre  VARCHAR(40) NOT NULL,
  CONSTRAINT uq_tipos_movimiento_clave UNIQUE (clave)
) ENGINE=InnoDB;

-- 6. Apuestas / partidas
CREATE TABLE apuestas (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  usuario_id     INT UNSIGNED NOT NULL,
  juego_id       INT UNSIGNED NOT NULL,
  monto          DECIMAL(10,2) NOT NULL,
  multiplicador  DECIMAL(6,2) NULL,
  pago           DECIMAL(12,2) NOT NULL DEFAULT 0,
  estado         ENUM('en_curso','ganada','perdida','empate') NOT NULL DEFAULT 'en_curso',
  estado_juego   JSON NULL,
  creado_en      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resuelto_en    DATETIME NULL,
  CONSTRAINT fk_apuestas_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
  CONSTRAINT fk_apuestas_juego FOREIGN KEY (juego_id) REFERENCES juegos(id),
  CONSTRAINT ck_apuestas_monto CHECK (monto > 0),
  CONSTRAINT ck_apuestas_pago CHECK (pago >= 0),
  INDEX ix_apuestas_usuario_fecha (usuario_id, creado_en),
  INDEX ix_apuestas_juego_fecha (juego_id, creado_en),
  INDEX ix_apuestas_estado (estado)
) ENGINE=InnoDB;

-- 7. Movimientos de la billetera (historial de saldo)
CREATE TABLE movimientos (
  id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  billetera_id     INT UNSIGNED NOT NULL,
  tipo_id          TINYINT UNSIGNED NOT NULL,
  monto            DECIMAL(12,2) NOT NULL,          -- positivo = abono, negativo = cargo
  saldo_resultante DECIMAL(12,2) NOT NULL,
  apuesta_id       INT UNSIGNED NULL,
  descripcion      VARCHAR(255) NOT NULL DEFAULT '',
  creado_por       INT UNSIGNED NULL,               -- administrador que hizo un ajuste
  creado_en        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_movimientos_billetera FOREIGN KEY (billetera_id) REFERENCES billeteras(id) ON DELETE CASCADE,
  CONSTRAINT fk_movimientos_tipo FOREIGN KEY (tipo_id) REFERENCES tipos_movimiento(id),
  CONSTRAINT fk_movimientos_apuesta FOREIGN KEY (apuesta_id) REFERENCES apuestas(id),
  CONSTRAINT fk_movimientos_admin FOREIGN KEY (creado_por) REFERENCES usuarios(id),
  CONSTRAINT ck_movimientos_saldo CHECK (saldo_resultante >= 0),
  CONSTRAINT ck_movimientos_monto CHECK (monto <> 0),
  INDEX ix_movimientos_billetera_fecha (billetera_id, creado_en)
) ENGINE=InnoDB;

-- 8. Bitácora de operaciones
CREATE TABLE bitacora (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  usuario_id  INT UNSIGNED NULL,
  accion      VARCHAR(40) NOT NULL,
  entidad     VARCHAR(30) NOT NULL,
  entidad_id  INT UNSIGNED NULL,
  detalle     JSON NULL,
  ip          VARCHAR(45) NULL,
  creado_en   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_bitacora_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL,
  INDEX ix_bitacora_fecha (creado_en),
  INDEX ix_bitacora_accion (accion)
) ENGINE=InnoDB;

-- Catálogos fijos
INSERT INTO roles (id, nombre) VALUES (1, 'admin'), (2, 'jugador');
INSERT INTO tipos_movimiento (id, clave, nombre) VALUES
  (1, 'recarga', 'Recarga de créditos'),
  (2, 'apuesta', 'Cargo por apuesta'),
  (3, 'premio',  'Pago de premio'),
  (4, 'ajuste',  'Ajuste del administrador'),
  (5, 'bono',    'Bono de bienvenida');

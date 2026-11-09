-- =============================================================
-- FUENTES PLATA - Switch entre tabla y volumen
-- Parametro: project.fuente_plata ('tabla' o 'volumen')
-- =============================================================

-- Vista temporal para plata_carga
-- Opcion 1: Leer de tabla ${project.catalog}.${project.schema_plata}.plata_carga
-- Opcion 2: Leer de volumen /Volumes/workspace/alunizaje/datos_oficiales/exportaciones/carga
CREATE TEMPORARY VIEW source_plata_carga AS
SELECT 
  NISE, MEDIDOR, FECHA_LECTURA_REAL, SGDA_ORIGINAL, SGDA_NORMALIZADO,
  OPERACION, UNIDAD, VALOR_LECTURA, CONSTANTE, TIPO_MEDIDOR,
  INTERVALO, ENERGIA, DEMANDA, LOCALIZACION_FISICA
FROM read_files('/Volumes/workspace/alunizaje/datos_oficiales/exportaciones/carga')
WHERE '${project.fuente_plata}' = 'volumen'
UNION ALL
SELECT 
  NISE, MEDIDOR, FECHA_LECTURA_REAL, SGDA_ORIGINAL, SGDA_NORMALIZADO,
  OPERACION, UNIDAD, VALOR_LECTURA, CONSTANTE, TIPO_MEDIDOR,
  INTERVALO, ENERGIA, DEMANDA, LOCALIZACION_FISICA
FROM ${project.catalog}.${project.schema_plata}.plata_carga
WHERE '${project.fuente_plata}' = 'tabla';

-- Vista temporal para plata_consumo
-- Opcion 1: Leer de tabla ${project.catalog}.${project.schema_plata}.plata_consumo
-- Opcion 2: Leer de volumen /Volumes/workspace/alunizaje/datos_oficiales/exportaciones/consumo
CREATE TEMPORARY VIEW source_plata_consumo AS
SELECT 
  NISE, MEDIDOR, FECHA_LECTURA_REAL, SGDA_NORMALIZADO, SGDA_ORIGINAL,
  OPERACION, UNIDAD, VALOR_LECTURA, CONSTANTE, ENERGIA,
  LOCALIZACION_FISICA
FROM read_files('/Volumes/workspace/alunizaje/datos_oficiales/exportaciones/consumo')
WHERE '${project.fuente_plata}' = 'volumen'
UNION ALL
SELECT 
  NISE, MEDIDOR, FECHA_LECTURA_REAL, SGDA_NORMALIZADO, SGDA_ORIGINAL,
  OPERACION, UNIDAD, VALOR_LECTURA, CONSTANTE, ENERGIA,
  LOCALIZACION_FISICA
FROM ${project.catalog}.${project.schema_plata}.plata_consumo
WHERE '${project.fuente_plata}' = 'tabla';

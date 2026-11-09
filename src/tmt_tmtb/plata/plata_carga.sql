-- =============================================================
-- PLATA CARGA - incremental / portable
-- Las cuatro funciones de negocio originales se expresan aqui con SQL nativo
-- para eliminar dependencias persistentes del catalogo.
-- =============================================================

CREATE TEMPORARY VIEW plata_carga_transformada AS
WITH base AS (
  SELECT
    COALESCE(CAST(c.LOCALIZACION AS STRING), CAST(c.MEDIDOR AS STRING)) AS NISE,
    CAST(c.MEDIDOR AS STRING) AS MEDIDOR,
    CAST(c.FECHA_LECTURA_REAL AS TIMESTAMP) AS FECHA_LECTURA_REAL,
    c.SGDA AS SGDA_ORIGINAL,
    CASE
      WHEN c.SGDA IS NULL THEN 'Consumo'
      WHEN c.SGDA IN ('Bidireccional', 'Bidirrecional') THEN 'Bidireccional'
      WHEN c.SGDA IN ('Generacion', 'GENERACION') THEN 'Generacion'
      WHEN c.SGDA IN ('totalizacion', 'tota suma', 'TOTA SUMA') THEN 'Totalizacion'
      ELSE 'Proyecto'
    END AS SGDA_NORMALIZADO,
    c.OPERACION AS OPERACION_ORIGINAL,
    c.UNIDAD,
    CAST(c.VALOR_LECTURA AS DOUBLE) AS VALOR_LECTURA,
    COALESCE(CAST(c.CONSTANTE AS DOUBLE), 1.0) AS CONSTANTE,
    c.TIPO_MEDIDOR,
    CAST(c.INTERVALO AS INT) AS INTERVALO,
    c.LOCALIZACION_REAL AS LOCALIZACION_FISICA
  FROM STREAM(carga) c
  INNER JOIN (
    SELECT CAST(nis AS STRING) AS nis_str FROM tmt
    UNION
    SELECT CAST(nis AS STRING) AS nis_str FROM tmtb
  ) ref
    ON CAST(c.LOCALIZACION AS STRING) = ref.nis_str
  WHERE c.FECHA_LECTURA_REAL IS NOT NULL
    AND c.OPERACION != 'Sum'
),
transformada AS (
  SELECT
    *,
    CASE
      WHEN SGDA_NORMALIZADO IN ('Consumo', 'Bidireccional') AND OPERACION_ORIGINAL = 'Delivered' AND UNIDAD = 'kWh' THEN 'Consumo_Activo_kWh'
      WHEN SGDA_NORMALIZADO IN ('Consumo', 'Bidireccional') AND OPERACION_ORIGINAL = 'Delivered' AND UNIDAD = 'kVARh' THEN 'Consumo_Reactivo_kVARh'
      WHEN SGDA_NORMALIZADO IN ('Consumo', 'Bidireccional') AND OPERACION_ORIGINAL = 'Received' AND UNIDAD = 'kWh' THEN 'Inyeccion_Activo_kWh'
      WHEN SGDA_NORMALIZADO IN ('Consumo', 'Bidireccional') AND OPERACION_ORIGINAL = 'Received' AND UNIDAD = 'kVARh' THEN 'Inyeccion_Reactivo_kVARh'
      WHEN SGDA_NORMALIZADO = 'Generacion' AND OPERACION_ORIGINAL = 'Delivered' AND UNIDAD = 'kWh' THEN 'Generacion_SGDA_Activo_kWh'
      WHEN SGDA_NORMALIZADO = 'Generacion' AND OPERACION_ORIGINAL = 'Delivered' AND UNIDAD = 'kVARh' THEN 'Generacion_SGDA_Reactivo_kVARh'
      WHEN SGDA_NORMALIZADO = 'Generacion' AND OPERACION_ORIGINAL = 'Received' AND UNIDAD = 'kWh' THEN 'Autoconsumo_SGDA_Activo_kWh'
      WHEN SGDA_NORMALIZADO = 'Totalizacion' AND OPERACION_ORIGINAL = 'Delivered' AND UNIDAD = 'kWh' THEN 'Totalizacion_Activo_kWh'
      WHEN SGDA_NORMALIZADO = 'Totalizacion' AND OPERACION_ORIGINAL = 'Delivered' AND UNIDAD = 'kVARh' THEN 'Totalizacion_Reactivo_kVARh'
      WHEN SGDA_NORMALIZADO = 'Proyecto' AND OPERACION_ORIGINAL = 'Delivered' AND UNIDAD = 'kWh' THEN 'Proyecto_Activo_kWh'
      WHEN SGDA_NORMALIZADO = 'Proyecto' AND OPERACION_ORIGINAL = 'Delivered' AND UNIDAD = 'kVARh' THEN 'Proyecto_Reactivo_kVARh'
      ELSE 'Otros'
    END AS OPERACION
  FROM base
)
SELECT
  NISE,
  MEDIDOR,
  FECHA_LECTURA_REAL,
  SGDA_ORIGINAL,
  SGDA_NORMALIZADO,
  OPERACION,
  UNIDAD,
  VALOR_LECTURA,
  CONSTANTE,
  TIPO_MEDIDOR,
  INTERVALO,
  ROUND(VALOR_LECTURA * CONSTANTE, 3) AS ENERGIA,
  CASE
    WHEN INTERVALO IS NULL OR INTERVALO = 0 THEN NULL
    ELSE ROUND(VALOR_LECTURA * CONSTANTE * (60.0 / INTERVALO), 3)
  END AS DEMANDA,
  LOCALIZACION_FISICA
FROM transformada;

CREATE OR REFRESH STREAMING TABLE ${project.catalog}.${project.schema_plata}.plata_carga;

CREATE FLOW plata_carga_flow AS AUTO CDC INTO ${project.catalog}.${project.schema_plata}.plata_carga
FROM STREAM(plata_carga_transformada)
KEYS (NISE, FECHA_LECTURA_REAL, OPERACION)
SEQUENCE BY FECHA_LECTURA_REAL
STORED AS SCD TYPE 1;

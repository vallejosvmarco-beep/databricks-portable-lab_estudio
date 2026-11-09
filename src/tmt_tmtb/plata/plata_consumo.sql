-- =============================================================
-- PLATA CONSUMO - incremental / portable
-- =============================================================

CREATE TEMPORARY VIEW plata_consumo_transformada AS
SELECT
  CAST(c.LOCALIZACION AS STRING) AS NISE,
  CAST(c.MEDIDOR AS STRING) AS MEDIDOR,
  CAST(c.FECHA_LECTURA_REAL AS TIMESTAMP) AS FECHA_LECTURA_REAL,
  CASE
    WHEN UPPER(c.SGDA) IN ('BIDIRECCIONAL', 'BIDIRRECIONAL') THEN 'Bidireccional'
    WHEN UPPER(c.SGDA) = 'GENERACION' THEN 'Generacion'
    WHEN UPPER(c.SGDA) IN ('TOTALIZACION', 'TOTA SUMA') THEN 'Totalizacion'
    WHEN c.SGDA IS NOT NULL AND c.SGDA != '' THEN 'Proyecto'
    ELSE 'Consumo'
  END AS SGDA_NORMALIZADO,
  c.SGDA AS SGDA_ORIGINAL,
  CASE
    WHEN c.TIPO_CONSUMO = 'ENE Delivered' AND c.UNIDAD = 'kWh' THEN
      CASE
        WHEN UPPER(c.SGDA) IN ('BIDIRECCIONAL', 'BIDIRRECIONAL') THEN 'Consumo_Activo_kWh'
        WHEN UPPER(c.SGDA) = 'GENERACION' THEN 'Generacion_SGDA_Activo_kWh'
        WHEN UPPER(c.SGDA) IN ('TOTALIZACION', 'TOTA SUMA') THEN 'Totalizacion_Activo_kWh'
        WHEN c.SGDA IS NOT NULL AND c.SGDA != '' THEN 'Proyecto_Activo_kWh'
        ELSE 'Consumo_Activo_kWh'
      END
    WHEN c.TIPO_CONSUMO = 'ENE Received' AND c.UNIDAD = 'kWh' THEN 'Inyeccion_Activo_kWh'
    WHEN c.TIPO_CONSUMO = 'ENE Sum' AND c.UNIDAD = 'kWh' THEN 'Totalizacion_Activo_kWh'
    WHEN c.TIPO_CONSUMO = 'FPO' AND c.UNIDAD = 'kVAR' THEN 'Consumo_Reactivo_kVARh'
    WHEN c.TIPO_CONSUMO = 'MDE Delivered' AND c.UNIDAD = 'kW' THEN 'Demanda_Delivered_kW'
    WHEN c.TIPO_CONSUMO = 'MDE Received' AND c.UNIDAD = 'kW' THEN 'Demanda_Received_kW'
    WHEN c.TIPO_CONSUMO = 'MDE Sum' AND c.UNIDAD = 'kW' THEN 'Demanda_Sum_kW'
    WHEN c.UNIDAD = 'Voltage' THEN
      CASE
        WHEN c.CONTADOR = 'A' THEN 'Tension_Fase_A'
        WHEN c.CONTADOR = 'B' THEN 'Tension_Fase_B'
        WHEN c.CONTADOR = 'C' THEN 'Tension_Fase_C'
        ELSE 'Tension_Otros'
      END
    ELSE 'Otros'
  END AS OPERACION,
  CASE WHEN c.UNIDAD = 'kVAR' THEN 'kVARh' ELSE c.UNIDAD END AS UNIDAD,
  CAST(c.VALOR_LECTURA AS DOUBLE) AS VALOR_LECTURA,
  CASE
    WHEN COALESCE(CAST(c.MULTIPLICADOR AS DOUBLE), 0.0) = 0.0 THEN 1.0
    ELSE CAST(c.MULTIPLICADOR AS DOUBLE)
  END AS CONSTANTE,
  CAST(c.VALOR_LECTURA AS DOUBLE) *
    CASE
      WHEN COALESCE(CAST(c.MULTIPLICADOR AS DOUBLE), 0.0) = 0.0 THEN 1.0
      ELSE CAST(c.MULTIPLICADOR AS DOUBLE)
    END AS ENERGIA,
  c.LOCALIZACION_REAL AS LOCALIZACION_FISICA
FROM STREAM(consumo) c
INNER JOIN (
  SELECT CAST(nis AS STRING) AS nis_str FROM tmt
  UNION
  SELECT CAST(nis AS STRING) AS nis_str FROM tmtb
) ref
  ON CAST(c.LOCALIZACION AS STRING) = ref.nis_str
WHERE c.UNIDAD IN ('kWh', 'kVAR', 'kW', 'Voltage')
  AND c.VALOR_LECTURA IS NOT NULL
  AND (
    c.CONTADOR IN ('Total')
    OR (c.UNIDAD = 'Voltage' AND c.CONTADOR IN ('A', 'B', 'C'))
  );

CREATE OR REFRESH STREAMING TABLE ${project.catalog}.${project.schema_plata}.plata_consumo;

CREATE FLOW plata_consumo_flow AS AUTO CDC INTO ${project.catalog}.${project.schema_plata}.plata_consumo
FROM STREAM(plata_consumo_transformada)
KEYS (NISE, FECHA_LECTURA_REAL, OPERACION)
SEQUENCE BY FECHA_LECTURA_REAL
STORED AS SCD TYPE 1;

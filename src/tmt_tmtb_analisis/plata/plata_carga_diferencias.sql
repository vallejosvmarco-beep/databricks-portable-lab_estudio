-- =============================================================
-- PLATA ANALISIS - diferencias carga vs contador
-- Batch/no streaming. Resultado limitado al periodo solicitado.
-- Conserva una lectura de consumo previa al periodo para calcular correctamente
-- el primer LAG del mes y usa el intervalo completo para la metrica de diferencia.
-- =============================================================

CREATE OR REFRESH MATERIALIZED VIEW ${project.catalog}.${project.schema_analisis}.plata_carga_diferencias
AS
WITH consumo_previo AS (
  SELECT NISE, OPERACION, FECHA_LECTURA_REAL, VALOR_LECTURA
  FROM (
    SELECT
      CAST(NISE AS STRING) AS NISE,
      CAST(OPERACION AS STRING) AS OPERACION,
      CAST(FECHA_LECTURA_REAL AS TIMESTAMP) AS FECHA_LECTURA_REAL,
      CAST(VALOR_LECTURA AS DOUBLE) AS VALOR_LECTURA,
      ROW_NUMBER() OVER (
        PARTITION BY CAST(NISE AS STRING), CAST(OPERACION AS STRING)
        ORDER BY CAST(FECHA_LECTURA_REAL AS TIMESTAMP) DESC
      ) AS rn
    FROM ${project.catalog}.${project.schema_plata}.plata_consumo
    WHERE NISE IS NOT NULL
      AND OPERACION IS NOT NULL
      AND FECHA_LECTURA_REAL IS NOT NULL
      AND VALOR_LECTURA IS NOT NULL
      AND CAST(FECHA_LECTURA_REAL AS TIMESTAMP) < CAST('${project.periodo_inicio}' AS TIMESTAMP)
  )
  WHERE rn = 1
),
consumo_periodo AS (
  SELECT
    CAST(NISE AS STRING) AS NISE,
    CAST(OPERACION AS STRING) AS OPERACION,
    CAST(FECHA_LECTURA_REAL AS TIMESTAMP) AS FECHA_LECTURA_REAL,
    CAST(VALOR_LECTURA AS DOUBLE) AS VALOR_LECTURA
  FROM ${project.catalog}.${project.schema_plata}.plata_consumo
  WHERE NISE IS NOT NULL
    AND OPERACION IS NOT NULL
    AND FECHA_LECTURA_REAL IS NOT NULL
    AND VALOR_LECTURA IS NOT NULL
    AND CAST(FECHA_LECTURA_REAL AS TIMESTAMP) >= CAST('${project.periodo_inicio}' AS TIMESTAMP)
    AND CAST(FECHA_LECTURA_REAL AS TIMESTAMP) < CAST(DATE_ADD('${project.periodo_fin}', 1) AS TIMESTAMP)
),
consumo_contexto AS (
  SELECT * FROM consumo_previo
  UNION ALL
  SELECT * FROM consumo_periodo
),
consumo_lag AS (
  SELECT
    NISE,
    OPERACION,
    LAG(FECHA_LECTURA_REAL) OVER (
      PARTITION BY NISE, OPERACION ORDER BY FECHA_LECTURA_REAL
    ) AS INI_ORIG,
    FECHA_LECTURA_REAL AS FIN_ORIG,
    CAST(
      VALOR_LECTURA - COALESCE(
        LAG(VALOR_LECTURA) OVER (
          PARTITION BY NISE, OPERACION ORDER BY FECHA_LECTURA_REAL
        ),
        0.0
      ) AS DOUBLE
    ) AS ENERGIA_CONTADOR
  FROM consumo_contexto
),
intervalos AS (
  SELECT
    NISE,
    OPERACION,
    INI_ORIG,
    FIN_ORIG,
    ENERGIA_CONTADOR,
    to_timestamp(CEIL(unix_timestamp(INI_ORIG) / 900.0) * 900) AS INICIO_C,
    to_timestamp(FLOOR(unix_timestamp(FIN_ORIG) / 900.0) * 900) AS FIN_C
  FROM consumo_lag
  WHERE INI_ORIG IS NOT NULL
    AND FIN_ORIG >= CAST('${project.periodo_inicio}' AS TIMESTAMP)
    AND FIN_ORIG < CAST(DATE_ADD('${project.periodo_fin}', 1) AS TIMESTAMP)
),
metricas AS (
  SELECT
    i.NISE,
    i.OPERACION,
    i.INI_ORIG,
    i.FIN_ORIG,
    i.INICIO_C,
    i.FIN_C,
    i.ENERGIA_CONTADOR,
    COUNT(*) AS LECTURAS_PRESENTES,
    SUM(CAST(l.ENERGIA AS DOUBLE)) AS ENERGIA_LECTURAS,
    CAST(
      CASE
        WHEN unix_timestamp(i.FIN_C) >= unix_timestamp(i.INICIO_C)
          THEN ((unix_timestamp(i.FIN_C) - unix_timestamp(i.INICIO_C)) / 900) + 1
        ELSE 0
      END AS BIGINT
    ) AS LECTURAS_ESPERADAS
  FROM intervalos i
  INNER JOIN ${project.catalog}.${project.schema_plata}.plata_carga l
    ON CAST(l.NISE AS STRING) = i.NISE
   AND CAST(l.OPERACION AS STRING) = i.OPERACION
   AND CAST(l.FECHA_LECTURA_REAL AS TIMESTAMP) >= i.INICIO_C
   AND CAST(l.FECHA_LECTURA_REAL AS TIMESTAMP) <= i.FIN_C
  WHERE i.INICIO_C IS NOT NULL
    AND i.FIN_C IS NOT NULL
    AND i.INICIO_C <= i.FIN_C
    AND i.ENERGIA_CONTADOR IS NOT NULL
  GROUP BY
    i.NISE, i.OPERACION, i.INI_ORIG, i.FIN_ORIG,
    i.INICIO_C, i.FIN_C, i.ENERGIA_CONTADOR
),
metricas_finales AS (
  SELECT
    *,
    CASE
      WHEN LECTURAS_ESPERADAS > 0
        THEN ((LECTURAS_ESPERADAS - LECTURAS_PRESENTES) / CAST(LECTURAS_ESPERADAS AS DOUBLE)) * 100.0
      ELSE 100.0
    END AS PORCENTAJE_FALTANTES,
    CASE
      WHEN COALESCE(ENERGIA_LECTURAS, 0.0) = 0.0
       AND COALESCE(ENERGIA_CONTADOR, 0.0) = 0.0 THEN 0.0
      ELSE (
        (COALESCE(ENERGIA_LECTURAS, 0.0) - COALESCE(ENERGIA_CONTADOR, 0.0)) /
        NULLIF(
          (COALESCE(ENERGIA_LECTURAS, 0.0) + COALESCE(ENERGIA_CONTADOR, 0.0)) / 2.0,
          0.0
        )
      ) * 100.0
    END AS PORCENTAJE_DIFERENCIA,
    concat(
      date_format(INI_ORIG, 'yyyy-MM-dd HH:mm:ss'), '_',
      NISE, '_', OPERACION, '_',
      date_format(FIN_ORIG, 'yyyy-MM-dd HH:mm:ss')
    ) AS LAPSO
  FROM metricas
  WHERE LECTURAS_PRESENTES > 0
)
SELECT
  CAST(l.NISE AS STRING) AS NISE,
  CAST(l.OPERACION AS STRING) AS OPERACION,
  CAST(l.FECHA_LECTURA_REAL AS TIMESTAMP) AS FECHA_LECTURA,
  CAST(l.FECHA_LECTURA_REAL AS DATE) AS FECHA,
  CAST(l.ENERGIA AS DOUBLE) AS ENERGIA,
  CAST(l.DEMANDA AS DOUBLE) AS DEMANDA,
  m.LAPSO,
  m.PORCENTAJE_DIFERENCIA,
  m.INI_ORIG AS INICIO_LAPSO,
  m.FIN_ORIG AS FIN_LAPSO,
  m.ENERGIA_CONTADOR,
  m.ENERGIA_LECTURAS,
  m.LECTURAS_ESPERADAS,
  m.LECTURAS_PRESENTES,
  m.PORCENTAJE_FALTANTES
FROM ${project.catalog}.${project.schema_plata}.plata_carga l
INNER JOIN metricas_finales m
  ON CAST(l.NISE AS STRING) = m.NISE
 AND CAST(l.OPERACION AS STRING) = m.OPERACION
 AND CAST(l.FECHA_LECTURA_REAL AS TIMESTAMP) >= m.INICIO_C
 AND CAST(l.FECHA_LECTURA_REAL AS TIMESTAMP) <= m.FIN_C
WHERE CAST(l.FECHA_LECTURA_REAL AS TIMESTAMP) >= CAST('${project.periodo_inicio}' AS TIMESTAMP)
  AND CAST(l.FECHA_LECTURA_REAL AS TIMESTAMP) < CAST(DATE_ADD('${project.periodo_fin}', 1) AS TIMESTAMP);

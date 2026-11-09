-- =============================================================
-- ORO: ANÁLISIS DE MARGEN DE COMERCIALIZACIÓN
-- Calcula márgenes de comercialización por cliente y plan tarifario
-- comparando ingresos por venta vs costos de compra de energía
-- Basado en plata_950_carga (datos de calidad validados)
-- =============================================================

CREATE OR REFRESH MATERIALIZED VIEW ${project.catalog}.${project.schema_oro}.oro_margen_comercializacion
COMMENT 'Análisis de margen de comercialización por cliente y plan tarifario (TMT/TMTB) - basado en plata_950'
AS
WITH carga_con_plan AS (
  -- Usar plata_950 que ya incluye el PLAN y datos de calidad
  SELECT 
    NISE,
    FECHA_LECTURA,
    ENERGIA,
    DEMANDA,
    PLAN
  FROM ${project.catalog}.${project.schema_analisis}.plata_950_carga
  WHERE OPERACION = 'Consumo_Activo_kWh'
    AND PLAN IS NOT NULL
),
consumo_por_periodo AS (
  SELECT 
    NISE,
    PLAN,
    CASE 
      WHEN HOUR(FECHA_LECTURA) >= 10 AND HOUR(FECHA_LECTURA) < 12 THEN 'Punta'
      WHEN HOUR(FECHA_LECTURA) = 12 AND MINUTE(FECHA_LECTURA) < 30 THEN 'Punta'
      WHEN HOUR(FECHA_LECTURA) >= 17 AND HOUR(FECHA_LECTURA) < 20 THEN 'Punta'
      WHEN HOUR(FECHA_LECTURA) = 20 AND MINUTE(FECHA_LECTURA) < 30 THEN 'Punta'
      WHEN HOUR(FECHA_LECTURA) >= 22 OR HOUR(FECHA_LECTURA) < 6 THEN 'Noche'
      ELSE 'Valle'
    END as periodo,
    SUM(ENERGIA) as total_energia_kwh,
    MAX(DEMANDA) as demanda_maxima_kw
  FROM carga_con_plan
  GROUP BY NISE, PLAN, 
    CASE 
      WHEN HOUR(FECHA_LECTURA) >= 10 AND HOUR(FECHA_LECTURA) < 12 THEN 'Punta'
      WHEN HOUR(FECHA_LECTURA) = 12 AND MINUTE(FECHA_LECTURA) < 30 THEN 'Punta'
      WHEN HOUR(FECHA_LECTURA) >= 17 AND HOUR(FECHA_LECTURA) < 20 THEN 'Punta'
      WHEN HOUR(FECHA_LECTURA) = 20 AND MINUTE(FECHA_LECTURA) < 30 THEN 'Punta'
      WHEN HOUR(FECHA_LECTURA) >= 22 OR HOUR(FECHA_LECTURA) < 6 THEN 'Noche'
      ELSE 'Valle'
    END
),
calculo_margen AS (
  SELECT 
    NISE,
    PLAN,
    periodo,
    total_energia_kwh,
    demanda_maxima_kw,
    -- Ingresos por venta según tarifas TMT/TMTB
    CASE 
      WHEN PLAN = 'TMT' AND periodo = 'Punta' THEN total_energia_kwh * 50.14
      WHEN PLAN = 'TMT' AND periodo = 'Valle' THEN total_energia_kwh * 25.06
      WHEN PLAN = 'TMT' AND periodo = 'Noche' THEN total_energia_kwh * 18.05
      WHEN PLAN = 'TMTB' AND periodo = 'Punta' THEN total_energia_kwh * 95.12
      WHEN PLAN = 'TMTB' AND periodo = 'Valle' THEN total_energia_kwh * 32.67
      WHEN PLAN = 'TMTB' AND periodo = 'Noche' THEN total_energia_kwh * 20.99
    END as ingreso_energia,
    CASE 
      WHEN PLAN = 'TMT' AND periodo = 'Punta' THEN demanda_maxima_kw * 8791.48
      WHEN PLAN = 'TMT' AND periodo = 'Valle' THEN demanda_maxima_kw * 6255.43
      WHEN PLAN = 'TMT' AND periodo = 'Noche' THEN demanda_maxima_kw * 3971.05
      WHEN PLAN = 'TMTB' AND periodo = 'Punta' THEN demanda_maxima_kw * 2793.58
      WHEN PLAN = 'TMTB' AND periodo = 'Valle' THEN demanda_maxima_kw * 1950.19
      WHEN PLAN = 'TMTB' AND periodo = 'Noche' THEN demanda_maxima_kw * 1249.71
    END as ingreso_potencia,
    -- Costos de compra (iguales para ambos planes)
    CASE 
      WHEN periodo = 'Punta' THEN total_energia_kwh * 36.85
      WHEN periodo = 'Valle' THEN total_energia_kwh * 30.2
      WHEN periodo = 'Noche' THEN total_energia_kwh * 25.63
    END as costo_energia,
    CASE 
      WHEN periodo = 'Punta' THEN demanda_maxima_kw * 1954.51
      WHEN periodo = 'Valle' THEN demanda_maxima_kw * 1954.51
      WHEN periodo = 'Noche' THEN 0
    END as costo_potencia
  FROM consumo_por_periodo
),
margen_por_cliente AS (
  SELECT 
    NISE,
    PLAN,
    SUM(ingreso_energia + ingreso_potencia) as total_ingreso,
    SUM(costo_energia + costo_potencia) as total_costo,
    SUM((ingreso_energia + ingreso_potencia) - (costo_energia + costo_potencia)) as margen_total,
    SUM(total_energia_kwh) as energia_total_kwh
  FROM calculo_margen
  GROUP BY NISE, PLAN
)
SELECT 
  NISE,
  PLAN,
  ROUND(energia_total_kwh, 2) as Energia_Total_kWh,
  ROUND(total_ingreso, 2) as Total_Ingreso,
  ROUND(total_costo, 2) as Total_Costo,
  ROUND(margen_total, 2) as Margen_Total,
  ROUND((margen_total / total_ingreso) * 100, 2) as Margen_Porcentaje
FROM margen_por_cliente
WHERE total_ingreso > 0
ORDER BY margen_total DESC;
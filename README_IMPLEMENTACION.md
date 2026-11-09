# TMT/TMTB portable - primera implementacion

> ⚠️ **¿Problemas con "Catalog does not exist"?** Lee la [Guía de Portabilidad](PORTABILIDAD.md) para configurar el proyecto en tu entorno.

## Inicio Rápido

### Para Nuevos Entornos

1. **Configura tu catálogo:**
   ```bash
   cp databricks.local.yml.example databricks.local.yml
   # Edita databricks.local.yml con tu catálogo
   ```

2. **Ejecuta bootstrap:**
   ```bash
   databricks bundle run bootstrap --target free_dev
   ```

3. **Deploy y ejecuta:**
   ```bash
   databricks bundle deploy --target free_dev
   databricks bundle run tmt_tmtb_workflow --target free_dev
   ```

**Ver más:** [PORTABILIDAD.md](PORTABILIDAD.md) para instrucciones detalladas.

---

## Donde vive cada cosa

- Git/Git Folder: YAML, Python y SQL de la logica.
- Unity Catalog Volumes: Parquet, Excel y demas archivos de datos.
- Unity Catalog tables: salidas bronce, plata, plata_analisis y oro.

## Arbol del repositorio

```text
databricks-portable-lab/
├── databricks.yml
├── resources/
│   ├── infrastructure.yml
│   ├── pipelines/
│   │   ├── tmt_tmtb.pipeline.yml
│   │   └── tmt_tmtb_analisis.pipeline.yml
│   └── jobs/
│       └── tmt_tmtb_workflow.job.yml
└── src/
    ├── tmt_tmtb/
    │   ├── bronce/
    │   │   ├── tmt.py
    │   │   ├── tmtb.py
    │   │   ├── carga.py
    │   │   ├── consumo.py
    │   │   ├── carga_tmt.py
    │   │   ├── carga_tmtb.py
    │   │   ├── consumo_tmt.py
    │   │   └── consumo_tmtb.py
    │   └── plata/
    │       ├── plata_carga.sql
    │       └── plata_consumo.sql
    └── tmt_tmtb_analisis/
        ├── plata/
        │   ├── plata_carga_diferencias.sql
        │   ├── plata_carga_completitud.sql
        │   └── plata_950_carga.sql
        └── oro/
            └── boxes.sql
```

## Rutas de datos iniciales

Los schemas y volumes se crean con el bundle al implementar.

### Datos oficiales

```text
/Volumes/workspace/alunizaje/datos_oficiales/tmt/periodo=2026/mes=06/TMT Junio 2026.xlsx
/Volumes/workspace/alunizaje/datos_oficiales/tmtb/periodo=2026/mes=06/TMTb Junio 2026.xlsx
```

Puede haber otro nombre de archivo `.xlsx`; el pipeline lee el directorio del mes.

### Datos crudos

```text
/Volumes/workspace/alunizaje/datos_crudos/carga/periodo=2026/mes=06/region=r1/*.parquet
/Volumes/workspace/alunizaje/datos_crudos/carga/periodo=2026/mes=06/region=r2/*.parquet
/Volumes/workspace/alunizaje/datos_crudos/carga/periodo=2026/mes=06/region=r3/*.parquet

/Volumes/workspace/alunizaje/datos_crudos/consumo/periodo=2026/mes=06/region=r1/*.parquet
/Volumes/workspace/alunizaje/datos_crudos/consumo/periodo=2026/mes=06/region=r2/*.parquet
/Volumes/workspace/alunizaje/datos_crudos/consumo/periodo=2026/mes=06/region=r3/*.parquet
```

Se pueden agregar mas regiones; Auto Loader recorre el arbol completo.

## Orden inicial

1. Copiar estos archivos dentro del Git Folder.
2. Implementar `free_dev`. Esto crea schemas, volumes, pipelines y el workflow.
3. Cargar los dos Excel oficiales en `datos_oficiales`.
4. Cargar Parquet en `datos_crudos`.
5. Ejecutar `TMT_TMTB` para poblar bronce/plata incremental.
6. Ejecutar `TMT_TMTB_Analisis` para recalcular junio de 2026.
7. Validar `oro.boxes_*`.
8. Commit + Push a GitHub.

## Periodo Oro inicial

```text
2026-06-01 a 2026-06-30
```

Se controla desde `databricks.yml` con `periodo_inicio` y `periodo_fin`.

## Cambio intencional respecto al ambiente original

El pipeline de analisis usa Materialized Views y no Streaming Tables. Es coherente con su naturaleza batch/no streaming y evita conservar resultados de periodos que no correspondan al rango configurado.

Las cuatro funciones SQL originales de plata se incorporaron directamente con expresiones SQL nativas dentro de `plata_carga.sql`. Esto elimina una dependencia externa y mantiene el bundle autocontenido.

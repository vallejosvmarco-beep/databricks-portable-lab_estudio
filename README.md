# Databricks Portable Lab

## 🚀 Proyecto Portable entre Workspaces

Este bundle de Databricks está diseñado para ser completamente portable entre diferentes cuentas y workspaces. Incluye pipelines, workflows y toda la infraestructura necesaria para procesamiento de datos TMT/TMTB.

## ⚡ Quick Start

### Primera Vez en un Nuevo Workspace

```bash
# 1. Lista catalogos disponibles
databricks catalogs list

# 2. Configura tu entorno local
cp databricks.local.yml.example databricks.local.yml
vim databricks.local.yml  # Cambia el catalog por uno existente

# 3. Deploy
databricks bundle deploy --target free_dev
```

### Deploy Rápido (Sin Configuración Local)

```bash
databricks bundle deploy --var catalog=main --target free_dev
```

## ⚠️ Problema Común: Dashboard usa catálogo incorrecto

Si al abrir un dashboard obtienes un error como:

```
[TABLE_OR_VIEW_NOT_FOUND] `mi_catalogo_test`.`oro`.`boxes_anual` cannot be found
```

Pero tu configuración usa un catálogo diferente (ej: `workspace`), los dashboards necesitan ser reprocesados:

```bash
# Solución rápida
python scripts/process_dashboards.py --catalog workspace --force
```

**Causa:** Los dashboards fueron procesados anteriormente con un catálogo diferente y ese cambio se guardó en los archivos `.lvdash.json`.

**Solución completa:** Ver [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## 📚 Documentación

* **[README-PORTABILIDAD.md](README-PORTABILIDAD.md)** - Guía completa de portabilidad y migración
* **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Solución de problemas comunes
* **databricks.local.yml.example** - Template de configuración local
* **databricks.yml** - Configuración base del bundle

## 🛠️ Estructura del Proyecto

```
databricks-portable-lab/
├── databricks.yml                    # Configuración del bundle
├── databricks.local.yml.example      # Template para configuración local
├── README-PORTABILIDAD.md            # Guía de portabilidad
├── scripts/
│   └── bootstrap.py                  # Inicialización automática
├── resources/
│   ├── pipelines/
│   │   ├── tmt_tmtb.pipeline.yml
│   │   ├── tmt_tmtb_analisis.pipeline.yml
│   │   └── tmt_tmtb_margenes_comercializacion.pipeline.yml
│   └── jobs/
│       └── tmt_tmtb_workflow.job.yml
└── src/
    ├── tmt_tmtb/                      # Código de pipelines principales
    ├── tmt_tmtb_analisis/             # Código de análisis
    └── ...
```

## 🔄 Arquitectura de Datos

### Capas del Lakehouse

* **Alunizaje** (`alunizaje`) - Zona de aterrizaje de datos crudos
* **Bronce** (`bronce`) - Datos sin procesar, tal cual llegan
* **Plata** (`plata`) - Datos limpiados y estandarizados
* **Análisis** (`plata_analisis`) - Métricas y análisis de calidad
* **Oro** (`oro`) - Datos listos para consumo final

### Pipelines

1. **TMT_TMTB** - Pipeline principal de ingestión (bronce → plata)
2. **TMT_TMTB_Analisis** - Análisis de calidad de datos
3. **TMT_TMTB_Margenes_Comercializacion** - Cálculos de márgenes (oro)

### Workflow

**TMT_TMTB_Workflow** orquesta los 3 pipelines en secuencia con dependencias:
```
actualizar_incremental (Pipeline 1)
    ↓
recalcular_analisis (Pipeline 2)
    ↓
margenes_comercializacion (Pipeline 3)
```

## ⚙️ Configuración

### Variables Principales

Todas las variables están definidas en `databricks.yml` y pueden sobreescribirse en `databricks.local.yml`:

* `catalog` - Catálogo de Unity Catalog (REQUERIDO configurar)
* `schema_alunizaje` - Schema de aterrizaje
* `schema_bronce` - Schema bronce
* `schema_plata` - Schema plata
* `schema_analisis` - Schema de análisis
* `schema_oro` - Schema oro
* `volume_crudos` - Volumen de datos crudos
* `volume_oficiales` - Volumen de datos oficiales
* `periodo_inicio` / `periodo_fin` - Periodo de procesamiento

### Personalización por Entorno

Crea `databricks.local.yml` (ver ejemplo) para:
* Usar diferentes catalogos por entorno
* Ajustar periodos de datos
* Configurar warehouses específicos

## 🚨 Problemas Comunes

### "Catalog 'workspace' does not exist"

➡️ **Solución**: Lee [README-PORTABILIDAD.md](README-PORTABILIDAD.md) sección "Solución de Problemas"

### El Workflow Falla pero los Pipelines Funcionan

**Síntoma**: El pipeline de márgenes funciona directo, pero el workflow falla.

**Causa**: El workflow tiene configuración desactualizada (le falta la tarea de márgenes).

➡️ **Solución**: Redeploy el bundle para actualizar el workflow. Ver [TROUBLESHOOTING.md](TROUBLESHOOTING.md) para instrucción detallada.

### Bootstrap Falla al Crear Catálogo

➡️ **Solución**: Usa un catálogo existente en lugar de crear uno nuevo, o pide permisos al admin.

## 🔒 Seguridad

* El archivo `databricks.local.yml` está en `.gitignore`
* Nunca commitees configuraciones específicas de tu entorno
* Usa variables de entorno en CI/CD para valores sensibles

## 🤝 Contribuir

Al contribuir:
* No modifiques el valor default de `catalog` en `databricks.yml`
* Actualiza `databricks.local.yml.example` si agregas nuevas variables
* Documenta cambios de arquitectura en este README
* Mantén la portabilidad del bundle

## 💬 Soporte

Consulta la documentación:
1. [README-PORTABILIDAD.md](README-PORTABILIDAD.md) - Problemas de portabilidad
2. [databricks.local.yml.example](databricks.local.yml.example) - Configuración
3. Comentarios en `databricks.yml` - Detalles de variables
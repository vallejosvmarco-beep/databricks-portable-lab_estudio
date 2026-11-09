# Guía de Portabilidad

Este proyecto está diseñado para ser completamente portable entre diferentes cuentas y workspaces de Databricks. Esta guía explica cómo configurarlo en un nuevo entorno.

## Problema Común: "Catalog does not exist"

Si ves este error al hacer `databricks bundle deploy`:

```
Error: cannot create resources.pipelines.xxx: Catalog 'workspace' does not exist.
```

Significa que el catálogo configurado no existe en tu entorno.

## Solución Rápida

### Opción 1: Usar un Catálogo Existente (Recomendado)

1. **Lista los catálogos disponibles:**

   ```bash
   databricks catalogs list
   ```

2. **Usa uno de los catálogos existentes:**

   ```bash
   databricks bundle deploy --var catalog=<nombre_catalogo> --target free_dev
   ```

   Por ejemplo:
   ```bash
   databricks bundle deploy --var catalog=main --target free_dev
   ```

### Opción 2: Crear el Catálogo Automáticamente

1. **Ejecuta el script de bootstrap primero:**

   ```bash
   databricks bundle run bootstrap --target free_dev
   ```

   El script intentará:
   - Verificar si el catálogo existe
   - Crear el catálogo si no existe (requiere permisos)
   - Crear todos los schemas necesarios
   - Crear todos los volumes necesarios

2. **Si el script falla por permisos:**
   - Solicita a un administrador que cree el catálogo
   - O usa la Opción 1 con un catálogo existente

### Opción 3: Configuración Permanente (databricks.local.yml)

Para no tener que especificar el catálogo cada vez:

1. **Crea el archivo `databricks.local.yml`** en la raíz del proyecto:

   ```bash
   cp databricks.local.yml.example databricks.local.yml
   ```

2. **Edita el archivo** con tus valores:

   ```yaml
   variables:
     catalog:
       default: mi_catalogo  # Cambia esto por tu catálogo
   ```

3. **Agrega a .gitignore** (si no está ya):

   ```bash
   echo "databricks.local.yml" >> .gitignore
   ```

   > ⚠️ **IMPORTANTE:** `databricks.local.yml` NO debe versionarse en Git porque contiene configuración específica de tu entorno.

## Flujo Completo para Nuevo Entorno

### 1. Clonar el Repositorio

```bash
git clone <repo-url>
cd databricks-portable-lab
```

### 2. Configurar Variables Locales

```bash
cp databricks.local.yml.example databricks.local.yml
```

Edita `databricks.local.yml` con tus valores:

```yaml
variables:
  catalog:
    default: tu_catalogo  # main, workspace, o el que uses
  
  # Opcional: sobrescribe otras variables si es necesario
  # schema_alunizaje:
  #   default: landing
  # schema_bronce:
  #   default: bronze
```

### 3. Ejecutar Bootstrap

```bash
databricks bundle run bootstrap --target free_dev
```

Esto crea:
- Catálogo (si no existe y tienes permisos)
- Schemas: `alunizaje`, `bronce`, `plata`, `plata_analisis`, `oro`
- Volumes: `datos_crudos`, `datos_oficiales`

### 4. Deploy del Bundle

```bash
databricks bundle deploy --target free_dev
```

### 5. Ejecutar el Workflow

```bash
databricks bundle run tmt_tmtb_workflow --target free_dev
```

## Variables Configurables

Todas estas variables pueden sobrescribirse vía:
- CLI: `--var nombre=valor`
- `databricks.local.yml`: para configuración permanente local
- Targets en `databricks.yml`: para diferentes entornos (dev/prod)

### Variables de Infraestructura

| Variable | Default | Descripción |
|----------|---------|-------------|
| `catalog` | `workspace` | Catálogo de Unity Catalog |
| `schema_alunizaje` | `alunizaje` | Schema para datos crudos (landing) |
| `schema_bronce` | `bronce` | Schema para datos en bronce |
| `schema_plata` | `plata` | Schema para datos transformados |
| `schema_analisis` | `plata_analisis` | Schema para análisis |
| `schema_oro` | `oro` | Schema para datos agregados |
| `volume_crudos` | `datos_crudos` | Volume para archivos crudos |
| `volume_oficiales` | `datos_oficiales` | Volume para archivos oficiales |

### Variables de Negocio

| Variable | Default | Descripción |
|----------|---------|-------------|
| `oficial_periodo` | `2026` | Año del periodo oficial |
| `oficial_mes` | `06` | Mes del periodo oficial |
| `periodo_inicio` | `2026-06-01` | Fecha inicio para análisis |
| `periodo_fin` | `2026-06-30` | Fecha fin para análisis |

### Variables de Infraestructura (Runtime)

| Variable | Default | Descripción |
|----------|---------|-------------|
| `warehouse_id` | `lookup: Serverless Starter Warehouse` | SQL Warehouse para dashboards |

## Estructura del Proyecto

```
databricks-portable-lab/
├── databricks.yml              # Configuración principal del bundle
├── databricks.local.yml        # (local, no versionado) Config específica del entorno
├── databricks.local.yml.example # Plantilla para databricks.local.yml
├── scripts/
│   └── bootstrap.py           # Script de inicialización
├── resources/
│   ├── pipelines/             # Definiciones de pipelines
│   ├── jobs/                  # Definiciones de workflows
│   └── dashboards/            # Definiciones de dashboards
└── src/
    ├── tmt_tmtb/              # Código de la pipeline principal
    └── tmt_tmtb_analisis/     # Código de la pipeline de análisis
```

## Diferencias entre Entornos

### Lo que VARÍA entre entornos:

- **Catálogo:** Puede llamarse diferente (`main`, `workspace`, `dev`, etc.)
- **Warehouse ID:** Diferentes warehouses disponibles
- **Nombres de recursos:** Los nombres se pueden prefijear automáticamente en modo dev

### Lo que NO VARÍA (es portable):

- **Código SQL/Python:** Usa variables `${project.catalog}`, etc.
- **Estructura de schemas:** Siempre la misma jerarquía
- **Lógica de negocio:** Completamente independiente del entorno
- **Configuración de pipelines:** Todas las rutas son relativas

## Troubleshooting

### Error: "Catalog does not exist"

**Causa:** El catálogo configurado no existe.

**Solución:**
1. Lista catálogos: `databricks catalogs list`
2. Usa uno existente: `--var catalog=<nombre>`
3. O ejecuta bootstrap: `databricks bundle run bootstrap`

### Error: "Cannot create catalog" durante bootstrap

**Causa:** No tienes permisos para crear catálogos.

**Solución:**
1. Usa un catálogo existente (Opción 1)
2. Solicita al admin que cree el catálogo
3. Solicita permisos de "CREATE CATALOG" en el metastore

### Error: "Schema already exists"

**Causa:** El schema ya existe (esto es OK).

**Solución:** Ninguna. El bootstrap detecta y conserva schemas existentes.

### Error: Pipelines fallan en runtime

**Causa:** Variables de configuración incorrectas.

**Solución:**
1. Verifica que todas las variables apunten a recursos existentes
2. Revisa los logs del pipeline
3. Asegúrate de haber ejecutado bootstrap primero

### Error: "Resource not found" al ejecutar workflow

**Causa:** No se hizo deploy del bundle.

**Solución:**
```bash
databricks bundle deploy --target free_dev
```

## Buenas Prácticas

### ✅ Hacer

1. **Usar `databricks.local.yml`** para configuración local
2. **Ejecutar bootstrap** antes del primer deploy
3. **Validar antes de deployar:**
   ```bash
   databricks bundle validate --target free_dev
   ```
4. **Usar variables** para todo lo que puede variar entre entornos
5. **Documentar cambios** en variables o estructura

### ❌ No Hacer

1. **NO versionar `databricks.local.yml`** en Git
2. **NO hardcodear** nombres de catálogos/schemas en el código
3. **NO asumir** que un catálogo existe sin verificar
4. **NO usar rutas absolutas** del workspace
5. **NO deployar sin validar** primero

## Referencias

- [Declarative Automation Bundles Documentation](https://docs.databricks.com/dev-tools/bundles/)
- [Unity Catalog Documentation](https://docs.databricks.com/data-governance/unity-catalog/)
- [Lakeflow Pipelines Documentation](https://docs.databricks.com/lakeflow/pipelines/)
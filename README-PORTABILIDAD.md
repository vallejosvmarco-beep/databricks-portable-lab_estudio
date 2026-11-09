# Guía de Portabilidad - Databricks Portable Lab

## 📋 Índice
1. [Descripción General](#descripción-general)
2. [Configuración Inicial](#configuración-inicial)
3. [Portabilidad de Dashboards](#portabilidad-de-dashboards)
4. [Variables de Configuración](#variables-de-configuración)
5. [Despliegue en Nuevo Workspace](#despliegue-en-nuevo-workspace)
6. [Troubleshooting](#troubleshooting)

---

## Descripción General

Este proyecto está diseñado para ser **completamente portable** entre diferentes:
- Workspaces de Databricks
- Catálogos de Unity Catalog
- Entornos (desarrollo, staging, producción)

La portabilidad se logra mediante:
1. **Variables de configuración** en `databricks.yml` y `databricks.local.yml`
2. **Script de bootstrap** que valida y crea recursos automáticamente
3. **Procesamiento automático de dashboards** para actualizar referencias al catálogo

---

## Configuración Inicial

### 1. Crear Archivo de Configuración Local

```bash
cd databricks-portable-lab
cp databricks.local.yml.example databricks.local.yml
```

### 2. Editar `databricks.local.yml`

```yaml
targets:
  free_dev:
    variables:
      catalog: tu_catalogo_aqui  # ← CAMBIAR ESTO
```

**⚠️ IMPORTANTE:** 
- El archivo `databricks.local.yml` está en `.gitignore` y **NO se versionará**
- Cada usuario/entorno debe tener su propia configuración
- Este archivo contiene configuración específica del workspace

---

## Portabilidad de Dashboards

### Problema Original

Los dashboards Lakeview (`.lvdash.json`) contienen queries SQL con referencias hardcodeadas al catálogo:

```sql
SELECT * FROM workspace.oro.boxes_anual
```

Esto causa errores al desplegar en un workspace con un catálogo diferente.

### Solución Automática

El proyecto incluye **procesamiento automático** de dashboards que:

1. **Durante el bootstrap:** Los dashboards se procesan automáticamente
2. **Reemplaza referencias:** `workspace.` → `{tu_catalogo}.`
3. **Preserva backups:** Los originales se guardan en `.templates/`

#### Proceso Automático

Cada vez que ejecutas `databricks bundle deploy`, el script `bootstrap.py` automáticamente:

```python
# En scripts/bootstrap.py
def process_dashboards():
    """Procesa dashboards para reemplazar catálogo hardcodeado."""
    # 1. Busca archivos .lvdash.json
    # 2. Reemplaza 'workspace.' con '{CATALOG}.'
    # 3. Guarda los archivos procesados
```

#### Proceso Manual (Opcional)

Si necesitas procesar dashboards manualmente:

```bash
# Procesar con un catálogo específico
python scripts/process_dashboards.py --catalog mi_catalogo

# Forzar reprocesamiento
python scripts/process_dashboards.py --catalog mi_catalogo --force

# Ver ayuda
python scripts/process_dashboards.py --help
```

### Archivos Afectados

Los siguientes dashboards se procesan automáticamente:

```
src/dashboards/
├── tmt_tmtb.lvdash.json                        # 8 referencias procesadas
├── margenes_comercializacion.lvdash.json       # 1 referencia procesada
└── .templates/                                 # Backups automáticos
    ├── tmt_tmtb.lvdash.json.original
    └── margenes_comercializacion.lvdash.json.original
```

**Nota:** Los archivos en `.templates/` están en `.gitignore` y no se versionan.

### Ejemplo de Transformación

**Antes del procesamiento:**
```sql
SELECT NISE, PLAN, OPERACION
FROM workspace.oro.boxes_anual
WHERE ANIO = 2026
```

**Después del procesamiento (con `catalog: analytics`):**
```sql
SELECT NISE, PLAN, OPERACION
FROM analytics.oro.boxes_anual
WHERE ANIO = 2026
```

---

## Variables de Configuración

### Variables Principales

Definidas en `databricks.yml`:

```yaml
variables:
  # PORTABILIDAD: Catálogo de Unity Catalog
  catalog:
    description: "Catálogo de Unity Catalog"
    default: workspace
    
  # Warehouse para dashboards
  warehouse_id:
    description: "ID del SQL Warehouse"
    default: ""
    
  # Esquemas
  schema_alunizaje:
    default: alunizaje
  
  schema_bronce:
    default: bronce
    
  schema_plata:
    default: plata
    
  schema_plata_analisis:
    default: plata_analisis
    
  schema_oro:
    default: oro
    
  # Volúmenes
  volume_crudos:
    default: datos_crudos
    
  volume_oficiales:
    default: datos_oficiales
    
  # Parámetros temporales
  oficial_periodo:
    default: 2026
    
  oficial_mes:
    default: 06
```

### Override en `databricks.local.yml`

Puedes sobrescribir cualquier variable:

```yaml
targets:
  free_dev:
    variables:
      catalog: mi_catalogo
      warehouse_id: abc123xyz
      oficial_periodo: 2025
      oficial_mes: 12
```

---

## Despliegue en Nuevo Workspace

### Paso 1: Clonar el Repositorio

```bash
git clone <repository-url>
cd databricks-portable-lab
```

### Paso 2: Configurar Variables Locales

```bash
cp databricks.local.yml.example databricks.local.yml
```

Editar `databricks.local.yml`:
```yaml
targets:
  free_dev:
    variables:
      catalog: <nombre_catalogo_existente_o_nuevo>
      warehouse_id: <tu_warehouse_id>
```

### Paso 3: Validar Portabilidad

```bash
./scripts/test_portability.sh
```

Este script verifica:
- ✓ Estructura del proyecto
- ✓ Archivos de configuración
- ✓ Variables de portabilidad
- ✓ Funciones de bootstrap
- ✓ Scripts de procesamiento

### Paso 4: Validar Bundle

```bash
databricks bundle validate --target free_dev
```

### Paso 5: Deploy

```bash
databricks bundle deploy --target free_dev
```

**¿Qué hace el deploy?**

1. **Bootstrap automático:**
   - Valida/crea catálogo
   - Crea esquemas necesarios
   - Crea volúmenes
   - **Procesa dashboards** (nuevo)

2. **Deploy de recursos:**
   - Pipelines
   - Jobs/Workflows
   - Dashboards (ya procesados)

### Paso 6: Ejecutar Workflow (Opcional)

```bash
# Ver workflow creado
databricks bundle summary --target free_dev

# Ejecutar workflow
databricks bundle run tmt_tmtb_workflow --target free_dev

# O ejecutar desde la UI
databricks bundle run --help
```

---

## Troubleshooting

### Error: "Catalog does not exist"

**Síntoma:**
```
Error: [CATALOG_DOES_NOT_EXIST] Catalog 'workspace' does not exist
```

**Solución:**

1. El bootstrap detecta esto automáticamente y muestra:
   ```
   [WARNING] El catálogo 'workspace' NO existe en este workspace.
   
   Catálogos disponibles en este workspace:
     • main
     • analytics
     • prod
   ```

2. Opciones:
   - **Opción A:** Usar un catálogo existente
     ```yaml
     # databricks.local.yml
     catalog: main  # o analytics, prod, etc.
     ```
   
   - **Opción B:** Crear el catálogo manualmente
     ```sql
     CREATE CATALOG IF NOT EXISTS workspace;
     ```
   
   - **Opción C:** Permitir que bootstrap lo cree automáticamente
     (solo si tienes permisos de CREATE CATALOG)

### Error: "Dashboard queries reference wrong catalog"

**Síntoma:**
Los dashboards no muestran datos o dan errores de tabla no encontrada.

**Diagnóstico:**
```bash
# Verificar referencias en dashboards
grep -r "workspace\." src/dashboards/*.lvdash.json
```

**Solución:**

1. **Procesamiento manual:**
   ```bash
   python scripts/process_dashboards.py --catalog tu_catalogo --force
   ```

2. **Redeploy:**
   ```bash
   databricks bundle deploy --target free_dev
   ```

3. **Verificar que se procesaron:**
   ```bash
   # No debe mostrar referencias a 'workspace'
   grep -c "workspace\." src/dashboards/*.lvdash.json
   
   # Debe mostrar referencias a tu catálogo
   grep -c "tu_catalogo\." src/dashboards/*.lvdash.json
   ```

### Error: Pipeline no encuentra datos

**Síntoma:**
```
Cannot read from volume: /Volumes/workspace/alunizaje/datos_crudos/
```

**Causa:** El catálogo en `databricks.local.yml` no coincide con el que se usó al crear los volúmenes.

**Solución:**

1. **Verificar qué catálogo se usó:**
   ```bash
   # Ver configuración actual
   databricks bundle validate --target free_dev
   ```

2. **Listar volúmenes existentes:**
   ```sql
   SHOW VOLUMES IN <catalog>.alunizaje;
   ```

3. **Opciones:**
   - Cambiar `catalog` en `databricks.local.yml` al catálogo correcto
   - O recrear los volúmenes con `databricks bundle destroy` + `deploy`

### Recuperar Dashboards Originales

Si necesitas restaurar los dashboards con el catálogo original `workspace`:

```bash
# Copiar backups
cp src/dashboards/.templates/tmt_tmtb.lvdash.json.original \
   src/dashboards/tmt_tmtb.lvdash.json

cp src/dashboards/.templates/margenes_comercializacion.lvdash.json.original \
   src/dashboards/margenes_comercializacion.lvdash.json

# O reprocesar con 'workspace'
python scripts/process_dashboards.py --catalog workspace --force
```

### Verificar Estado de Portabilidad

Ejecuta el script de validación en cualquier momento:

```bash
./scripts/test_portability.sh
```

Salida esperada:
```
===================================================================
VALIDACIÓN DE PORTABILIDAD - DATABRICKS PORTABLE LAB
===================================================================

✓ databricks.yml existe
✓ databricks.local.yml.example existe
✓ .gitignore contiene databricks.local.yml
✓ README-PORTABILIDAD.md existe
✓ bootstrap.py contiene función catalog_exists()
✓ bootstrap.py contiene función create_catalog()
✓ bootstrap.py contiene función process_dashboards()  ← Nuevo
✓ process_dashboards.py existe                        ← Nuevo

===================================================================
✅ TODAS LAS VALIDACIONES PASARON
===================================================================
```

---

## Resumen de Archivos de Portabilidad

| Archivo | Propósito | Versionado |
|---------|-----------|------------|
| `databricks.yml` | Configuración base del bundle | ✅ Sí |
| `databricks.local.yml` | Configuración local/específica | ❌ No (.gitignore) |
| `databricks.local.yml.example` | Template para configuración local | ✅ Sí |
| `scripts/bootstrap.py` | Validación y creación de recursos | ✅ Sí |
| `scripts/process_dashboards.py` | Procesamiento de dashboards | ✅ Sí |
| `scripts/test_portability.sh` | Validación de portabilidad | ✅ Sí |
| `src/dashboards/*.lvdash.json` | Dashboards (se procesan automáticamente) | ✅ Sí |
| `src/dashboards/.templates/` | Backups de dashboards originales | ❌ No (.gitignore) |
| `README-PORTABILIDAD.md` | Esta guía | ✅ Sí |

---

## Checklist de Migración

Usa este checklist al migrar a un nuevo workspace:

- [ ] Clonar repositorio
- [ ] Crear `databricks.local.yml` desde el ejemplo
- [ ] Configurar `catalog` en `databricks.local.yml`
- [ ] Configurar `warehouse_id` (opcional)
- [ ] Ejecutar `./scripts/test_portability.sh`
- [ ] Ejecutar `databricks bundle validate`
- [ ] Ejecutar `databricks bundle deploy`
- [ ] Verificar que dashboards se procesaron correctamente
- [ ] Verificar que pipelines se crearon
- [ ] Verificar que workflow se creó
- [ ] (Opcional) Ejecutar workflow de prueba
- [ ] (Opcional) Cargar datos de prueba en volúmenes

---

## Preguntas Frecuentes

### ¿Por qué no versionamos `databricks.local.yml`?

Porque contiene configuración específica de cada workspace/usuario. Cada persona/entorno necesita su propia configuración.

### ¿Qué pasa si no creo `databricks.local.yml`?

El proyecto usa el valor por defecto `catalog: workspace` de `databricks.yml`. Funciona, pero no es portable si el catálogo no existe.

### ¿Los dashboards se procesan en cada deploy?

Sí, el script `process_dashboards()` se ejecuta automáticamente en el bootstrap. Es idempotente: si los dashboards ya tienen el catálogo correcto, no hace cambios innecesarios.

### ¿Puedo tener múltiples configuraciones locales?

Sí, puedes crear archivos como:
- `databricks.dev.yml` 
- `databricks.staging.yml`
- `databricks.prod.yml`

Y especificar cuál usar:
```bash
databricks bundle deploy --target <target_name>
```

### ¿Cómo verifico qué catálogo está usando el bundle?

```bash
# Ver todas las variables resueltas
databricks bundle validate --target free_dev

# O ver directamente el bootstrap
python scripts/bootstrap.py
```

---

## Soporte

Para reportar problemas de portabilidad o sugerir mejoras, contacta al equipo de desarrollo del proyecto.

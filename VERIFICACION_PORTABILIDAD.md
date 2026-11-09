# ✅ Verificación de Portabilidad - Checklist Completo

Este documento verifica que el proyecto esté completamente portable y listo para migrar entre cuentas sin problemas.

## 🔍 Problemas Identificados y Corregidos

### ❌ Problema 1: Catálogo Hardcodeado

**Síntoma:**
```
Error: cannot create resources.pipelines.tmt_tmtb_analisis: 
Catalog 'workspace' does not exist. (404 CATALOG_DOES_NOT_EXIST)
```

**Causa:** 
- El catálogo 'workspace' no existe en todos los entornos
- No había mecanismo para detectar/crear catálogos automáticamente

**✅ Solución Implementada:**
1. Script `bootstrap.py` mejorado con:
   - Verificación de existencia del catálogo
   - Intento de creación automática
   - Mensajes claros de error con soluciones
   - Listado de catálogos disponibles

2. Documentación en `databricks.yml`:
   - Comentarios explicativos sobre la variable `catalog`
   - Instrucciones para diferentes escenarios
   - Referencia a `databricks.local.yml`

3. Archivo `databricks.local.yml.example` creado:
   - Plantilla lista para copiar
   - Ejemplos de configuración
   - Instrucciones paso a paso

4. Guía completa en `PORTABILIDAD.md`:
   - 3 opciones para resolver el problema
   - Flujo completo de setup
   - Troubleshooting
   - Buenas prácticas

---

### ❌ Problema 2: Pipeline ID Hardcodeado en Workflow

**Síntoma:**
- Workflow falla al ejecutar tarea `margenes_comercializacion`
- Pipeline funciona bien cuando se ejecuta directamente
- Error indica que el pipeline no existe

**Causa:**
```yaml
# ANTES (INCORRECTO):
pipeline_task:
  pipeline_id: 9426a33d-71ef-44f4-a278-7afba0000ae1  # ❌ ID hardcodeado
```

Este ID:
- Es específico del entorno original
- No existe en otros entornos
- No se actualiza cuando el bundle crea nuevos pipelines
- **Rompe completamente la portabilidad**

**✅ Solución Implementada:**
```yaml
# DESPUÉS (CORRECTO):
pipeline_task:
  pipeline_id: ${resources.pipelines.tmt_tmtb_margenes_comercializacion.id}  # ✅ Referencia dinámica
```

**Cambios en `tmt_tmtb_workflow.job.yml`:**
1. Reemplazado pipeline_id hardcodeado por referencia dinámica
2. Corregida indentación YAML
3. Agregados comentarios explicativos para cada tarea
4. Documentado el porqué de usar referencias dinámicas

---

## ✅ Checklist de Portabilidad

Verifica que TODOS estos puntos estén correctos antes de migrar:

### 1. Variables Dinámicas

- [ ] **Catálogos:** ✅ `${var.catalog}` usado en todos los pipelines
- [ ] **Schemas:** ✅ `${var.schema_*}` usado en todos los archivos SQL
- [ ] **Volumes:** ✅ `${var.volume_*}` usado donde se necesita
- [ ] **Pipeline IDs:** ✅ `${resources.pipelines.*.id}` en el workflow
- [ ] **Warehouse ID:** ✅ `${var.warehouse_id}` con lookup dinámico

### 2. Archivos SQL

Todos los archivos SQL deben usar variables `${project.*}`:

#### ✅ Bronce (tmt_tmtb):
- `tmt.py` - Usa variables de configuración
- `tmtb.py` - Usa variables de configuración
- `carga.py` - Usa variables de configuración
- `consumo.py` - Usa variables de configuración

#### ✅ Plata (tmt_tmtb):
- `plata_carga.sql` - Usa `${project.catalog}.${project.schema_plata}`
- `plata_consumo.sql` - Usa `${project.catalog}.${project.schema_plata}`

#### ✅ Plata Análisis (tmt_tmtb_analisis):
- `plata_carga_diferencias.sql` - Usa variables dinámicas
- `plata_carga_completitud.sql` - Usa variables dinámicas
- `plata_950_carga.sql` - Usa variables dinámicas

#### ✅ Oro:
- `boxes.sql` (tmt_tmtb_analisis) - Usa `${project.catalog}.${project.schema_oro}`
- `margen_comercializacion.sql` (tmt_tmtb) - Usa `${project.catalog}.${project.schema_oro}`

### 3. Configuración de Pipelines

#### ✅ tmt_tmtb.pipeline.yml:
```yaml
catalog: ${var.catalog}  ✅
schema: ${var.schema_bronce}  ✅
configuration:
  project.catalog: ${var.catalog}  ✅
  project.schema_*: ${var.schema_*}  ✅
```

#### ✅ tmt_tmtb_analisis.pipeline.yml:
```yaml
catalog: ${var.catalog}  ✅
schema: ${var.schema_analisis}  ✅
configuration:
  project.catalog: ${var.catalog}  ✅
  project.schema_*: ${var.schema_*}  ✅
```

#### ✅ tmt_tmtb_margenes_comercializacion.pipeline.yml:
```yaml
catalog: ${var.catalog}  ✅
target: ${var.schema_oro}  ✅
configuration:
  project.catalog: ${var.catalog}  ✅
  project.schema_*: ${var.schema_*}  ✅
```

### 4. Workflow (Job)

#### ✅ tmt_tmtb_workflow.job.yml:
```yaml
tasks:
  - task_key: actualizar_incremental
    pipeline_task:
      pipeline_id: ${resources.pipelines.tmt_tmtb.id}  ✅

  - task_key: recalcular_analisis
    pipeline_task:
      pipeline_id: ${resources.pipelines.tmt_tmtb_analisis.id}  ✅

  - task_key: margenes_comercializacion
    pipeline_task:
      pipeline_id: ${resources.pipelines.tmt_tmtb_margenes_comercializacion.id}  ✅
```

**⚠️ IMPORTANTE:** NO debe haber ningún pipeline_id hardcodeado como UUID.

### 5. Rutas de Archivos

Todas las rutas en pipelines deben ser **relativas** desde el archivo del pipeline:

```yaml
libraries:
  - file:
      path: ../../src/tmt_tmtb/bronce/tmt.py  ✅ Ruta relativa
```

**❌ NO usar rutas absolutas** como `/Workspace/Users/...`

### 6. Archivos de Configuración

#### ✅ databricks.yml:
- Define todas las variables con valores por defecto
- Documenta cada variable
- Incluye comentarios sobre portabilidad

#### ✅ databricks.local.yml.example:
- Plantilla para configuración local
- Instrucciones claras
- Ejemplos de uso

#### ✅ .gitignore:
- Incluye `databricks.local.yml`
- Incluye `.databricks/`
- No versiona configuración específica del entorno

### 7. Scripts de Inicialización

#### ✅ bootstrap.py:
- Acepta catálogo como parámetro
- Verifica existencia del catálogo
- Intenta crear catálogo si es necesario
- Crea todos los schemas
- Crea todos los volumes
- Manejo de errores claro

### 8. Documentación

- [ ] ✅ `README_IMPLEMENTACION.md` - Actualizado con inicio rápido
- [ ] ✅ `PORTABILIDAD.md` - Guía completa de portabilidad
- [ ] ✅ `databricks.local.yml.example` - Plantilla de configuración
- [ ] ✅ `VERIFICACION_PORTABILIDAD.md` - Este checklist

---

## 🧪 Prueba de Portabilidad

### Paso 1: Limpiar Entorno Actual (Opcional)

Para probar la portabilidad desde cero:

```bash
# Listar recursos deployados
databricks bundle resources list --target free_dev

# Destruir recursos (cuidado: elimina todo)
databricks bundle destroy --target free_dev --auto-approve
```

### Paso 2: Configurar Nuevo Entorno

```bash
# 1. Ver catálogos disponibles
databricks catalogs list

# 2. Crear configuración local
cp databricks.local.yml.example databricks.local.yml

# 3. Editar databricks.local.yml
# Cambiar:
#   catalog:
#     default: main  # o el catálogo que uses

# 4. Ejecutar bootstrap
databricks bundle run bootstrap --target free_dev
```

**Salida Esperada del Bootstrap:**
```
======================================================================
BOOTSTRAP DATABRICKS
Catalogo: main
======================================================================

[1/3] Verificando catalogo...
[OK] El catalogo 'main' existe.

[2/3] Verificando schemas en main...
[OK] main.alunizaje ya existe. Se conserva.
[OK] main.bronce ya existe. Se conserva.
[OK] main.plata ya existe. Se conserva.
[OK] main.plata_analisis ya existe. Se conserva.
[OK] main.oro ya existe. Se conserva.

[3/3] Verificando volumes en main...
[OK] main.alunizaje.datos_crudos ya existe. Se conserva.
[OK] main.alunizaje.datos_oficiales ya existe. Se conserva.

======================================================================
BOOTSTRAP COMPLETADO
======================================================================
```

### Paso 3: Validar Configuración

```bash
databricks bundle validate --strict --target free_dev
```

**Salida Esperada:**
```
Validation OK!
```

### Paso 4: Deploy

```bash
databricks bundle deploy --target free_dev
```

**Verificar que se crean:**
- ✅ 3 pipelines (tmt_tmtb, tmt_tmtb_analisis, tmt_tmtb_margenes_comercializacion)
- ✅ 1 workflow (TMT_TMTB_Workflow) con 3 tareas
- ✅ Todas las referencias de pipeline_id son dinámicas

### Paso 5: Ejecutar Workflow

```bash
databricks bundle run tmt_tmtb_workflow --target free_dev
```

**Verificar que:**
- ✅ Tarea 1 (actualizar_incremental) se ejecuta correctamente
- ✅ Tarea 2 (recalcular_analisis) se ejecuta después de la 1
- ✅ Tarea 3 (margenes_comercializacion) se ejecuta después de la 2
- ✅ **NO hay errores de "pipeline not found"**

### Paso 6: Verificar Pipelines Individualmente

```bash
# Pipeline 1
databricks bundle run tmt_tmtb --target free_dev

# Pipeline 2
databricks bundle run tmt_tmtb_analisis --target free_dev

# Pipeline 3 (el que tenía el problema)
databricks bundle run tmt_tmtb_margenes_comercializacion --target free_dev
```

Todos deben ejecutarse correctamente.

---

## 🎯 Puntos Críticos de Portabilidad

### ❌ NUNCA Hardcodear:

1. **Pipeline IDs:**
   ```yaml
   # ❌ MAL
   pipeline_id: 9426a33d-71ef-44f4-a278-7afba0000ae1
   
   # ✅ BIEN
   pipeline_id: ${resources.pipelines.nombre_pipeline.id}
   ```

2. **Catálogos/Schemas:**
   ```sql
   -- ❌ MAL
   SELECT * FROM workspace.bronce.tmt
   
   -- ✅ BIEN
   SELECT * FROM ${project.catalog}.${project.schema_bronce}.tmt
   ```

3. **Rutas del Workspace:**
   ```yaml
   # ❌ MAL
   path: /Workspace/Users/user@example.com/proyecto/archivo.py
   
   # ✅ BIEN
   path: ../../src/proyecto/archivo.py
   ```

4. **Warehouse IDs:**
   ```yaml
   # ❌ MAL
   warehouse_id: abc123def456
   
   # ✅ BIEN
   warehouse_id:
     lookup:
       warehouse: Serverless Starter Warehouse
   ```

### ✅ Siempre Usar:

1. **Variables del bundle:** `${var.nombre}`
2. **Referencias a recursos:** `${resources.tipo.nombre.id}`
3. **Variables de configuración en pipelines:** `${project.nombre}`
4. **Rutas relativas:** `../../ruta/relativa`
5. **Lookups dinámicos:** Para warehouses y otros recursos

---

## 📋 Resumen de Cambios

### Archivos Modificados:

1. **scripts/bootstrap.py**
   - Agregada verificación de catálogo
   - Agregada creación automática de catálogo
   - Mejorado manejo de errores
   - Agregados mensajes informativos

2. **databricks.yml**
   - Agregada documentación extensa sobre variable `catalog`
   - Agregados comentarios en script bootstrap

3. **resources/jobs/tmt_tmtb_workflow.job.yml** ⭐ **CRÍTICO**
   - **Reemplazado pipeline_id hardcodeado por referencia dinámica**
   - Corregida estructura YAML
   - Agregados comentarios explicativos

4. **.gitignore**
   - Agregado `databricks.local.yml`

5. **README_IMPLEMENTACION.md**
   - Agregada sección de inicio rápido
   - Agregada alerta sobre portabilidad

### Archivos Nuevos:

1. **PORTABILIDAD.md** - Guía completa de portabilidad
2. **databricks.local.yml.example** - Plantilla de configuración
3. **VERIFICACION_PORTABILIDAD.md** - Este checklist

---

## ✅ Confirmación Final

Antes de considerar el proyecto portable, verifica:

- [ ] Bootstrap ejecuta sin errores en nuevo entorno
- [ ] `bundle validate` pasa sin warnings
- [ ] `bundle deploy` crea todos los recursos
- [ ] Workflow ejecuta las 3 tareas correctamente
- [ ] No hay errores de "catalog not found"
- [ ] No hay errores de "pipeline not found"
- [ ] Pipelines individuales funcionan
- [ ] Documentación está actualizada
- [ ] `databricks.local.yml.example` existe
- [ ] `.gitignore` incluye archivos locales

## 🎉 Proyecto Portable

Si todos los puntos anteriores están verificados, el proyecto es **completamente portable** y puede migrarse entre cuentas sin modificar código.
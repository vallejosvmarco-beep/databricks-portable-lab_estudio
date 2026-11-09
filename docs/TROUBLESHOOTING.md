# 🔧 Resolución de Problemas de Portabilidad

## Error: Dashboard busca tabla en catálogo incorrecto

### Síntoma

Al abrir un dashboard en un ambiente diferente, obtienes un error como:

```
[TABLE_OR_VIEW_NOT_FOUND] The table or view `mi_catalogo_test`.`oro`.`boxes_anual` cannot be found.
```

Pero tu `databricks.yml` o `databricks.local.yml` tiene configurado un catálogo diferente (ej: `workspace`).

### Causa

Los archivos `.lvdash.json` en `src/dashboards/` contienen referencias SQL hardcodeadas a un catálogo diferente del configurado.

### Solución Rápida

```bash
# Opción 1: Reprocesar dashboards con el catálogo correcto
python scripts/process_dashboards.py --catalog workspace --force

# Opción 2: Restaurar desde backup y procesar
cp src/dashboards/.templates/*.original src/dashboards/
rename 's/\.original$//' src/dashboards/*.original 2>/dev/null || true
python scripts/process_dashboards.py --catalog workspace --force
```

### Verificación

```bash
# Ver qué catálogos usan los dashboards actualmente
grep -o '"[a-z_]*\.(oro\|plata\|bronce\|alunizaje)' src/dashboards/*.lvdash.json | sort | uniq -c
```

## Cómo funciona el sistema

```
databricks.local.yml → bootstrap.py → process_dashboards.py → deploy
   (configuración)      (orquesta)     (reemplaza catálogo)    (despliega)
```

El script `process_dashboards.py` ahora detecta **cualquier** catálogo actual y lo reemplaza con el configurado.

## Comandos útiles

```bash
# Ver catálogos disponibles
databricks catalogs list

# Verificar configuración actual
cat databricks.local.yml | grep catalog

# Forzar reprocesamiento
python scripts/process_dashboards.py --catalog NOMBRE --force
```

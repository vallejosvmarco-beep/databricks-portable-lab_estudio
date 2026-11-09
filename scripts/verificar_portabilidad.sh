#!/bin/bash

# ============================================================
# Script de Verificacion de Portabilidad
# ============================================================
# Este script verifica que el proyecto este configurado
# correctamente para ser portable entre entornos.
# ============================================================

set -e

echo "===================================================================="
echo "VERIFICACION DE PORTABILIDAD - databricks_portable_lab"
echo "===================================================================="
echo ""

# ============================================================
# 1. Verificar archivos requeridos
# ============================================================
echo "[1/5] Verificando archivos requeridos..."

required_files=(
    "databricks.yml"
    "databricks.local.yml.example"
    "scripts/bootstrap.py"
    "PORTABILIDAD.md"
    "VERIFICACION_PORTABILIDAD.md"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file - FALTA"
        exit 1
    fi
done

echo ""

# ============================================================
# 2. Verificar que no haya pipeline IDs hardcodeados
# ============================================================
echo "[2/5] Verificando referencias de pipeline..."

if grep -r "pipeline_id:.*[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}" resources/jobs/ 2>/dev/null; then
    echo "  ❌ ADVERTENCIA: Pipeline IDs hardcodeados encontrados"
    echo "     Esto rompe la portabilidad. Usa referencias dinamicas:"
    echo "     pipeline_id: \${resources.pipelines.nombre.id}"
    exit 1
else
    echo "  ✅ No se encontraron pipeline IDs hardcodeados"
fi

echo ""

# ============================================================
# 3. Verificar sintaxis YAML
# ============================================================
echo "[3/5] Verificando sintaxis YAML..."

python3 << 'EOF'
import yaml
import sys
import os

errors = []

for root, dirs, files in os.walk('resources'):
    for file in files:
        if file.endswith('.yml'):
            filepath = os.path.join(root, file)
            try:
                with open(filepath, 'r') as f:
                    yaml.safe_load(f)
                print(f"  ✅ {filepath}")
            except Exception as e:
                print(f"  ❌ {filepath}: {e}")
                errors.append(filepath)

if errors:
    sys.exit(1)
EOF

echo ""

# ============================================================
# 4. Verificar variables en databricks.yml
# ============================================================
echo "[4/5] Verificando variables en databricks.yml..."

required_vars=(
    "catalog"
    "schema_alunizaje"
    "schema_bronce"
    "schema_plata"
    "schema_analisis"
    "schema_oro"
    "volume_crudos"
    "volume_oficiales"
)

for var in "${required_vars[@]}"; do
    if grep -q "^  $var:" databricks.yml; then
        echo "  ✅ Variable '$var' definida"
    else
        echo "  ❌ Variable '$var' NO encontrada"
        exit 1
    fi
done

echo ""

# ============================================================
# 5. Verificar .gitignore
# ============================================================
echo "[5/5] Verificando .gitignore..."

if grep -q "databricks.local.yml" .gitignore; then
    echo "  ✅ databricks.local.yml esta en .gitignore"
else
    echo "  ❌ ADVERTENCIA: databricks.local.yml NO esta en .gitignore"
    echo "     Esto puede exponer configuracion sensible en Git"
fi

if grep -q ".databricks/" .gitignore; then
    echo "  ✅ .databricks/ esta en .gitignore"
else
    echo "  ⚠️  ADVERTENCIA: .databricks/ NO esta en .gitignore"
fi

echo ""
echo "===================================================================="
echo "VERIFICACION COMPLETADA"
echo "===================================================================="
echo ""
echo "✅ El proyecto esta configurado correctamente para portabilidad"
echo ""
echo "Proximos pasos:"
echo "  1. Crear configuracion local:"
echo "     cp databricks.local.yml.example databricks.local.yml"
echo ""
echo "  2. Editar databricks.local.yml con tu catalogo"
echo ""
echo "  3. Ejecutar bootstrap:"
echo "     databricks bundle run bootstrap --target free_dev"
echo ""
echo "  4. Deploy:"
echo "     databricks bundle deploy --target free_dev"
echo ""
echo "Ver documentacion completa: PORTABILIDAD.md"
echo "===================================================================="
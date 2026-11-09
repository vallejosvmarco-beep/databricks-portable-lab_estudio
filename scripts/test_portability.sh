#!/bin/bash

echo "==================================================================="
echo "VALIDACIÓN DE PORTABILIDAD - DATABRICKS PORTABLE LAB"
echo "==================================================================="
echo

ERRORS=0

# ============================================================
# 1. ARCHIVOS DE CONFIGURACIÓN
# ============================================================

echo "1. Archivos de configuración:"
echo "-------------------------------------------------------------------"

if [ -f "databricks.yml" ]; then
    echo "✓ databricks.yml existe"
else
    echo "✗ databricks.yml NO encontrado"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "databricks.local.yml.example" ]; then
    echo "✓ databricks.local.yml.example existe"
else
    echo "✗ databricks.local.yml.example NO encontrado"
    ERRORS=$((ERRORS + 1))
fi

if grep -q "databricks.local.yml" .gitignore 2>/dev/null; then
    echo "✓ .gitignore contiene databricks.local.yml"
else
    echo "✗ .gitignore NO ignora databricks.local.yml"
    ERRORS=$((ERRORS + 1))
fi

echo

# ============================================================
# 2. DOCUMENTACIÓN
# ============================================================

echo "2. Documentación:"
echo "-------------------------------------------------------------------"

if [ -f "README-PORTABILIDAD.md" ]; then
    echo "✓ README-PORTABILIDAD.md existe"
else
    echo "✗ README-PORTABILIDAD.md NO encontrado"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "README.md" ]; then
    echo "✓ README.md existe"
else
    echo "✗ README.md NO encontrado"
    ERRORS=$((ERRORS + 1))
fi

echo

# ============================================================
# 3. SCRIPTS DE BOOTSTRAP Y PROCESAMIENTO
# ============================================================

echo "3. Scripts de portabilidad:"
echo "-------------------------------------------------------------------"

if [ -f "scripts/bootstrap.py" ]; then
    echo "✓ scripts/bootstrap.py existe"
    
    # Verificar funciones clave
    if grep -q "def catalog_exists" scripts/bootstrap.py; then
        echo "  ✓ Contiene función catalog_exists()"
    else
        echo "  ✗ Falta función catalog_exists()"
        ERRORS=$((ERRORS + 1))
    fi
    
    if grep -q "def list_available_catalogs" scripts/bootstrap.py; then
        echo "  ✓ Contiene función list_available_catalogs()"
    else
        echo "  ✗ Falta función list_available_catalogs()"
        ERRORS=$((ERRORS + 1))
    fi
    
    if grep -q "def create_catalog" scripts/bootstrap.py; then
        echo "  ✓ Contiene función create_catalog()"
    else
        echo "  ✗ Falta función create_catalog()"
        ERRORS=$((ERRORS + 1))
    fi
    
    if grep -q "def process_dashboards" scripts/bootstrap.py; then
        echo "  ✓ Contiene función process_dashboards()"
    else
        echo "  ✗ Falta función process_dashboards()"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "✗ scripts/bootstrap.py NO encontrado"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "scripts/process_dashboards.py" ]; then
    echo "✓ scripts/process_dashboards.py existe"
else
    echo "✗ scripts/process_dashboards.py NO encontrado"
    ERRORS=$((ERRORS + 1))
fi

echo

# ============================================================
# 4. DASHBOARDS
# ============================================================

echo "4. Dashboards:"
echo "-------------------------------------------------------------------"

if [ -d "src/dashboards" ]; then
    echo "✓ Directorio src/dashboards/ existe"
    
    # Contar dashboards
    DASHBOARD_COUNT=$(find src/dashboards -maxdepth 1 -name "*.lvdash.json" | wc -l)
    echo "  ℹ  Encontrados $DASHBOARD_COUNT dashboard(s)"
    
    # Verificar configuración de dashboards
    if [ -d "resources/dashboards" ]; then
        echo "  ✓ Configuración en resources/dashboards/ existe"
    else
        echo "  ✗ Falta resources/dashboards/"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "✗ Directorio src/dashboards/ NO encontrado"
    ERRORS=$((ERRORS + 1))
fi

echo

# ============================================================
# 5. ESTRUCTURA DE RECURSOS
# ============================================================

echo "5. Estructura de recursos:"
echo "-------------------------------------------------------------------"

if [ -d "resources/pipelines" ]; then
    echo "✓ resources/pipelines/ existe"
else
    echo "✗ resources/pipelines/ NO encontrado"
    ERRORS=$((ERRORS + 1))
fi

if [ -d "resources/jobs" ]; then
    echo "✓ resources/jobs/ existe"
else
    echo "✗ resources/jobs/ NO encontrado"
    ERRORS=$((ERRORS + 1))
fi

if [ -d "src/tmt_tmtb" ]; then
    echo "✓ src/tmt_tmtb/ existe"
else
    echo "✗ src/tmt_tmtb/ NO encontrado"
    ERRORS=$((ERRORS + 1))
fi

echo

# ============================================================
# 6. VARIABLES DE PORTABILIDAD
# ============================================================

echo "6. Variables de portabilidad:"
echo "-------------------------------------------------------------------"

if grep -q "catalog:" databricks.yml; then
    echo "✓ Variable 'catalog' definida"
else
    echo "✗ Variable 'catalog' NO definida"
    ERRORS=$((ERRORS + 1))
fi

if grep -q "schema_alunizaje:" databricks.yml; then
    echo "✓ Variable 'schema_alunizaje' definida"
else
    echo "✗ Variable 'schema_alunizaje' NO definida"
    ERRORS=$((ERRORS + 1))
fi

echo

# ============================================================
# RESULTADO FINAL
# ============================================================

echo "==================================================================="

if [ $ERRORS -eq 0 ]; then
    echo "✅ TODAS LAS VALIDACIONES PASARON"
    echo "==================================================================="
    echo
    echo "El proyecto está configurado correctamente para portabilidad."
    echo
    echo "Los dashboards se procesarán automáticamente durante el deploy."
    echo
    exit 0
else
    echo "❌ SE ENCONTRARON $ERRORS ERROR(ES)"
    echo "==================================================================="
    echo
    echo "Revisa los mensajes de error arriba."
    echo
    exit 1
fi

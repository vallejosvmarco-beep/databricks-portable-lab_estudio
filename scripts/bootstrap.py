import subprocess
import sys
import json
import os


def _resolve_catalog():
    """Resolve catalog from CLI args, env var, or bundle config files."""
    if len(sys.argv) > 1:
        return sys.argv[1]
    if os.environ.get("CATALOG"):
        return os.environ["CATALOG"]
    try:
        import yaml
        script_dir = os.path.dirname(os.path.abspath(__file__))
        bundle_root = os.path.dirname(script_dir)
        target = os.environ.get("BUNDLE_TARGET", "free_dev")
        for fname in ("databricks.local.yml", "databricks.yml"):
            config_path = os.path.join(bundle_root, fname)
            if os.path.exists(config_path):
                with open(config_path) as f:
                    data = yaml.safe_load(f)
                if not data:
                    continue
                # Check target-level variables first
                targets = data.get("targets", {})
                if target in targets:
                    target_vars = targets[target].get("variables", {})
                    if "catalog" in target_vars:
                        val = target_vars["catalog"]
                        if isinstance(val, dict) and "default" in val:
                            return val["default"]
                        elif isinstance(val, str):
                            return val
                # Fallback to top-level variables
                if "variables" in data:
                    cat_var = data["variables"].get("catalog", {})
                    if isinstance(cat_var, dict) and "default" in cat_var:
                        return cat_var["default"]
                    elif isinstance(cat_var, str):
                        return cat_var
    except Exception:
        pass
    return "workspace"


CATALOG = _resolve_catalog()


SCHEMAS = [
    "alunizaje",
    "bronce",
    "plata",
    "plata_analisis",
    "oro",
]


VOLUMES = [
    ("alunizaje", "datos_crudos"),
    ("alunizaje", "datos_oficiales"),
]


def run(cmd, check=True):
    print(f"> {' '.join(cmd)}")

    result = subprocess.run(
        cmd,
        text=True,
        capture_output=True
    )

    if result.stdout:
        print(result.stdout)

    if result.returncode != 0 and result.stderr:
        print(result.stderr)

    if check and result.returncode != 0:
        raise RuntimeError(
            f"Comando fallo con codigo {result.returncode}: "
            f"{' '.join(cmd)}"
        )

    return result


def catalog_exists():
    """Verifica si el catalogo existe."""
    result = run(
        [
            "databricks",
            "catalogs",
            "get",
            CATALOG,
        ],
        check=False,
    )
    return result.returncode == 0


def list_available_catalogs():
    """Lista catalogos disponibles en el workspace."""
    result = run(
        [
            "databricks",
            "catalogs",
            "list",
            "--output",
            "json",
        ],
        check=False,
    )
    
    if result.returncode == 0 and result.stdout:
        try:
            catalogs_data = json.loads(result.stdout)
            if "catalogs" in catalogs_data:
                return [c["name"] for c in catalogs_data["catalogs"]]
        except json.JSONDecodeError:
            pass
    
    return []


def create_catalog():
    """Intenta crear el catalogo."""
    print(f"[CREATE] Intentando crear catalogo {CATALOG}...")
    result = run(
        [
            "databricks",
            "catalogs",
            "create",
            CATALOG,
        ],
        check=False,
    )
    return result.returncode == 0


def schema_exists(schema):
    full_name = f"{CATALOG}.{schema}"

    result = run(
        [
            "databricks",
            "schemas",
            "get",
            full_name,
        ],
        check=False,
    )

    return result.returncode == 0


def create_schema(schema):
    run(
        [
            "databricks",
            "schemas",
            "create",
            schema,
            CATALOG,
        ]
    )


def volume_exists(schema, volume):
    full_name = f"{CATALOG}.{schema}.{volume}"

    result = run(
        [
            "databricks",
            "volumes",
            "read",
            full_name,
        ],
        check=False,
    )

    return result.returncode == 0


def create_volume(schema, volume):
    run(
        [
            "databricks",
            "volumes",
            "create",
            CATALOG,
            schema,
            volume,
            "MANAGED",
        ]
    )




def process_dashboards():
    """Procesa dashboards para reemplazar catálogo hardcodeado."""
    print()
    print("=" * 70)
    print("PROCESANDO DASHBOARDS PARA PORTABILIDAD")
    print("=" * 70)
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    dashboards_dir = os.path.join(project_root, "src", "dashboards")
    
    if not os.path.exists(dashboards_dir):
        print(f"⚠️  Directorio de dashboards no encontrado: {dashboards_dir}")
        return
    
    # Buscar archivos .lvdash.json
    dashboard_files = [
        f for f in os.listdir(dashboards_dir) 
        if f.endswith('.lvdash.json')
    ]
    
    if not dashboard_files:
        print("ℹ️  No se encontraron dashboards para procesar")
        return
    
    print(f"📊 Encontrados {len(dashboard_files)} dashboard(s)")
    print()
    
    processed = 0
    for dashboard_file in dashboard_files:
        file_path = os.path.join(dashboards_dir, dashboard_file)
        
        # Leer contenido
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Verificar si necesita procesamiento
        if 'workspace.' not in content:
            # Verificar si ya tiene el catálogo correcto
            if f'{CATALOG}.' in content:
                print(f"✓ {dashboard_file}: ya usa catálogo '{CATALOG}'")
                continue
        
        # Contar reemplazos
        workspace_count = content.count('workspace.')
        
        if workspace_count == 0:
            print(f"ℹ️  {dashboard_file}: sin referencias a 'workspace'")
            continue
        
        # Reemplazar workspace con el catálogo configurado
        new_content = content.replace('workspace.', f'{CATALOG}.')
        
        # Guardar el archivo modificado
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        
        print(f"✅ {dashboard_file}: {workspace_count} reemplazos 'workspace' → '{CATALOG}'")
        processed += 1
    
    if processed > 0:
        print()
        print(f"📝 {processed} dashboard(s) procesado(s) correctamente")
    
    print("=" * 70)


print("=" * 70)
print("BOOTSTRAP DATABRICKS")
print(f"Catalogo: {CATALOG}")
print("=" * 70)


# ============================================================
# VALIDACION DEL CATALOGO
# ============================================================

if not catalog_exists():
    print(f"[WARNING] El catalogo '{CATALOG}' NO existe en este workspace.")
    print()
    
    available = list_available_catalogs()
    
    if available:
        print("Catalogos disponibles en este workspace:")
        for cat in available:
            print(f"  - {cat}")
        print()
    
    print("Intentando crear el catalogo...")
    if create_catalog():
        print(f"[OK] Catalogo '{CATALOG}' creado exitosamente.")
    else:
        print(f"[ERROR] No se pudo crear el catalogo '{CATALOG}'.")
        print()
        print("SOLUCION:")
        print("  1. Si no tienes permisos para crear catalogos:")
        print(f"     - Usa un catalogo existente: databricks bundle deploy --var catalog=<nombre>")
        print("  2. O crea un archivo databricks.local.yml:")
        print("     targets:")
        print("       free_dev:")
        print("         variables:")
        print("           catalog: <nombre_catalogo_existente>")
        print()
        sys.exit(1)
else:
    print(f"[OK] Catalogo '{CATALOG}' existe.")


# ============================================================
# SCHEMAS
# ============================================================

for schema in SCHEMAS:

    full_name = f"{CATALOG}.{schema}"

    if schema_exists(schema):

        print(f"[OK] {full_name} ya existe. Se conserva.")

    else:

        print(f"[CREATE] {full_name}")

        create_schema(schema)


# ============================================================
# VOLUMES
# ============================================================

for schema, volume in VOLUMES:

    full_name = f"{CATALOG}.{schema}.{volume}"

    if volume_exists(schema, volume):

        print(f"[OK] {full_name} ya existe. Se conserva.")

    else:

        print(f"[CREATE] {full_name}")

        create_volume(schema, volume)




# ============================================================
# DASHBOARDS
# ============================================================

process_dashboards()

print("=" * 70)
print("BOOTSTRAP COMPLETADO")
print("=" * 70)

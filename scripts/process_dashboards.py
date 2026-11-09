#!/usr/bin/env python3
"""
Script de preprocesamiento de dashboards para portabilidad.

Este script reemplaza CUALQUIER catálogo en los archivos de dashboard
.lvdash.json con el catálogo configurado en databricks.yml/local.yml.

Uso:
    python scripts/process_dashboards.py --catalog <catalog_name>
"""

import json
import os
import sys
import argparse
import re
from pathlib import Path


def process_dashboard(template_path: str, output_path: str, catalog: str) -> int:
    """
    Procesa un archivo de dashboard reemplazando CUALQUIER catálogo.
    
    Args:
        template_path: Ruta al archivo .lvdash.json original
        output_path: Ruta donde guardar el dashboard procesado
        catalog: Nombre del catálogo a usar
        
    Returns:
        Número de reemplazos realizados
    """
    print(f"📄 Procesando: {template_path}")
    
    # Leer el archivo JSON
    with open(template_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Patrón para detectar: "catalog"."schema" donde schema es uno de nuestros schemas conocidos
    # Esto evita reemplazar otros catálogos del sistema como system.access
    known_schemas = ['oro', 'plata', 'bronce', 'alunizaje']
    
    # Crear patrón que capture: palabra.schema (donde schema es conocido)
    pattern = r'\b([a-zA-Z_][a-zA-Z0-9_]*)\.(' + '|'.join(known_schemas) + r')\b'
    
    # Función de reemplazo que preserva el schema pero cambia el catálogo
    def replace_catalog(match):
        old_catalog = match.group(1)
        schema = match.group(2)
        
        # No reemplazar catálogos del sistema
        if old_catalog in ['system', 'hive_metastore']:
            return match.group(0)
        
        return f"{catalog}.{schema}"
    
    # Contar reemplazos antes
    original_content = content
    
    # Hacer el reemplazo
    content = re.sub(pattern, replace_catalog, content)
    
    # Contar reemplazos realizados
    replacements = len(re.findall(pattern, original_content))
    
    # Guardar el archivo procesado
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"   ✅ Reemplazos: {replacements} referencias de catálogo → '{catalog}'")
    print(f"   📝 Guardado en: {output_path}")
    
    return replacements


def main():
    parser = argparse.ArgumentParser(
        description='Procesar dashboards para hacerlos portables'
    )
    parser.add_argument(
        '--catalog',
        required=True,
        help='Nombre del catálogo a usar (ej: workspace, prod, dev)'
    )
    parser.add_argument(
        '--src-dir',
        default='src/dashboards',
        help='Directorio con los archivos .lvdash.json originales'
    )
    parser.add_argument(
        '--force',
        action='store_true',
        help='Procesar dashboards incluso si ya tienen el catálogo correcto'
    )
    
    args = parser.parse_args()
    
    # Obtener el directorio raíz del proyecto
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    src_dir = project_root / args.src_dir
    
    print("=" * 70)
    print("PROCESAMIENTO DE DASHBOARDS PARA PORTABILIDAD")
    print("=" * 70)
    print()
    print(f"📂 Directorio origen: {src_dir}")
    print(f"📦 Catálogo destino: {args.catalog}")
    print()
    
    # Verificar que el directorio existe
    if not src_dir.exists():
        print(f"❌ Error: El directorio {src_dir} no existe")
        sys.exit(1)
    
    # Buscar todos los archivos .lvdash.json
    dashboard_files = list(src_dir.glob('*.lvdash.json'))
    
    if not dashboard_files:
        print(f"⚠️  No se encontraron archivos .lvdash.json en {src_dir}")
        sys.exit(0)
    
    print(f"🔍 Encontrados {len(dashboard_files)} dashboard(s):")
    for f in dashboard_files:
        print(f"   • {f.name}")
    print()
    
    # Procesar cada dashboard
    processed = 0
    skipped = 0
    total_replacements = 0
    
    for dashboard_file in dashboard_files:
        # Verificar si ya está procesado (solo si no es --force)
        if not args.force:
            with open(dashboard_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Patrón para ver si ya usa el catálogo correcto
            known_schemas = ['oro', 'plata', 'bronce', 'alunizaje']
            pattern = r'\b([a-zA-Z_][a-zA-Z0-9_]*)\.(' + '|'.join(known_schemas) + r')\b'
            
            matches = re.findall(pattern, content)
            
            # Si TODOS los matches son del catálogo destino, skip
            if matches and all(cat == args.catalog for cat, _ in matches):
                print(f"⏭️  Saltando {dashboard_file.name} (ya usa catálogo '{args.catalog}')") 
                skipped += 1
                continue
        
        # Procesar el dashboard (in-place)
        replacements = process_dashboard(
            str(dashboard_file),
            str(dashboard_file),
            args.catalog
        )
        
        total_replacements += replacements
        processed += 1
        print()
    
    print("=" * 70)
    print("RESUMEN")
    print("=" * 70)
    print(f"✅ Procesados: {processed}")
    print(f"⏭️  Omitidos: {skipped}")
    print(f"🔄 Total de reemplazos: {total_replacements}")
    print()
    
    if processed > 0:
        print("💡 Los dashboards ahora usan el catálogo: '{}'".format(args.catalog))
        print("   Ejecuta 'databricks bundle deploy' para aplicar los cambios")
    
    print("=" * 70)


if __name__ == '__main__':
    main()

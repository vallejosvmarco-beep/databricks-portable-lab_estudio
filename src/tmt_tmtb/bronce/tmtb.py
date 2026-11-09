import re
import unicodedata

from pyspark import pipelines as dp
from pyspark.sql import functions as F


def _normalizar_nombre(nombre: str) -> str:
    texto = unicodedata.normalize("NFKD", str(nombre))
    texto = "".join(c for c in texto if not unicodedata.combining(c))
    texto = texto.strip().lower()
    texto = re.sub(r"[^a-z0-9]+", "_", texto)
    return texto.strip("_")


def _leer_oficial(subcarpeta: str, plan_esperado: str):
    catalog = spark.conf.get("project.catalog")
    schema = spark.conf.get("project.schema_alunizaje")
    volume = spark.conf.get("project.volume_oficiales")
    periodo = spark.conf.get("project.oficial_periodo")
    mes = spark.conf.get("project.oficial_mes")

    path = (
        f"/Volumes/{catalog}/{schema}/{volume}/"
        f"{subcarpeta}/{periodo}/{mes}"
    )

    df = (
        spark.read
        .format("excel")
        .option("headerRows", 1)
        .load(path)
    )

    df = df.toDF(*[_normalizar_nombre(c) for c in df.columns])

    # Columnas clave se tipan de forma estable; el resto conserva la inferencia del lector Excel.
    if "nis" in df.columns:
        df = df.withColumn("nis", F.col("nis").cast("string"))
    if "localizacion" in df.columns:
        df = df.withColumn("localizacion", F.col("localizacion").cast("string"))
    if "medidor" in df.columns:
        df = df.withColumn("medidor", F.col("medidor").cast("string"))
    if "plan" in df.columns:
        df = df.withColumn("plan", F.upper(F.trim(F.col("plan").cast("string"))))
    if "fecha_lectura" in df.columns:
        fecha_txt = F.col("fecha_lectura").cast("string")
        df = df.withColumn(
            "fecha_lectura",
            F.coalesce(
                F.to_date(fecha_txt, "dd-MM-yyyy"),
                F.to_date(fecha_txt, "yyyy-MM-dd"),
                F.col("fecha_lectura").cast("date")
            )
        )

    return (
        df
        .filter(F.col("nis").isNotNull())
        .filter(F.col("plan") == F.lit(plan_esperado))
        .dropDuplicates(["nis"])
    )


@dp.materialized_view(
    name="tmtb",
    comment="Snapshot oficial TMTB cargado desde Excel en el volumen datos_oficiales."
)
def tmtb():
    return _leer_oficial("tmtb", "TMTB")

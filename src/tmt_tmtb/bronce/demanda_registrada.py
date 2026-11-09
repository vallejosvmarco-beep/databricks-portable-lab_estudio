from pyspark import pipelines as dp
from pyspark.sql import functions as F


@dp.materialized_view(
    name="demanda_registrada",
    comment="Datos bronce de demanda registrada ingeridos desde archivos Excel en el volumen datos_oficiales."
)
def demanda_registrada():
    catalog = spark.conf.get("project.catalog")
    schema = spark.conf.get("project.schema_alunizaje")
    volume = spark.conf.get("project.volume_oficiales")

    # Leer archivos Excel del volumen usando patrón específico
    source_path = f"/Volumes/{catalog}/{schema}/{volume}/demanda_registrada/*/*/*.xlsx"

    return (
        spark.read
        .format("excel")
        .option("header", "true")
        .option("inferSchema", "true")
        .load(source_path)
        .withColumn(
            "periodo",
            F.regexp_extract("_metadata.file_path", r"/(\d{4})/", 1).cast("int")
        )
        .withColumn(
            "mes",
            F.regexp_extract("_metadata.file_path", r"/(\d{2})/", 1).cast("int")
        )
        .withColumn("file_name", F.col("_metadata.file_path"))
    )
from pyspark import pipelines as dp
from pyspark.sql import functions as F


@dp.table(
    name="consumo",
    comment="Datos bronce de consumo AMI ingeridos incrementalmente desde el volumen datos_crudos."
)
def consumo():
    catalog = spark.conf.get("project.catalog")
    schema = spark.conf.get("project.schema_alunizaje")
    volume = spark.conf.get("project.volume_crudos")

    source_path = f"/Volumes/{catalog}/{schema}/{volume}/consumo"

    return (
        spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "parquet")
        .option("recursiveFileLookup", "true")
        .option("pathGlobFilter", "*.parquet")
        .load(source_path)
        .withColumn(
            "periodo",
            F.regexp_extract("_metadata.file_path", r"periodo=(\d{4})", 1).cast("int")
        )
        .withColumn(
            "mes",
            F.regexp_extract("_metadata.file_path", r"mes=(\d{1,2})", 1).cast("int")
        )
        .withColumn(
            "region",
            F.regexp_extract("_metadata.file_path", r"region=(r\d+)", 1)
        )
    )

from pyspark import pipelines as dp


@dp.table(
    name="consumo_tmt",
    comment="Consumo filtrado por NIS del plan TMT."
)
def consumo_tmt():
    consumo = spark.readStream.table("consumo")
    tmt = spark.read.table("tmt").select("nis")
    return (
        consumo
        .join(tmt, consumo.LOCALIZACION.cast("string") == tmt.nis.cast("string"), "inner")
        .drop("nis")
    )

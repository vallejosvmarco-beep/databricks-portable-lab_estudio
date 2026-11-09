from pyspark import pipelines as dp


@dp.table(
    name="carga_tmt",
    comment="Carga filtrada por NIS del plan TMT."
)
def carga_tmt():
    carga = spark.readStream.table("carga")
    tmt = spark.read.table("tmt").select("nis")
    return (
        carga
        .join(tmt, carga.LOCALIZACION.cast("string") == tmt.nis.cast("string"), "inner")
        .drop("nis")
    )

from pyspark import pipelines as dp


@dp.table(
    name="carga_tmtb",
    comment="Carga filtrada por NIS del plan TMTB."
)
def carga_tmtb():
    carga = spark.readStream.table("carga")
    tmtb = spark.read.table("tmtb").select("nis")
    return (
        carga
        .join(tmtb, carga.LOCALIZACION.cast("string") == tmtb.nis.cast("string"), "inner")
        .drop("nis")
    )

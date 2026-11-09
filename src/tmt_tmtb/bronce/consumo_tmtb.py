from pyspark import pipelines as dp


@dp.table(
    name="consumo_tmtb",
    comment="Consumo filtrado por NIS del plan TMTB."
)
def consumo_tmtb():
    consumo = spark.readStream.table("consumo")
    tmtb = spark.read.table("tmtb").select("nis")
    return (
        consumo
        .join(tmtb, consumo.LOCALIZACION.cast("string") == tmtb.nis.cast("string"), "inner")
        .drop("nis")
    )

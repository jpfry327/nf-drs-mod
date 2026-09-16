#!/usr/bin/env nextflow

include { PIPELINE } from './workflows/pipeline'

workflow {
    if (!params.input) {
        error "Missing --input <samplesheet.csv>  (columns: sample,pod5_dir,condition)"
    }

    log.info """
    ${workflow.manifest.name} v${workflow.manifest.version}
      input   : ${params.input}
      outdir  : ${params.outdir}
      profile : ${workflow.profile}
    """.stripIndent()

    PIPELINE()
}

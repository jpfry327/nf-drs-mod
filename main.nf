#!/usr/bin/env nextflow

include { PIPELINE } from './workflows/pipeline'

workflow {
    if (!params.input) {
        error "Missing --input <samplesheet.csv>  (columns: sample,pod5_dir,condition)"
    }
    if (!params.reference) {
        error "Missing --reference <fasta>  (transcriptome or genome to align to)"
    }

    log.info """
    ${workflow.manifest.name} v${workflow.manifest.version}
      input   : ${params.input}
      outdir  : ${params.outdir}
      ref     : ${params.reference}
      model   : ${params.dorado_model}
      profile : ${workflow.profile}
    """.stripIndent()

    PIPELINE()
}

include { MULTIQC } from '../modules/lib/multiqc/main'
// ADD includes here:  modules/lib/<tool>/main  (scripts/module.sh add <tool>)
//                     modules/local/<tool>/main (hand-written, new-module skill)

// Samplesheet file cells: absolute paths and URIs are used as-is; relative paths resolve
// against the samplesheet's own directory, so a sheet + its files travel together.
def resolvePath(sheet, String p) {
    def f = (p.startsWith('/') || p.contains('://')) ? file(p) : sheet.parent.resolve(p)
    if (!f.exists()) error "Samplesheet ${sheet}: file not found: ${p}"
    return f
}

workflow PIPELINE {

    ch_versions = Channel.empty()

    //
    // 1. Samplesheet -> [ meta, pod5_dir ]
    //    Columns: sample, pod5_dir, condition.
    //    pod5_dir is a DIRECTORY of .pod5 files (one run / one sample), not a single file.
    //    USER-OWNED: add assay columns here AND in tests/data/samplesheet.csv together.
    //
    def sheet = file(params.input, checkIfExists: true)
    ch_samples = Channel
        .fromPath(sheet)
        .splitCsv(header: true)
        .map { row ->
            def meta = [ id: row.sample, condition: row.condition ]
            [ meta, resolvePath(sheet, row.pod5_dir) ]
        }

    // =====================================================================
    //  ADD YOUR ANALYSIS STEPS HERE
    //  - library module:  scripts/module.sh add <tool>   -> modules/lib/<tool>
    //  - one-off module:  new-module skill              -> modules/local/<tool>
    //  - keep every channel shaped [ meta, files ]
    //  - tool options / publishDir / container go in conf/modules.config
    // =====================================================================

    //
    // 2. Aggregate QC
    //
    ch_multiqc = Channel.empty()
        // .mix( TOOL.out.log.map { meta, f -> f } )
        .collect()
    MULTIQC( ch_multiqc )
    ch_versions = ch_versions.mix( MULTIQC.out.versions )

    //
    // 3. Versions
    //
    ch_versions
        .unique()
        .collectFile(name: 'software_versions.yml', storeDir: "${params.outdir}/pipeline_info")
}

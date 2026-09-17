include { MULTIQC           } from '../modules/lib/multiqc/main'
include { SAMTOOLS_INDEX    } from '../modules/lib/samtools/index/main'
include { DORADO_BASECALLER } from '../modules/local/dorado/basecaller/main'
include { DORADO_ALIGNER    } from '../modules/local/dorado/aligner/main'
include { SAMTOOLS_SORT     } from '../modules/local/samtools/sort/main'
include { SAMTOOLS_STATS    } from '../modules/local/samtools/stats/main'
include { MODKIT_PILEUP     } from '../modules/local/modkit/pileup/main'
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

    // Reference FASTA (transcriptome or genome) shared by the aligner and modkit.
    ch_reference = Channel.value( file(params.reference, checkIfExists: true) )

    // pod5 -> unaligned BAM with MM/ML modification tags (GPU)
    DORADO_BASECALLER( ch_samples, params.dorado_model )
    ch_versions = ch_versions.mix( DORADO_BASECALLER.out.versions.first() )

    // uBAM -> aligned BAM (dorado aligner = minimap2, keeps the mod tags)
    DORADO_ALIGNER( DORADO_BASECALLER.out.bam, ch_reference )
    ch_versions = ch_versions.mix( DORADO_ALIGNER.out.versions.first() )

    // sort + index; join on the whole meta map -> [ meta, bam, bai ]
    SAMTOOLS_SORT( DORADO_ALIGNER.out.bam )
    ch_versions = ch_versions.mix( SAMTOOLS_SORT.out.versions.first() )
    SAMTOOLS_INDEX( SAMTOOLS_SORT.out.bam )
    ch_versions = ch_versions.mix( SAMTOOLS_INDEX.out.versions.first() )
    ch_bam_bai = SAMTOOLS_SORT.out.bam.join( SAMTOOLS_INDEX.out.bai )

    // alignment QC (feeds MultiQC)
    SAMTOOLS_STATS( ch_bam_bai )
    ch_versions = ch_versions.mix( SAMTOOLS_STATS.out.versions.first() )

    // per-sample, per-site modification calls (bedMethyl)
    MODKIT_PILEUP( ch_bam_bai, ch_reference )
    ch_versions = ch_versions.mix( MODKIT_PILEUP.out.versions.first() )

    //
    // 2. Aggregate QC
    //
    ch_multiqc = Channel.empty()
        .mix( SAMTOOLS_STATS.out.stats.map { meta, f -> f } )
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

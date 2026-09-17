process DORADO_ALIGNER {
    tag "$meta.id"
    label 'process_high'

    // Josh supplies this (Seqera Containers or a .sif path). Override per pipeline in
    // conf/modules.config: withName: 'DORADO_ALIGNER' { container = '...' }
    container '<CONTAINER_URL>'

    input:
    tuple val(meta), path(bam)                // unaligned BAM from DORADO_BASECALLER (MM/ML tags kept)
    path  reference                           // FASTA (transcriptome or genome); minimap2 opts via ext.args --mm2-opts

    output:
    tuple val(meta), path("*.bam"), emit: bam     // aligned, unsorted
    path  "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    if ("$bam" == "${prefix}.bam") error "DORADO_ALIGNER: input and output are both ${prefix}.bam - set ext.prefix in conf/modules.config"
    """
    dorado aligner \\
        $args \\
        --threads $task.cpus \\
        ${reference} \\
        ${bam} \\
        > ${prefix}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dorado: \$( dorado --version 2>&1 | tail -n1 )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    if ("$bam" == "${prefix}.bam") error "DORADO_ALIGNER: input and output are both ${prefix}.bam - set ext.prefix in conf/modules.config"
    """
    touch ${prefix}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dorado: stub
    END_VERSIONS
    """
}

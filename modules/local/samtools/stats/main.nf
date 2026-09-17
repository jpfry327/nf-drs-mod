process SAMTOOLS_STATS {
    tag "$meta.id"
    label 'process_low'

    // Same image as the library's samtools/index (Josh's). Override per pipeline in
    // conf/modules.config: withName: 'SAMTOOLS_STATS' { container = '...' }
    container 'community.wave.seqera.io/library/htslib_samtools:1.24--d697cfb9dce007cd'

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("*.stats"), emit: stats    // MultiQC-parsable (samtools stats)
    path  "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    samtools stats \\
        $args \\
        -@ $task.cpus \\
        ${bam} \\
        > ${prefix}.stats

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -n1 | sed 's/samtools //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.stats

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: stub
    END_VERSIONS
    """
}

process SAMTOOLS_SORT {
    tag "$meta.id"
    label 'process_medium'

    // Same image as the library's samtools/index (Josh's). Override per pipeline in
    // conf/modules.config: withName: 'SAMTOOLS_SORT' { container = '...' }
    container 'community.wave.seqera.io/library/htslib_samtools:1.24--d697cfb9dce007cd'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*.bam"), emit: bam     // coordinate-sorted
    path  "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    if ("$bam" == "${prefix}.bam") error "SAMTOOLS_SORT: input and output are both ${prefix}.bam - set ext.prefix in conf/modules.config"
    """
    samtools sort \\
        $args \\
        -@ $task.cpus \\
        -T ${prefix} \\
        -o ${prefix}.bam \\
        ${bam}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -n1 | sed 's/samtools //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    if ("$bam" == "${prefix}.bam") error "SAMTOOLS_SORT: input and output are both ${prefix}.bam - set ext.prefix in conf/modules.config"
    """
    touch ${prefix}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: stub
    END_VERSIONS
    """
}

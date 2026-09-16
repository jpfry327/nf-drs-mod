process MODKIT_PILEUP {
    tag "$meta.id"
    label 'process_medium'

    // Josh supplies this (Seqera Containers or a .sif path). Override per pipeline in
    // conf/modules.config: withName: 'MODKIT_PILEUP' { container = '...' }
    container '<CONTAINER_URL>'

    input:
    tuple val(meta), path(bam), path(bai)     // sorted + indexed aligned BAM with MM/ML tags
    path  reference                           // FASTA the BAM was aligned to (modkit --ref)

    output:
    tuple val(meta), path("*.bedmethyl")  , emit: bed     // per-site modification counts / frequencies
    tuple val(meta), path("*.modkit.log") , emit: log
    path  "versions.yml"                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    modkit pileup \\
        $args \\
        --threads $task.cpus \\
        --ref ${reference} \\
        --log-filepath ${prefix}.modkit.log \\
        ${bam} \\
        ${prefix}.bedmethyl

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        modkit: \$( modkit --version 2>&1 | awk '{ print \$NF }' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.bedmethyl ${prefix}.modkit.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        modkit: stub
    END_VERSIONS
    """
}

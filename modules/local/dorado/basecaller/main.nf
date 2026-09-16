process DORADO_BASECALLER {
    tag "$meta.id"
    label 'process_high'
    label 'process_gpu'                       // conf/hpc.config keys the GPU queue / --nv off this

    // Josh supplies this (Seqera Containers or a .sif path). Override per pipeline in
    // conf/modules.config: withName: 'DORADO_BASECALLER' { container = '...' }
    container '<CONTAINER_URL>'

    input:
    tuple val(meta), path(pod5_dir)           // directory of .pod5 files for one sample
    val   model                               // model complex: 'sup,m6A,pseU' or 'rna004_130bps_sup@v5.2.0,m6A'

    output:
    tuple val(meta), path("*.bam"), emit: bam     // unaligned BAM carrying MM/ML modification tags
    path  "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    dorado basecaller \\
        $args \\
        ${model} \\
        ${pod5_dir} \\
        > ${prefix}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dorado: \$( dorado --version 2>&1 | tail -n1 )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dorado: stub
    END_VERSIONS
    """
}

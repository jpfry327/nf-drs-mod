process SAMTOOLS_INDEX {
    tag "$meta.id"
    label 'process_low'

    // Single image for docker and singularity (Nextflow prefixes docker:// as needed).
    // Override per pipeline in conf/modules.config: withName: 'SAMTOOLS_INDEX' { container = '...' }
    container 'community.wave.seqera.io/library/htslib_samtools:1.24--d697cfb9dce007cd'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*.bai"), emit: bai
    path  "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    samtools index -@ $task.cpus $bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -n1 | sed 's/samtools //')
    END_VERSIONS
    """

    stub:
    """
    touch ${bam}.bai

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: stub
    END_VERSIONS
    """
}

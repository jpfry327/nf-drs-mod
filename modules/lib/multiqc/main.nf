process MULTIQC {
    label 'process_low'

    // Single image for docker and singularity (Nextflow prefixes docker:// as needed).
    // Override per pipeline in conf/modules.config: withName: 'MULTIQC' { container = '...' }
    container 'community.wave.seqera.io/library/multiqc:1.35--c17fb751507e9dfc'

    input:
    path '*'

    output:
    path "multiqc_report.html", emit: report
    path "multiqc_data"       , emit: data
    path "versions.yml"       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    multiqc -f $args .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed -e "s/multiqc, version //g" )
    END_VERSIONS
    """

    stub:
    """
    mkdir multiqc_data
    touch multiqc_report.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: stub
    END_VERSIONS
    """
}

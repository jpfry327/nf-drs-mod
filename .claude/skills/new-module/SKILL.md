---
name: new-module
description: Write a hand-written (local) Nextflow DSL2 module in modules/local/<tool>/main.nf for this pipeline. Use when a tool is not in the personal library (github.com/jpfry327/nf-modules), when the user wants to wrap a script or command quickly, or says "write a module for", "wrap this script", "make a process for". Produces a module with meta tuple input, ext.args/ext.prefix, a container placeholder, versions.yml, and a stub block.
---

# Write a local module

## 0. Library first

Check https://github.com/jpfry327/nf-modules/tree/main/modules/jpfry327 (and
`scripts/module.sh list`). If the tool is there, install it (`wire-module` skill) instead.

## 1. Scaffold `modules/local/<tool>/main.nf`

Process name is UPPERCASE of the path (`samtools/index` → `SAMTOOLS_INDEX`, dir
`modules/local/samtools/index/`). Model:

```groovy
process TOOL_NAME {
    tag "$meta.id"
    label 'process_low'                       // process_single|low|medium|high (+ process_gpu)

    container '<CONTAINER_URL>'               // Josh supplies this (Seqera Containers or .sif path)

    input:
    tuple val(meta), path(reads)
    // path index                             // extra non-sample inputs as separate path/val lines

    output:
    tuple val(meta), path("*.out.txt"), emit: txt
    tuple val(meta), path("*.log")    , emit: log        // optional; MultiQC-parsable logs
    path "versions.yml"               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    tool run $args --threads $task.cpus --out ${prefix}.out.txt ${reads} 2> ${prefix}.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tool: \$( tool --version 2>&1 | sed 's/^.*version //' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.out.txt ${prefix}.log
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tool: stub
    END_VERSIONS
    """
}
```

Rules:
- **Container: write the literal placeholder `<CONTAINER_URL>`.** Josh supplies the real URL
  (Seqera Containers, or a `.sif` path). Never look one up, never guess a tag. If Josh has
  already given a URL in the conversation, use it verbatim.
- Sample channels in and out are `[ meta, files ]`; never read meta fields other than `meta.id`
  (and `meta.single_end` when the tool genuinely branches on it).
- No hardcoded flags: everything optional goes through `task.ext.args`; basenames via
  `task.ext.prefix`. Threads via `$task.cpus`.
- The stub must `touch` every declared output and must not call the tool.
- A script in `bin/` (bash/python/R, `chmod +x`) is on PATH inside every task; call it by name.
  That is the fast path for "run my script across samples".

## 2. Wire and configure

Follow the `wire-module` skill: include line (`'../modules/local/<tool>/main'`), call inside
the marked block, versions mix, `withName: 'TOOL_NAME' { ext.args = '...' }` in
`conf/modules.config`. For a custom `.sif`, set it in the module directly or override with
`container = '/path/to.sif'` in `conf/modules.config`.

## 3. Verify

Static: every output glob is produced by the script AND the stub; emits used in the workflow exist.
Then `docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work nextflow/nextflow:25.04.6 nextflow run . -profile test -stub-run`.

## Promote to the library (when it proves reusable)

Copy `modules/local/<tool>/` to `nf-modules/modules/jpfry327/<tool>/`, add a stub test there
(that repo's `new-module` skill), merge, then in the pipeline:
`scripts/module.sh add <tool>`, switch the include path to `modules/lib`, delete `modules/local/<tool>`.

## Report back

Files created, the process name and emits, the `withName` block added, and — always —
whether `<CONTAINER_URL>` is still a placeholder.

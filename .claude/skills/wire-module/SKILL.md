---
name: wire-module
description: Add an analysis step to this Nextflow pipeline. Use whenever the user wants to add, install, or chain a tool — an aligner, trimmer, QC step, caller, sorter, basecaller, etc. — into workflows/pipeline.nf, or names a bioinformatics tool to "add to the pipeline" (fastp, star, bwa, samtools, macs2, minimap2, bcftools, dorado, ...). Covers getting the module (library install or hand-written) and wiring it up.
---

# Wire a module into this pipeline

## 1. Get the module

Check what's already here, then the library:

```bash
scripts/module.sh list
```
Library index: https://github.com/jpfry327/nf-modules/tree/main/modules/jpfry327
(nested tools look like `samtools/index`, `star/align`).

- **In the library** → install it. The script prints the include line to paste.
  ```bash
  scripts/module.sh add <tool>              # main branch
  scripts/module.sh add <tool> --ref <sha>  # pin a commit
  ```
- **Not in the library** → use the `new-module` skill to write it in `modules/local/<tool>/`.
  Do not copy modules from nf-core/modules wholesale unless the user asks.

Never edit files under `modules/lib/` by hand and never hand-edit `modules.json`;
re-install with `--force` or `update` instead.

## 2. Wire it — file checklist

| Always | What |
|---|---|
| `workflows/pipeline.nf` | `include { TOOL } from '../modules/lib/<tool>/main'` (or `../modules/local/...`); call it inside the `ADD YOUR ANALYSIS STEPS HERE` block; keep every channel `[ meta, files ]`; `ch_versions = ch_versions.mix( TOOL.out.versions.first() )` |
| `conf/modules.config` | `withName: 'TOOL' { ext.args = '...' }` — add `ext.prefix`, `publishDir`, or `container` overrides only if needed |

| When applicable | What |
|---|---|
| New param (reference path, threshold) | `nextflow.config` `params {}` with a comment. Nowhere else. |
| Tool emits MultiQC-parsable output | `.mix( TOOL.out.<log>.map { meta, f -> f } )` in the `ch_multiqc` chain |
| Two channels need joining | `.join()` on `meta` (the whole map), never on a hardcoded field |
| GPU tool | module carries `label 'process_gpu'`; `conf/hpc.config` keys the GPU queue off it |
| Container URL missing (`<CONTAINER_URL>` in a local module) | leave the placeholder, report it |

**Do not change** the samplesheet columns or the `.map { row -> ... }` meta build in
`workflows/pipeline.nf`. If the tool needs a column that doesn't exist, stop and ask.

## 3. Verify

No Nextflow on the Mac. Statically: include path exists, every `.out.<emit>` you use is
declared in the module, input tuple shapes match. Then run the DAG through Docker:

```bash
docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work nextflow/nextflow:25.04.6 nextflow run . -profile test -stub-run
```

If the new step needs inputs the test samplesheet lacks, say so rather than editing the
samplesheet. On the HPC: `nextflow run . -profile test,hpc -stub-run`, then the real run.

## Report back

1. Module source: library (+ short SHA) or `modules/local`.
2. Files touched.
3. Params added to `nextflow.config`.
4. Open items: `<CONTAINER_URL>` placeholders, samplesheet columns needed, what needs real data.

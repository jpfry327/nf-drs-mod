# nf-drs-mod

Direct RNA-seq base modification pipeline. Takes Oxford Nanopore pod5 signal data per sample
and calls RNA base modifications, comparing across a `condition` grouping.

Design goals: know where everything goes, reuse modules from
[nf-modules](https://github.com/jpfry327/nf-modules) with full control, write one-off
modules in place, keep tests optional. No nf-schema, no nf-core CLI, no lint gates.
Add rigor per pipeline when one graduates to "publishable".

## Add a step
1. **Get a module.** From the library:
   ```bash
   scripts/module.sh add fastp              # -> modules/lib/fastp/main.nf, recorded in modules.json
   scripts/module.sh add samtools/index     # nested tools keep their path
   scripts/module.sh list | update --all | remove <tool>
   ```
   Or write a one-off in `modules/local/<tool>/main.nf` (the `new-module` Claude skill scaffolds
   it: meta tuple in, `ext.args`, `ext.prefix`, single `container`, stub block, versions.yml).
2. **Wire it** in `workflows/pipeline.nf` inside the `ADD YOUR ANALYSIS STEPS HERE` block
   (the `wire-module` Claude skill does steps 1–3). Keep channels `[ meta, files ]`.
3. **Configure it** in `conf/modules.config`: `withName: 'TOOL' { ext.args = '...' }`, plus
   `ext.prefix`, `publishDir`, or `container = '/path/to/custom.sif'` overrides as needed.
   New params go in `nextflow.config` `params {}` only.

## Run
```bash
# smoke-test the DAG anywhere Nextflow runs (no containers needed)
nextflow run . -profile test -stub-run

# on the Mac (no Nextflow installed): same thing through Docker
docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work nextflow/nextflow:25.04.6 nextflow run . -profile test -stub-run

# real runs
nextflow run . -profile test,docker                          # tiny run on a laptop
nextflow run . -profile hpc --input samplesheet.csv -stub-run # cluster dry run
nextflow run . -profile hpc --input samplesheet.csv           # cluster real run
```
Samplesheet columns: `sample,pod5_dir,condition`. `pod5_dir` is a **directory** of `.pod5`
files for that sample, not a single file; `condition` is carried through on `meta`. Relative
paths resolve against the samplesheet's directory. See `assets/samplesheet.csv`.

## Tests (optional)
- `-profile test -stub-run` is the always-available smoke test (`tests/data/`).
- `tests/pipeline.nf.test` is an [nf-test](https://www.nf-test.com) stub test; run `nf-test test`
  where nf-test is installed (HPC / CI). It needs no editing as the DAG grows.
- Graduating a pipeline: the `add-test` Claude skill covers more nf-test cases, a real-data
  `test_full` profile, and a CI snippet.

## Layout
```
main.nf                   entrypoint (arg check + summary + PIPELINE)
nextflow.config           params (ALL of them), profiles, manifest
conf/base.config          resources per label + resourceLimits
conf/modules.config       per-process ext.args / ext.prefix / publishDir / container   <- edit HERE
conf/hpc.config           cluster: slurm queues, caps, singularity cache, GPU label
conf/test.config          tiny samplesheet + small resource caps
workflows/pipeline.nf     your DAG (insertion point marked); samplesheet -> [ meta, pod5_dir ]
modules/lib/<tool>/       library modules, installed by scripts/module.sh (don't edit)
modules/local/<tool>/     hand-written one-off modules
modules.json              what's installed from the library, at which commit (script-managed)
scripts/module.sh         library module installer
tests/                    nf-test stub test + tests/data samplesheet and placeholder files
assets/samplesheet.csv    example samplesheet
.claude/skills/           wire-module, new-module, add-test
```

Reusable modules are authored (and tested) in
[nf-modules](https://github.com/jpfry327/nf-modules), then installed here. A `modules/local`
module that proves useful gets promoted there.

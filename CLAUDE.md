# nf-drs-mod — conventions

Direct RNA-seq base modification pipeline (ONT pod5 → modification calls). DAG today:
DORADO_BASECALLER → DORADO_ALIGNER → SAMTOOLS_SORT → SAMTOOLS_INDEX → { SAMTOOLS_STATS → MULTIQC,
MODKIT_PILEUP }. Per-sample only; the cross-condition step (modkit dmr) is not wired yet.
Most pipelines are quick workhorse runs; keep ceremony low. No nf-schema, no nf-core CLI.
Params live only in `nextflow.config`. See `README.md` for the human walkthrough.

## Where things go
| What | Where | How |
|---|---|---|
| Reusable module from the library | `modules/lib/<tool>/` | `scripts/module.sh add <tool>` — **never edit by hand**; re-install instead |
| One-off / hand-written module | `modules/local/<tool>/main.nf` | `new-module` skill |
| Wiring a step into the DAG | `workflows/pipeline.nf` (marked block) | `wire-module` skill |
| Tool flags, output names, publishDir, container overrides | `conf/modules.config` | `withName: 'TOOL' { ext.args = ... }` |
| New parameter | `nextflow.config` `params {}` only | comment it; that is the docs |
| Cluster / executor settings | `conf/hpc.config` | `-profile hpc` |
| Tests | `tests/`, `conf/test.config` | `add-test` skill |
| Pipeline overview diagram | `assets/metro_map.mmd` → `.svg` | `metro-map` skill (nf-metro) |

`modules.json` is written by `scripts/module.sh` — don't hand-edit it.

## Hard conventions (never violate)
- Channels are `[ meta, files ]`; key off `meta`, never hardcode meta field names in modules.
- Every module: one plain-string `container '...'` directive (works for docker and singularity);
  no conda directive, no engine ternary. Override per pipeline via `container = ...` in
  `conf/modules.config`.
- **Container URLs come from Josh** (Seqera Containers or a custom `.sif` path). When writing a
  module, put the literal placeholder `<CONTAINER_URL>` and report it as an open item.
  Never invent or guess an image tag.
- No hardcoded tool flags in modules: `task.ext.args`; output basenames via
  `task.ext.prefix ?: "${meta.id}"`.
- Every module has a `stub:` block touching every declared output, and emits `versions.yml`.
- Resource labels: `process_single|low|medium|high` (+ `process_gpu`). Caps via `resourceLimits`
  in `conf/base.config` / `conf/hpc.config`.

## User-owned — ask before changing
The samplesheet contract: its columns, and the `.map { row -> ... }` that builds `meta` in
`workflows/pipeline.nf`. If a step needs a column that doesn't exist, **stop and ask**.
When columns do change, `tests/data/samplesheet.csv` (and `assets/samplesheet.csv`) change in
lockstep.

## Gotchas
- **No Nextflow / Java on the dev Mac.** Verify statically, then run the stub DAG through Docker:
  `docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work nextflow/nextflow:25.04.6 nextflow run . -profile test -stub-run`
  Real runs happen on the HPC after cloning (`-profile test,hpc -stub-run`, then the real run).
- **GPU:** `label 'process_gpu'` is the switch; `conf/hpc.config` keys queue/`--gres`/`--nv` off it.
- Relative paths in a samplesheet resolve against the samplesheet's directory (see `resolvePath`).
- `-profile test` enables no container engine on purpose; combine (`test,docker`, `test,hpc`) for real runs.

## Verify checklist
1. `bash -n scripts/module.sh` if touched; include paths exist; every `.out.<emit>` used exists in the module.
2. Docker stub run above → succeeds; until a step is wired it publishes no files (MULTIQC is skipped).
3. HPC: `nextflow config . -profile hpc`, then `-profile test,hpc -stub-run`, then real data.

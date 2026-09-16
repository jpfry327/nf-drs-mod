---
name: add-test
description: Add or extend tests for this Nextflow pipeline — nf-test cases in tests/, a real-data test profile, keeping tests/data in sync with samplesheet changes, or a CI workflow. Use when the user says "add a test", "test this pipeline", "make this publishable", "set up CI", or after the samplesheet gains columns.
---

# Tests for this pipeline

Baseline that already exists: `conf/test.config` (tiny samplesheet in `tests/data/`, small
resource caps, no container engine) and `tests/pipeline.nf.test` (one nf-test stub test).
The stub test runs the whole DAG and never needs editing as steps are added — unless the
samplesheet contract changes. Keep tests proportional: quick pipelines get the stub test only.

## A. Samplesheet changed → keep tests/data in sync

If columns were added to `workflows/pipeline.nf`'s `.map { row -> ... }`, update
`tests/data/samplesheet.csv` (and `assets/samplesheet.csv`) with the new column, and `touch`
any new placeholder files under `tests/data/`. Rerun the stub test.

## B. More nf-test cases (`tests/*.nf.test`)

Add `test("...")` blocks to `tests/pipeline.nf.test`, or a new file per concern. Patterns:

```groovy
test("skip trimming") {                       // param variant
    options "-stub-run"
    when { params { input = "$projectDir/tests/data/samplesheet.csv"; outdir = "$outputDir"; skip_trim = true } }
    then {
        assert workflow.success
        assert !path("$outputDir/fastp").exists()
        assert workflow.trace.tasks().size() == 5     // task count as a cheap DAG assertion
    }
}
```
- Existence: `path("$outputDir/<dir>/<file>").exists()`; content: `.text.contains("...")`.
- Stable text outputs (real runs only): `snapshot(path("$outputDir/x.tsv")).match()`; snapshots
  land in `tests/*.nf.test.snap`; refresh with `nf-test test --update-snapshot`.
- Never snapshot stub outputs (empty files) or files with timestamps/paths inside.

## C. Real-data test profile (HPC)

Add `conf/test_full.config` pointing at small real inputs on the cluster, and a profile:

```groovy
// conf/test_full.config
params { input = '/projects/b1042/<project>/test/samplesheet.csv'; outdir = 'results-test-full' }
process { resourceLimits = [ cpus: 8, memory: 32.GB, time: 4.h ] }
```
```groovy
// nextflow.config profiles { ... }
test_full { includeConfig 'conf/test_full.config' }
```
Run: `nextflow run . -profile test_full,hpc`. A matching nf-test case uses `tag "full"` and
no `-stub-run`; run those with `nf-test test --tag full --profile hpc`.

## D. Running

| Where | Command |
|---|---|
| Mac (no Nextflow) | `docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work nextflow/nextflow:25.04.6 nextflow run . -profile test -stub-run` |
| HPC, smoke | `nextflow run . -profile test,hpc -stub-run` |
| HPC, nf-test | `nf-test test --tag stub` (install: `curl -fsSL https://get.nf-test.com \| bash`) |
| HPC, real tiny | `nextflow run . -profile test,hpc` |

## E. CI (only for pipelines that graduate)

`.github/workflows/test.yml`: checkout, `nf-core/setup-nextflow` action (or the docker image
above), `nf-test` install, `nf-test test --tag stub`. Stub tests need no containers, so this
runs on the free GitHub runner. Real-data tests stay on the HPC.

## Report back

Which of A–E was done, files touched, the exact command to run the new tests, and what could
only be verified statically on the Mac.

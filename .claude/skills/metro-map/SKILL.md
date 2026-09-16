---
name: metro-map
description: Draw this pipeline as an nf-metro metro-map SVG — a transit-style overview where each route through the workflow is a coloured line. Use whenever the user wants a visual overview, diagram, schematic, or figure of the pipeline, or says "metro map", "nf-metro", "SVG overview", "diagram the pipeline", "picture of the workflow", "figure for the README/paper/slides". Covers authoring assets/metro_map.mmd from workflows/pipeline.nf, the render–look–edit loop, and the README embed.
---

# Metro map of this pipeline

The map is a **faithfulness exercise**: it should read as the same pipeline a developer
sees in `workflows/pipeline.nf`. Get the model right first, then fight the layout.

Source of truth is the workflow code, not a Nextflow DAG export. `nf-metro convert`
/ `--from-nextflow` exists, but its own docs say it rarely produces a good diagram for
anything past a few subworkflows. Read `workflows/pipeline.nf` instead — it's right here
and it's more accurate. (Where Nextflow *is* available, `nextflow run . -preview
-with-dag dag.mmd` can be a sanity check that you modelled every process, but hand-author
the map regardless.)

## 0. Check nf-metro is here

```bash
nf-metro --version
```

Assume it's on `PATH` — Josh starts Claude Code from an env that has it. **If it's not
found, stop and say so.** Don't install it, don't hunt through mamba envs, don't fall back
to Docker: just report that nf-metro isn't on `PATH` so Josh can restart from the right
env. Everything else in this skill needs it, so there's nothing useful to do first.

## 1. Files

| What | Where |
|---|---|
| Source (committed, hand-edited) | `assets/metro_map.mmd` |
| Rendered static SVG (committed) | `assets/metro_map.svg` |
| Regeneration command | a `%%` comment header in the `.mmd` |

Animated SVG, PNG (`--raster-width 2265` for slides/print), or interactive
`--format html` only when the user asks. Don't create a `docs/` tree for this.

## 2. Model the pipeline

Read `workflows/pipeline.nf` end to end — the `ADD YOUR ANALYSIS STEPS HERE` block, the
`ch_multiqc` mix chain, and the samplesheet `.map { row -> ... }` (its columns tell you
what the real inputs are). Check `conf/modules.config` for steps that are conditional or
renamed via `ext.prefix`. Then decide:

- **Stations** = the processes a user would recognise (`FASTQC`, `MULTIQC`, each wired
  tool). One station per module call, labelled with the tool's human name, not the
  Nextflow process name in caps.
- **Lines** = routes through the pipeline, 1–4 for most of these. A main sample path plus
  a dashed QC/reporting line covers the common case. Two inputs that flow through
  identical modules end to end are one line, not two (e.g. single- vs paired-end).
- **Sections** = phases (`Input`, `Analysis`, `Reporting`). Grid-place them with
  `%%metro grid: <section> | <col>,<row>` — **col first, then row**.
- **File icons** = samplesheet, reference genomes, and other file inputs, as
  `%%metro file: <id> | <EXT> | <Label>` on an empty-label station `id[ ]`.

**Accuracy rule:** a station sits on a line only if that module actually consumes that
line's data. A line drawn through a station that doesn't process it ("breeze-past") is
the single most common modelling bug. Audit every edge label against the channel wiring.

Sensible simplifications are fine — eliding a one-off helper module, merging two trivially
similar inputs — but say which ones you made when you report back.

## 3. Skeleton

```text
%% Regenerate: nf-metro render assets/metro_map.mmd -o assets/metro_map.svg --theme light
%%metro title: <pipeline name from nextflow.config manifest>
%%metro line: main | Samples | #4CAF50
%%metro line: qc | QC reports | #2196F3 | dashed
%%metro line_order: definition

%%metro file: sheet | CSV | Samplesheet
%%metro file: reads | FASTQ | Reads
%%metro grid: input | 0,0
%%metro grid: analysis | 1,0
%%metro grid: report | 2,0

graph LR
    subgraph input[Input]
        sheet[ ]
        reads[ ]
    end
    subgraph analysis[Analysis]
        fastqc[FastQC]
    end
    subgraph report[Reporting]
        multiqc[MultiQC]
    end

    sheet -->|main| reads
    reads -->|main| fastqc
    fastqc -->|qc| multiqc
```

Inter-section edges go **outside** every `subgraph`/`end` block.

Directives worth knowing beyond these: `%%metro files:` (stacked/batched inputs),
`%%metro dir:` (folder icon), `%%metro off_track: <id>` (optional input that shouldn't
drag the trunk line into it), `%%metro interchange:`, `%%metro marker:` (flag a station),
`%%metro caption:` (attribution line), `%%metro legend:`, `%%metro logo:`. Full reference:
https://seqeralabs.github.io/nf-metro/latest/guide/#directive-reference

## 4. Render, look, edit

```bash
nf-metro validate assets/metro_map.mmd
nf-metro render assets/metro_map.mmd \
    -o assets/metro_map.svg --theme light
```

**Actually look at the result** — render a PNG to a scratch path and Read it as an image.
A map that validates can still be unreadable, and that's the whole point of the artifact.

```bash
nf-metro render assets/metro_map.mmd \
    -o /tmp/.../check.png --raster-width 1400 --theme light
```

Iterate on: stations on lines they don't consume, crossings that could be untangled by
reordering `%%metro line:` declarations, sections that are over- or under-sized for their
contents. `--debug` draws grid lines and bboxes; `nf-metro info` summarises what was
parsed; `nf-metro explain` says why the engine placed things where it did.

**Don't pass `--x-spacing`/`--y-spacing` unless a render actually looks cramped.** The
engine picks safe values; an explicit spacing below the minimum a graph needs earns a
warning and collided labels. (The nf-core baseline of `60 40` is too tight for a small
map with file icons.) `--center-ports` reduces kinks at section boundaries;
`--line-order definition` keeps lines stacked in declaration order.

## 5. README

Once it reads right, embed it near the top of `README.md`:

```html
<img src="assets/metro_map.svg" alt="<pipeline> pipeline overview" width="100%">
```

## Keeping it current

The map goes stale the moment a step is added. When the `wire-module` skill adds a tool to
`workflows/pipeline.nf`, add the station here and re-render in the same change.

## Gotchas

- `%%metro grid:` is `col,row` — nf-metro's own authoring skill documents it backwards.
- An empty-label station (`id[ ]`) needs a matching `%%metro file:`/`files:`/`dir:`
  directive, or it renders as a nameless dot. `validate` won't catch this — looking will.
- Plain `%%` lines (not `%%metro`) are comments and are safe to leave in the file.
- nf-metro 2.1.0 already writes a trailing newline; the `sed` normalisation step in the
  nf-core setup docs is unnecessary here.
- Container URLs, module internals, and `ext.args` are invisible on the map by design —
  it's an overview, not a config dump. Don't try to encode flags into station labels.

## Report back

1. `assets/metro_map.mmd` + `assets/metro_map.svg`, and whether README was touched.
2. The lines you chose and what each represents.
3. Simplifications you made (elided modules, merged inputs).
4. Anything in the workflow you couldn't model confidently — conditional paths especially.

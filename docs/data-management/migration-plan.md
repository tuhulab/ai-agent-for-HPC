# Migration Plan — What to Migrate (Prioritized)

Categorization of every pending Computerome item by **data type**, with a clear
**migrate / regenerate / version-in-git** decision. "Raw" = irreplaceable
sequencing data → **highest priority**. "Reference" = re-download. "Intermediate"
= reproducible (skip unless cheap). "Code" = version in GitHub instead.

Legend:
- 🟢 **MIGRATE** — raw / irreplaceable
- 🔴 **REDOWNLOAD** — reference genomes, re-fetch from public source
- 🟡 **ANALYZE** — intermediate/reproducible; migrate only if you want to keep
  (often huge, skip to save time/space)
- 🔵 **GITHUB** — code/scripts -> commit to a repo, do not bulk-migrate

---

## A. Need verification / unknown destination (check first)

> **Update (2026-08-27):** The demultiplexed fastq for `sequencing_thomas` and
> `TB-FLEX-total-lung`/`sequencing_total_lung` have been found already migrated to
> `/work/TB group/` (`sequencing_data_endothelial` 671G, `sequencing_data_totallung` 1009G).
> The raw BCL run folders (`231212` endothelial, `231219` totallung, `adjuvant04`)
> are **NOT to be migrated** — ✅ **decided: demultiplexed fastq is sufficient**.
> These sections are therefore closed.

Shared `data/` — **resolved** (fastq migrated, raw BCL not needed):

| Path | Size | Type | Action |
|---|---|---|---|
| `data/sequencing_thomas` (Endothelial — `fastq_TB-02_i5RC`) | 671G fastq | 🟢 RAW fastq | ✅ migrated → `/work/TB group/sequencing_data_endothelial` |
| `data/sequencing_thomas` raw BCL run `231212_A01428_0443_AHJ5GVDSX3` | ~600G | 🟢 RAW BCL | ✅ **decided: not needed** (demux fastq sufficient) |
| `data/TB-FLEX-total-lung` + `sequencing_total_lung` (pool fastq pool_1-4) | 1009G | 🟢 RAW fastq | ✅ migrated → `/work/TB group/sequencing_data_totallung` |
| `data/sequencing_total_lung` raw BCL run `231219_A01428_0446_AHJHLCDSX3` | ~550G | 🟢 RAW BCL | ✅ **decided: not needed** (demux fastq sufficient) |
| `data/adjuvant04` (raw BCL run) | 39G | 🟢 RAW BCL | ✅ **decided: not needed** (demux fastq sufficient) |

## B. Raw — migrate (from julzim `people/s144334`)

| Path | Size | Notes |
|---|---|---|
| `data/GEO/F2859` | 187 G | fastq (F2859_Alum/CAF01/HA/control...) + count matrices |
| `data/GEO/F2907` | 558 G | fastq + count matrices (GEO submission) |
| `data/GEO/F2702` | 20 G | fastq + counts |
| `data/GEO/F2833` | 43 G | fastq (scRNAseq) |
| `data/TI_F2768` (`raw_files`, `fastq_files`, `RNA_seq`) | 136 G | 🟢 fastq + 🟡 RNA_seq |
| `data/rhapsody_F2833` (`fastq_files` + 2×Undetermined) | 55 G | 🟢 fastq |
| `data/YFP_F2702` (`fastq_files`) | 43 G | 🟢 fastq (adapterremoval + test are intermediate) |
| `data/230315_A00962_0093_BHYG7TDRX2` + `.zip` | 73 G | raw BCL run |
| `results/10x_F2853_F2859_F2866/fastq_files` | (part of 863 G) | 🟢 raw fastq |

## C. Intermediate / reproducible — ANALYZE (huge, often skip)

| Path | Size | What it is |
|---|---|---|
| `people/s144334/projects/F2859, F2866, F2907` | 713 G total | cellranger count outputs (`*_Alum_HA`, `*_control`...) |
| `people/s144334/results/10x_F2853_F2859_F2866` | 863 G | `cellranger_count`, `fastqc` (the `fastq_files` subdir is raw — see B) |
| `people/s144334/results/YFP_F2702` | 165 G | bam, counts, trimmed fastq |
| `people/s144334/results/xDC_thesis` | 21 G | counts, trimmed, QC |
| `people/s144334/data/F2853_F2859_F2866` + top-level `F2853_F2859_F2866` | 383 G + 6.6 M | cellranger/count intermediates + metadata |
| katwor `F2902_counts_B` (27 G), `F2902_counts_C` (104 G) | 131 G | cellranger counts (reproducible from fastq) |
| `people/s144334/F2867` | 632 M | 2 CSVs (small — just migrate for completeness) |

## D. Raw (katwor) — migrate

| Path | Size | Notes |
|---|---|---|
| `people/katwor/experiments/F2902/data/F2902_F2907_fastqfiles_v2` | **835 G** | 🟢 RAW demultiplexed fastq (4 lanes) — **biggest single raw item** |

## E. Reference genomes — REDOWNLOAD (do not copy)

| Path | Size |
|---|---|
| `people/s144334/data/mouse_genome` | 32 G (GRCm38, refdata-gex-mm10-2020-A) |
| `data/_reference` | 37 G (GRCh38, GRCm39, macaque, probe sets) |
| katwor `data/refdata-gex-mm10-2020-A` | 15 G |

## F. Code / scripts — GITHUB (do not bulk migrate)

- `people/s144334/src/` (~19 M): nextflow, RNA_seq, 10x, bcl2fastq scripts
- katwor `bcl2fastq_scrpt.sh`, `cellranger_count.sh` + `.o/.e` logs
- All `_cache_*`, nextflow `work/`, `_test_fetchngs*` (tuhu home) — cache, skip

## G. tuhu home workspaces (outside project)

`10xFLEX`, `adpso_endotypes_federated`, `bd_rhapsody_velocyto`,
`GSE200151_granuloma`, `guide-nextflow-scRNA-seq`, `INFIMM-*`, `kelvin_collaboration`,
`TB-Endothelial`, `_cache_*`, `_download`, `_test_fetchngs*`

→ Mostly code/renv/nextflow caches. 🔵 version code in GitHub; 🟡 re-derive data
from migrated raw fastq. **Decide scope** — most is outside the raw-data mandate.

---

## Recommended execution order

1. ~~Verify unknowns (Section A)~~ — **done**: `sequencing_thomas` and
   `TB-FLEX-total-lung`/`sequencing_total_lung` fastq are already on
   `/work/TB group`; raw BCL decided not needed.
2. **Migrate katwor F2902 fastq (835 G)** — largest single raw dataset.
3. **Migrate julzim GEO (808 G)** — raw fastq needed for publication submission.
4. **Migrate remaining julzim raw** (TI_F2768, rhapsody_F2833, YFP fastq, BHYG run).
5. **Skip/re-derive intermediates** (projects/, most results/) unless explicitly needed.
6. **Re-download references** (Section E) rather than copy.
7. **Version code** (Section F/G) in this GitHub repo.

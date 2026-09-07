# Computerome — Source Inventory (`cu_10181`)

> Snapshot taken live over SFTP (`transfer.computerome.dk`, user `tuhu`) on
> 2026-08-27. Sizes are approximate (`du` output). **2FA required for access.**

## Project root: `/home/projects/cu_10181/`

```
├── apps/
├── archive/
├── data/          4.6 TB  (shared sequencing data, tuhu-owned)
├── people/
│   ├── s144334/   ~3.9 TB (julzim)
│   ├── katwor/     980 GB (experiments/F2902)
│   ├── tuhu/       (cache only in project; bulk lives in home dir)
│   ├── mehbak/     (migration tooling + the *_dir.txt listings)
│   └── ninngu/
└── scratch/
```

---

## `data/` — shared sequencing data (4.6 TB)

| Path | Size | Migrated? |
|---|---|---|
| `sc_CAF01_CAF08b_CAF39` | 105 M | ✅ `sc_CAF01_CAF08b_CAF39` |
| `_reference` | 37 G | ❓ (reference genomes, incl. mouse genome) |
| `adjuvant04` | 39 G | ❓ |
| `sc_F2857_flex_ssi` | 73 G | ✅ `sc_F2857_flex_ssi` |
| `chlamydia-01` | 95 G | ✅ → `chlamydia-01-bcl` |
| `chlamydia-01-fastq` | 117 G | ✅ `chlamydia-01-fastq` |
| `sc_f2853_ssi` | 426 G | ✅ `sc_f2853_ssi` |
| `adj_02_03` | 485 G | ✅ `adj_02_03` |
| `sequencing_total_lung` | 550 G | ❓ → `total_lung_*` |
| `sc_F2853_F2859_F2866_ssi` | 585 G | ✅ `sc_F2853_F2859_F2866_ssi` |
| `TB-FLEX-total-lung` | 1.1 T | ❓ → `total_lung_*` |
| `sequencing_thomas` | 1.2 T | ❓ (endothelial) |

---

## `people/s144334/` — julzim (~3.9 TB)

### `data/` (~1.8 TB)

| Path | Size | Migrated? |
|---|---|---|
| `xDC_thesis` | 23 G | ✅ `xDC_thesis` |
| `mouse_genome` | 32 G | ❓ |
| `rhapsody_F2766` | 35 G | ✅ `rhapsody_F2766` |
| `230315_A00962_0093_BHYG7TDRX2.zip` | 36 G | ❓ |
| `230315_A00962_0093_BHYG7TDRX2` | 37 G | ❓ (BCL run) |
| `YFP_F2702` | 43 G | ❓ |
| `rhapsody_F2833` | 55 G | ❓ |
| `TI_F2768` | 136 G | ❓ |
| `10x_F2795` | 219 G | ✅ `10x_F2795` |
| `F2853_F2859_F2866` | 383 G | ❓ |
| `GEO` | 807 G | ❓ |

`GEO/` breakdown:

| Path | Size |
|---|---|
| `GEO/F2702` | 20 G |
| `GEO/F2833` | 43 G |
| `GEO/F2859` | 187 G |
| `GEO/F2907` | 558 G |

### `results/` (~1.1 TB)

| Path | Size | Migrated? |
|---|---|---|
| `rhapsody_F2766` | 2.0 M | ✅ |
| `TI_F2768` | 22 M | ❓ |
| `xDC_thesis` | 21 G | ❓ |
| `10x_F2795` | 52 G | ✅ |
| `YFP_F2702` | 165 G | ❓ |
| `10x_F2853_F2859_F2866` | 863 G | ❓ |

### `projects/` (~713 GB)

| Path | Size |
|---|---|
| `projects/F2866` | 130 G |
| `projects/F2859` | 146 G |
| `projects/F2907` | 437 G |

### Other top-level (s144334)

| Path | Size | Migrated? |
|---|---|---|
| `F2853_F2859_F2866` | 6.6 M | ❓ |
| `F2867` | 632 M | ❓ (2× 316 M CSVs) |
| `src` | 19 M | ❓ |

---

## `people/katwor/` — 980 GB

```
experiments/F2902/  980 GB
├── analyse/   (1 K)
└── data/      (980 G)
```

`katwor_dir.txt` (the source listing) shows this corresponds to
`data/F2902_counts_B`, `data/F2902_counts_C`, `data/F2902_F2907_fastqfiles_v2`
(~83 G undetermined fastq ×4 lanes) and `data/refdata-gex-mm10-2020-A`.

**Not seen migrated** under any matching name in `/work/data_migration`. ❓

---

## `people/tuhu/`

Only `_cache_R` (~18 K) lives in the project `people/tuhu/` dir. Tuhu's analysis
workspaces (per `tuhu_dir.txt`), e.g.:

- `10xFLEX`, `adpso_endotypes_federated`
- `bd_rhapsody_velocyto`
- `GSE200151_granuloma`, `guide-nextflow-scRNA-seq`
- `INFIMM-caf01_caf08b_caf39`, `INFIMM-TB-F2853`, `INFIMM-TB-FLEX`,
  `INFIMM-TB-MINCLE`, `kelvin_collaboration`, `TB-Endothelial`, `TB-FLEX-total-lung`
- `_cache_nextflow`, `_cache_R`, `_cache_singularity`, `_cache_vscode`,
  `_download`, `_test_fetchngs*`

are in tuhu's **home directory** (`/home/people/tuhu/`), which is outside the
project `cu_10181`. Most of these are **not** present in `/work/data_migration`.

> ⚠️ **Needs live confirmation** of the exact home-dir location and whether these
> workspaces should be migrated (many are code/work directories rather than raw
> sequencing data).

---

## Migrated-destination state

Target: `/work/data_migration` on UCloud (~3.5 TB). Full mapping is in
[`migration-status.md`](migration-status.md).

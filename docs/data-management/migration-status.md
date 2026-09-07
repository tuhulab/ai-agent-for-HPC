# Migration Status: Computerome → `/work/data_migration` (UCloud)

Comparison of source (`/home/projects/cu_10181/` on Computerome) against the
destination (`/work/data_migration` on UCloud). Destination ≈ **3.5 TB**.

Legend: ✅ migrated · ❓ source present, destination not confirmed · ⚠️ needs
decision/confirmation.

## Already migrated (source → destination, noting renames)

| Source (Computerome) | Destination (`/work/data_migration`) | Notes |
|---|---|---|
| `data/sc_CAF01_CAF08b_CAF39` | `sc_CAF01_CAF08b_CAF39` | same name |
| `data/sc_F2857_flex_ssi` | `sc_F2857_flex_ssi` | same name |
| `data/chlamydia-01` | `chlamydia-01-bcl` | **renamed** (-bcl) |
| `data/chlamydia-01-fastq` | `chlamydia-01-fastq` | same name |
| `data/sc_f2853_ssi` | `sc_f2853_ssi` | same name |
| `data/adj_02_03` | `adj_02_03` | same name |
| `data/sc_F2853_F2859_F2866_ssi` | `sc_F2853_F2859_F2866_ssi` | same name |
| `people/s144334/data/10x_F2795` + `results/10x_F2795` | `10x_F2795` | data+results merged |
| `people/s144334/data/rhapsody_F2766` + `results/rhapsody_F2766` | `rhapsody_F2766` | |
| `people/s144334/data/xDC_thesis` | `xDC_thesis` | |
| `data/sequencing_total_lung` / `data/TB-FLEX-total-lung` | `total_lung_TBD*`, `total_lung_AdTx` | spread across several `total_lung_*` dirs |
| `data/sequencing_thomas` (endothelial) | `total_lung_AdTx`? | ⚠️ confirm |
| `people/mehbak/*_dir.txt`, md5s, rsync logs | `bash_scripts/`, `*.dir.txt` | migration tooling preserved |

Independently added on the destination (newer data, not in the original 2023–24
source listings): `Adj-05_SHLL_*`, `Adj_05_fastq*`, `iBALT_RORgt_Adtx_*`,
`imaging_data_F2977_F3015_iBALT`, `10x_F2805`, `project_caf39`, `Trash`.

### Resolved via `/work/TB group` & `/work/Adjuvant group` (new destination dirs, 2026-08-27)

| Source (Computerome) | Destination | Status |
|---|---|---|
| `data/sequencing_thomas` demux fastq (`fastq_TB-02_i5RC`) | `/work/TB group/sequencing_data_endothelial/` (671G, Endothelial_01-16 fastq + checksums.md5) | ✅ fastq migrated |
| `data/sequencing_thomas` raw BCL run `231212_A01428_0443_AHJ5GVDSX3` | — | ✅ **decided: not needed** (demux fastq sufficient) |
| `data/TB-FLEX-total-lung` + `sequencing_total_lung` (pool fastq) | `/work/TB group/sequencing_data_totallung/` (1009G, pool_1-4 fastq) | ✅ fastq migrated |
| `data/sequencing_total_lung` raw BCL run `231219_A01428_0446_AHJHLCDSX3` | — | ✅ **decided: not needed** (demux fastq sufficient) |
| `data/adjuvant04` (raw BCL run, 39G) | — (only Adj-05 demux fastq & F2964/F2965 analysis present) | ✅ **decided: not needed** (demux fastq sufficient) |
| julzim `data/GEO/*`, `TI_F2768`, `YFP_F2702`, `rhapsody_F2833`, BHYG run, katwor F2902 | not in these group dirs | ❓ still pending (see plan) |

> ✅ **Decision (2026-08-27):** demultiplexed fastq is sufficient for these three shared datasets. The raw BCL runs (`231212` endothelial, `231219` totallung, `adjuvant04`) are **not to be migrated** — fastq preserved on `/work/TB group`. The `total_lung_*_bcl`/`total_lung_AdTx` dirs on `/work/data_migration` are newer 2026 runs and are unrelated.

## Decisions & destination policy (2026-08-27)

- **All migrated data goes to `/work/data_migration`** (nothing goes directly to
  `/work/TB group` or `/work/Adjuvant group` on migration).
- **Julie (julzim) raw BCL runs ARE necessary** to migrate (e.g. `BHYG7TDRX2`).
- **TB-group raw BCL is NOT necessary** (demux fastq already migrated to
  `/work/TB group`; quality checked).
- **Checked `/work/Adjuvant group`**: it contains only F2925 fastq and an
  `F2859_Influenza_CAF09b_JUZI_KAWO` analysis — the julzim raw fastq (GEO
  F2859/F2907/F2702/F2833, TI_F2768, rhapsody_F2833, YFP_F2702) is **NOT**
  there, so those still need to be migrated to `/data_migration`.

## Not yet migrated / to confirm (candidates)

### julzim (`people/s144334`, ~3.9 TB)
| Path | Size | Status |
|---|---|---|
| `data/GEO/` (F2702, F2833, F2859, F2907) | 807 G | ❓ |
| `data/TI_F2768` | 136 G | ❓ |
| `data/YFP_F2702` | 43 G | ❓ |
| `data/mouse_genome` (+ `_reference`) | 32 G | ❓ |
| `data/rhapsody_F2833` | 55 G | ❓ |
| `data/230315_A00962_0093_BHYG7TDRX2` + `.zip` | 73 G | ❓ |
| `data/F2853_F2859_F2866` | 383 G | ❓ |
| `results/10x_F2853_F2859_F2866` | 863 G | ❓ |
| `results/YFP_F2702` | 165 G | ❓ |
| `results/TI_F2768`, `results/xDC_thesis` | ~21 G | ❓ |
| `projects/F2859, F2866, F2907` | 713 G | ❓ |
| `F2867`, `F2853_F2859_F2866`, `src` | ~656 M | ❓ |

### katwor (`people/katwor`, 980 GB)
| Path | Size | Status |
|---|---|---|
| `experiments/F2902/data` (counts B/C, fastqfiles_v2, refdata) | 980 G | ❓ |

### Shared `data/`
| Path | Size | Status |
|---|---|---|
| `_reference` | 37 G | ⚠️ reference genomes — confirm needed |
| `adjuvant04` | 39 G | ⚠️ confirm |
| `sequencing_thomas` (endothelial) | 1.2 T | ⚠️ confirm destination |

### tuhu home workspaces (`/home/people/tuhu`)
`10xFLEX`, `adpso_endotypes_federated`, `bd_rhapsody_velocyto`,
`GSE200151_granuloma`, `guide-nextflow-scRNA-seq`, `INFIMM-caf01_caf08b_caf39`,
`INFIMM-TB-F2853`, `INFIMM-TB-FLEX`, `INFIMM-TB-MINCLE`, `kelvin_collaboration`,
`TB-Endothelial`, `TB-FLEX-total-lung`, `_cache_*`, `_download`, `_test_fetchngs*`.

⚠️ Mostly code/work/renv directories, not raw sequence. **Decision needed** on
whether these are in scope for migration.

## Recommended next steps

1. Re-establish Computerome access (2FA available) and pull a **full recursive
   listing** of `people/s144334`, `people/katwor`, `data/` to double-check the
   "not migrated" candidates (some may already be copied elsewhere).
2. Confirm the ambiguous `total_lung_*` / `sequencing_thomas` mapping.
3. Decide scope for tuhu home-dir workspaces and reference genomes.
4. For each ❓ candidate: run `rsync`/`rclone` with the same md5-verification
   workflow used previously (see `bash_scripts/` on the destination).

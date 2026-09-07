# TB Group Working Drive (`/work/TB group/`) — Directory Inventory & Catalog

**Location**: SDU eScience Center UCloud (`BINF INFIMM` workspace)  
**Mount Point**: `/work/TB group/` (WekaFS persistent shared drive)  
**Total Storage**: **5643.01 GB** (5.51 TB) across **957,970 files** in **29 directories**  
**Last Surveyed**: September 2026  

---

## 📊 Executive Summary

| Modality / Category | Dirs | Total Size | Total Files | Key Formats |
|---|---|---|---|---|
| **Raw Sequencing Data (FASTQ)** | 3 | 1,823.8 GB (1.78 TB) | 264 | `.fastq.gz`, `.md5`, `.tsv` |
| **Raw Microscopy & Imaging Slides** | 9 | 2,479.9 GB (2.42 TB) | 12,279 | `.czi`, `.lif`, `.tif`, `.npy` |
| **Histology & Spatial Analysis (QuPath / Python)** | 6 | 355.2 GB (0.35 TB) | 594,303 | `.qpproj`, `.qpdata`, `.json`, `.csv`, `.py` |
| **Single-Cell Transcriptomics Analysis & Objects** | 11 | 545.1 GB (0.53 TB) | 275,125 | `.h5ad`, `.rds`, `.h5`, `.csv`, `.r`, `.py` |
| **Total** | **29** | **5643.01 GB (5.51 TB)** | **957,970** | |

---

## 📁 Complete Directory Catalog

| # | Directory Name | Type / Modality | Sample IDs / Tags | Size & Files | Key Contents & Purpose | Key Formats | Suggested Actions |
|---|---|---|---|---|---|---|---|
| **1** | `NAFP Image analysis` | Histology & Image Analysis (QuPath) | CD31, CD312, CD313 | 9.5 GB<br>(9,709 files) | Central QuPath project hub containing classifiers, annotations (HEV, iBALT, neutrophils, B-cell aggregates), and MFI measurement tables. | `.json`, `.jpg`, `.qpdata` | High value — backup to Data_backup. Clean up redundant project copies (e.g. (copy 1), with comb HEV(2)). |
| **2** | `QuPath Analysis F2944` | Histology & Image Analysis (QuPath) | F2944 | 0.5 GB<br>(735 files) | Standalone QuPath project for F2944 slide series + export tables measurements.csv and measurements2.csv. | `.json`, `.qpdata`, `.jpg` | Consolidate with NAFP Image analysis or maintain as standalone project; ensure measurement CSVs are backed up. |
| **3** | `QuPath Analysis F2944(1)` | Histology & Image Analysis (QuPath) | F2944 | 0.0 GB<br>(707 files) | Duplicate / unfinished copy of the F2944 QuPath project without measurement exports. | `.json`, `.jpg`, `.qpdata` | Candidate for removal / archiving to Trash after verifying no unique annotations exist. |
| **4** | `TB-Endothelial` | Single-Cell Analysis Project | CD86, Endothelial, cd3679, f0098, f0318, f1087, f1096, f1127 | 0.9 GB<br>(24,239 files) | Specialized R analysis pipeline for pulmonary endothelial subset heterogeneity (1,855 .rds objects + renv lock). | `.hpp`, `.rds`, `(no ext)` | Push git repo. Backup final integrated endothelial Seurat object. |
| **5** | `TB-VIT` | Single-Cell Analysis Project | CD0, CD8744, Cd27, F2662, F3363, F4327, F6413, F6462 | 10.1 GB<br>(7,700 files) | 742 .rds Seurat objects, R scripts, Jupyter notebooks, and differential expression results for vaccinated/infected lung cohorts. | `(no ext)`, `.r`, `.rds` | Backup code and key .rds objects. Push git repo to GitHub. |
| **6** | `TB-scverse` | Microscopy & Raw Imaging Data | CD103, CD4, Cd103, cd0, cd10, cd103, cd12, cd4 | 20.7 GB<br>(29,388 files) | Scverse/Scanpy workflow repository containing cross-species integration (NHP vs human), CellxGene visualization configs, and .venv. | `.py`, `.pyc`, `(no ext)` | Push git commits. Clean up virtualenv cache (.venv/__pycache__) prior to backup. |
| **7** | `TB-total-lung` | Microscopy & Raw Imaging Data | CD077815, CD7, Cd27, F0806, F1136, F1983, F2181, F2229 | 25.8 GB<br>(54,219 files) | R/Seurat single-cell pipeline with 4,394 .rds objects, renv lockfile, QC scripts, and figures. | `.hpp`, `(no ext)`, `.rds` | Push git commits. Backup finalized .rds Seurat objects; renv cache can be excluded from backup. |
| **8** | `TB_TL` | Single-Cell Analysis Project | Cd19, Cd226, Cd3, Cd4, Cd40, Cd74, Cd79, Cd8 | 173.6 GB<br>(770 files) | 31 large AnnData (.h5ad) objects across lung immune lineages, clustering plots, marker CSVs, and Git-tracked analysis repo. | `.png`, `(no ext)`, `.csv` | High priority backup. Ensure git commits are pushed to remote repo; backup .h5ad objects in Data_backup. |
| **9** | `TB_TL_AdTx_F2998_F3035` | Single-Cell Analysis Project | AdTx, CD4, F2998, F3035, cd1, cd2076, cd4578, cd5 | 236.2 GB<br>(104,286 files) | Processed 10x Cell Ranger count outputs, filtered feature-barcode matrices, and HDF5 feature dumps for adjuvant therapy cohort. | `(no ext)`, `.csv`, `.h5` | High priority backup. Essential intermediate count matrices for F2998/F3035 AdTx analysis. |
| **10** | `TB_TL_Non_Tcell` | Single-Cell Analysis Project | Cd28, Cd3, Cd40, cd0, cd0218162, cd048602, cd0513, cd115 | 123.5 GB<br>(824 files) | 20 AnnData (.h5ad) objects focused specifically on myeloid, stromal, and B-cell subsets in the TB Total Lung atlas. | `.png`, `(no ext)`, `.pdf` | Backup .h5ad objects. Push git repository commits to GitHub. |
| **11** | `TB_TL_TBD2_F2998` | Single-Cell Processed Objects | CD4, F2998, F3035, TBD2 | 55.1 GB<br>(44,192 files) | Processed Cell Ranger feature matrices and H5 files for timepoint TBD2 (F2998). | `(no ext)`, `.csv`, `.h5` | Backup to Data_backup. Canonical count matrix for TBD2. |
| **12** | `TB_TL_TBD3_F2998_F3035` | Single-Cell Processed Objects | CD4, F2998, F3035, TBD3 | 54.5 GB<br>(44,333 files) | Processed Cell Ranger feature matrices and H5 files for timepoint TBD3 (F2998/F3035). | `(no ext)`, `.csv`, `.h5` | Backup to Data_backup. Canonical count matrix for TBD3. |
| **13** | `TB_TL_TBD_F2998` | Single-Cell Analysis Project | CD4, F2998, TBD, f5664 | 34.9 GB<br>(24,638 files) | Processed Cell Ranger feature matrices and downstream analysis scripts for initial TBD cohort. | `(no ext)`, `.csv`, `.h5` | Backup to Data_backup. |
| **14** | `imaging_analysis_f2805_HEV` | Microscopy & Raw Imaging Data | F2805, HEV, cd00, cd01, cd0785, cd0834, cd085, cd1 | 134.3 GB<br>(150,254 files) | Python pipelines for spatial quantification of B-cell density, HEV distance, and follicle metrics across timepoints. | `.pyc`, `.py`, `.h` | Prune virtualenv files. Embedded .venv adds ~100k files. Backup scripts, CSV summaries, and final vector/PNG plots. |
| **15** | `imaging_data_CD31pilot_#1_#2` | Microscopy & Raw Imaging Data | CD31 | 83.6 GB<br>(5 files) | 5 Zeiss .czi slide scans testing endothelial CD31 antibody staining and tiling parameters. | `.czi` | Archive to Data_backup. |
| **16** | `imaging_data_f2630_HEV` | Microscopy & Raw Imaging Data | HEV, f2630 | 260.6 GB<br>(20 files) | 20 Zeiss .czi slide scans stained for High Endothelial Venules (HEV / PNAd) in TB granulomas. | `.czi` | Backup to Data_backup. Keep as canonical raw source for F2630 HEV analyses. |
| **17** | `imaging_data_f2630_neutrophils` | Histology & Image Analysis (QuPath) | f2630, neutrophil | 256.7 GB<br>(158 files) | 32 Zeiss .czi slides stained for neutrophil markers (Ly6G/MPO) + QuPath classification caches. | `.json`, `.jpg`, `.czi` | Backup .czi slides to Data_backup. Verify analysis project is synchronized with NAFP Image analysis. |
| **18** | `imaging_data_f2701_HEV` | Microscopy & Raw Imaging Data | F2805, HEV, f2701 | 228.2 GB<br>(26 files) | 26 Zeiss .czi slide scans evaluating HEV formation and memory T-cell niches in infected tissue. | `.czi` | Backup to Data_backup. Ensure corresponding QuPath project is cataloged. |
| **19** | `imaging_data_f2805_HEV` | Microscopy & Raw Imaging Data | F2805, HEV, f2805 | 53.6 GB<br>(19 files) | 19 Zeiss .czi slides from week 16 timepoint focusing on iBALT structures and HEV networks. | `.czi` | Backup to Data_backup. Reference dataset for week 16 histology. |
| **20** | `imaging_data_f2944_1` | Histology & Image Analysis (QuPath) | f2944 | 860.4 GB<br>(722 files) | 23 high-resolution Zeiss .czi slide scans of lung sections + integrated QuPath slide tile caches & object data. | `.json`, `.jpg`, `.qpdata` | Backup .czi slides to Data_backup. Consider separating raw .czi files from ephemeral tile caches (.qpdata/.jpg) to reduce backup volume. |
| **21** | `imaging_data_f2944_2` | Microscopy & Raw Imaging Data | f2944 | 718.2 GB<br>(21 files) | 21 large Zeiss confocal .czi slide scans for experiment F2944 lung histology. | `.czi` | Backup to Data_backup. Mark directory read-only to prevent accidental modification or overwrite. |
| **22** | `imaging_data_seattle` | Microscopy & Raw Imaging Data | — | 22.1 GB<br>(1 files) | Single multi-series Leica confocal image file (20231012 H107.lif) from Seattle collaboration. | `.lif` | Backup to Data_backup. Add a brief README.txt noting slide origin and staining panel. |
| **23** | `imaging_data_test_cellpose` | Microscopy & Raw Imaging Data | CD31, cd0, cd1398, cd3, cd3848772, cd4875, cd562, cd59 | 244.8 GB<br>(11,301 files) | Extracted multi-channel image TIFF tiles and pre-computed Cellpose segmentation masks (.npy). | `.tif`, `.npy`, `(no ext)` | Evaluate persistence. These are machine-generated tiles/masks; if re-generable via pipeline, exclude from heavy offsite backup or archive as compressed tarball. |
| **24** | `imaging_py` | Code / Analysis Pipeline | — | 0.0 GB<br>(4 files) | 4 exploratory Jupyter notebooks testing scikit-image and slide loading environments. | `.ipynb` | Safe to keep or integrate into main script repository. |
| **25** | `nagar_F2657_csv` | Microscopy & Raw Imaging Data | CD27, CD4, F2000, F2008, F2014, F2020, F2657, cd0 | 210.8 GB<br>(433,594 files) | QUICHE spatial neighborhood modeling, cell-type interaction matrices, and embedded Python virtual environment. | `.py`, `.pyc`, `.h` | Clean up build artifacts. The .venv / .pyc files inflate this directory to 433k files. Add .gitignore, purge .pyc, and backup only code + final CSV interaction matrices. |
| **26** | `sequencing_data_MonkeyPAXgene_GEO241235` | Raw Sequencing (FASTQ) | Monkey, PAXgene | 144.5 GB<br>(62 files) | Longitudinal whole blood PAXgene bulk RNA-seq FASTQ data from NHP TB challenge studies + sample metadata sheets. | `.gz`, `.tsv`, `.xlsx` | Archive & backup. Verify snapshot in Data_backup. Safe for long-term cold archive. |
| **27** | `sequencing_data_endothelial` | Raw Sequencing (FASTQ) | endothelial | 670.4 GB<br>(138 files) | Demultiplexed raw sequencing FASTQ files for isolated pulmonary endothelial cells across 4 lanes + MD5 checksums. | `.gz`, `.md5`, `.eve8n4` | Keep write-protected. Verify Restic backup snapshot in Data_backup. Clean up hidden temp upload artifact (.EVE8n4). |
| **28** | `sequencing_data_totallung` | Raw Sequencing (FASTQ) | totallung | 1008.9 GB<br>(64 files) | Demultiplexed single-cell 10x FLEX FASTQ files (I1, I2, R1, R2 across 4 sequencing lanes). | `.gz` | Keep write-protected. Verify incremental Restic backup to Data_backup. Do not store analysis derivatives here. |
| **29** | `tb-lung-atlas` | Single-Cell Analysis Project | cd09, cd27, cd5, f0409, f1798, f2244, f2887, f3790 | 0.7 GB<br>(15,841 files) | Clean reproducible R repository containing analysis workflows, documentation (README.md), and 418 .rds milestone objects. | `.hpp`, `(no ext)`, `.r` | Sync with GitHub. High priority reproducible publication code repository. |

---

## 🧹 Optimization & Maintenance Priorities

1. **Clean up virtualenv / build artifacts on WekaFS**:
   - `nagar_F2657_csv` (433,594 files) and `imaging_analysis_f2805_HEV` (150,254 files) have massive `.venv` / `.pyc` trees that slow down POSIX operations.
   - Add `.gitignore` rules for `.venv`, `__pycache__`, and `*.pyc`.
2. **De-duplicate / prune redundant projects**:
   - `QuPath Analysis F2944(1)` (20 MB duplicate) can be removed or moved to `Trash`.
   - Consolidate standalone `QuPath Analysis F2944` into `NAFP Image analysis`.
3. **Restic Backup Validation**:
   - Ensure all 3 raw sequencing directories (1.82 TB) and 9 raw imaging directories (2.48 TB) are registered in the automated `scripts/backup/run_incremental_backups.sh` job to `/work/Data_backup/`.

---

*This inventory is machine-generated and tracked in Git (`docs/data-management/inventory-tb-group.md` and `.json`) as well as preserved on `/work/TB group/tb_group_catalog.json`.*
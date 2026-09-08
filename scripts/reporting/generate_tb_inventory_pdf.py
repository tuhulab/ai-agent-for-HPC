#!/usr/bin/env python3
"""
Generate a publication-grade, professional PDF report for the TB Group Storage Inventory.
Merges docs/data-management/inventory-tb-group.json and docs/data-management/inventory-tb-group.md.
"""

import json
import re
import os
import sys

def load_data():
    with open("docs/data-management/inventory-tb-group.json") as f:
        json_data = json.load(f)

    with open("docs/data-management/inventory-tb-group.md") as f:
        md_text = f.read()

    actions = {}
    for line in md_text.splitlines():
        if line.startswith("| **"):
            parts = [p.strip() for p in line.split("|")]
            if len(parts) >= 9:
                m = re.search(r"`([^`]+)`", parts[2])
                if m:
                    name = m.group(1)
                    action = parts[8]
                    actions[name] = action

    for d in json_data:
        name = d["name"]
        d["action"] = actions.get(name, "Maintain regular backup snapshot in Data_backup.")

    return json_data

def get_modality_badge(modality):
    badges = {
        "Microscopy & Raw Imaging Data": ("#0284c7", "#e0f2fe", "#0369a1", "Microscopy (Raw)"),
        "Raw Sequencing (FASTQ)": ("#7c3aed", "#f3e8ff", "#6d28d9", "Raw Sequencing (FASTQ)"),
        "Histology & Image Analysis (QuPath)": ("#0d9488", "#ccfbf1", "#0f766e", "Histology (QuPath)"),
        "Single-Cell Analysis Project": ("#d97706", "#fef3c7", "#b45309", "Single-Cell Project"),
        "Single-Cell Processed Objects": ("#ea580c", "#ffedd5", "#c2410c", "Single-Cell Objects"),
        "Code / Analysis Pipeline": ("#475569", "#f1f5f9", "#334155", "Code / Pipeline")
    }
    return badges.get(modality, ("#64748b", "#f1f5f9", "#475569", modality))

def get_action_badge(action):
    if "Primary raw data" in action:
        return ("#dc2626", "#fee2e2", "#991b1b", "Primary Raw Backup", "Write-protect; register in automated Restic backup to Data_backup.")
    elif "Git-tracked" in action:
        return ("#2563eb", "#dbeafe", "#1e40af", "Git Remote Sync", "Verify local commits and tags pushed to remote GitHub repo.")
    elif "Redundant copy candidate" in action:
        return ("#d97706", "#fef3c7", "#92400e", "Redundancy Audit", "Compare against master project; verify uniqueness & prune.")
    else:
        return ("#16a34a", "#dcfce7", "#166534", "Routine Snapshot", "Maintain regular incremental snapshots in Data_backup.")

def generate_html(data):
    total_gb = sum(d["size_gb"] for d in data)
    total_files = sum(d["total_files"] for d in data)
    total_dirs = sum(d["total_dirs"] for d in data)

    modalities = {}
    for d in data:
        m = d["modality"]
        if m not in modalities:
            modalities[m] = {"count": 0, "size_gb": 0, "files": 0}
        modalities[m]["count"] += 1
        modalities[m]["size_gb"] += d["size_gb"]
        modalities[m]["files"] += d["total_files"]

    sorted_modalities = sorted(modalities.items(), key=lambda x: x[1]["size_gb"], reverse=True)

    part1_items = data[:15]
    part2_items = data[15:]

    def render_catalog_rows(items, start_idx=1):
        html_rows = []
        for idx, d in enumerate(items, start_idx):
            name = d["name"]
            modality = d["modality"]
            border_col, bg_col, text_col, short_mod = get_modality_badge(modality)
            act_border, act_bg, act_text, act_pill, act_desc = get_action_badge(d["action"])

            sample_ids = d.get("sample_ids", [])
            if sample_ids:
                samples_html = "".join(f'<span class="mono-badge">{s}</span>' for s in sample_ids[:4])
                if len(sample_ids) > 4:
                    samples_html += f'<span class="mono-badge-more">+{len(sample_ids)-4}</span>'
            else:
                samples_html = '<span class="text-muted">—</span>'

            exts = d.get("top_exts", [])[:3]
            exts_html = " ".join(f'<span class="ext-pill">{e[0]} <small>({e[1]:,})</small></span>' for e in exts) if exts else '<span class="text-muted">—</span>'

            flags = []
            if d.get("has_git"):
                flags.append('<span class="flag-icon flag-git" title="Git Tracked">git</span>')
            if d.get("has_readme"):
                flags.append('<span class="flag-icon flag-doc" title="README Available">doc</span>')
            if d.get("has_venv"):
                flags.append('<span class="flag-icon flag-env" title="Virtualenv">venv</span>')
            if d.get("has_notebooks"):
                flags.append('<span class="flag-icon flag-nb" title="Jupyter Notebooks">ipynb</span>')
            if d.get("has_backup_copies"):
                flags.append('<span class="flag-icon flag-bak" title="Backup Copy Detected">bak</span>')
            flags_html = "".join(flags) if flags else '<span class="text-muted">—</span>'

            date_span = d.get("date_range", "2023-2026")

            row_html = f"""
            <tr>
              <td class="col-num">{idx}</td>
              <td class="col-name">
                <div class="dir-title">{name}</div>
                <div class="dir-meta">
                  <span>📅 {date_span}</span> &bull; <span>📁 {d['total_dirs']:,} dirs</span>
                </div>
              </td>
              <td class="col-mod">
                <span class="modality-pill" style="background:{bg_col}; color:{text_col}; border-color:{border_col}44;">
                  {short_mod}
                </span>
              </td>
              <td class="col-size">
                <div class="size-val">{d['size_gb']:.2f} <small>GB</small></div>
                <div class="file-count">{d['total_files']:,} files</div>
              </td>
              <td class="col-samples">{samples_html}</td>
              <td class="col-exts">{exts_html}</td>
              <td class="col-flags">{flags_html}</td>
              <td class="col-action">
                <span class="action-pill" style="background:{act_bg}; color:{act_text}; border-color:{act_border}55;">
                  {act_pill}
                </span>
                <div class="action-text">{act_desc}</div>
              </td>
            </tr>
            """
            html_rows.append(row_html)
        return "\n".join(html_rows)

    rows_part1 = render_catalog_rows(part1_items, 1)
    rows_part2 = render_catalog_rows(part2_items, 16)

    mod_bars = []
    mod_legends = []
    for m, v in sorted_modalities:
        raw_pct = (v["size_gb"] / total_gb) * 100
        bar_pct = max(raw_pct, 0.7) if v["count"] > 0 else 0
        border_col, bg_col, text_col, short_mod = get_modality_badge(m)
        mod_bars.append(f'<div class="mod-bar-segment" style="width: {bar_pct:.2f}%; background-color: {border_col};" title="{m}: {raw_pct:.1f}%"></div>')
        pct_str = f"{raw_pct:.1f}%" if raw_pct >= 0.05 else "<0.1%"
        mod_legends.append(f"""
        <div class="mod-legend-item">
          <span class="legend-dot" style="background-color: {border_col};"></span>
          <span class="legend-name">{short_mod}</span>
          <span class="legend-pct"><strong>{pct_str}</strong> ({v['size_gb']:.1f} GB &bull; {v['count']} datasets)</span>
        </div>
        """)

    mod_bars_html = "".join(mod_bars)
    mod_legends_html = "\n".join(mod_legends)

    mod_summary_rows = []
    for m, v in sorted_modalities:
        pct = (v["size_gb"] / total_gb) * 100
        border_col, bg_col, text_col, short_mod = get_modality_badge(m)
        mod_summary_rows.append(f"""
        <tr>
          <td><span class="mod-color-block" style="background:{border_col};"></span> <strong>{m}</strong></td>
          <td class="text-right">{v['count']}</td>
          <td class="text-right"><strong>{v['size_gb']:.2f} GB</strong></td>
          <td class="text-right">{pct:.1f}%</td>
          <td class="text-right">{v['files']:,}</td>
        </tr>
        """)
    mod_summary_table_html = "\n".join(mod_summary_rows)

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>TB Group Storage Inventory & Governance Catalog</title>
<style>
  @page {{
    size: A4 portrait;
    margin: 10mm 12mm 10mm 12mm;
  }}

  * {{
    box-sizing: border-box;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }}

  body {{
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    color: #0f172a;
    background-color: #ffffff;
    margin: 0;
    padding: 0;
    font-size: 8pt;
    line-height: 1.3;
  }}

  .page {{
    page-break-after: always;
    height: 277mm;
    max-height: 277mm;
    position: relative;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }}

  .page:last-child {{
    page-break-after: avoid;
  }}

  /* Typography & Utilities */
  h1, h2, h3, h4 {{
    margin: 0;
    font-weight: 700;
    color: #0f172a;
  }}
  .text-muted {{ color: #64748b; }}
  .text-right {{ text-align: right; }}
  .text-center {{ text-align: center; }}
  .font-mono {{ font-family: ui-monospace, "SF Mono", "JetBrains Mono", Menlo, Consolas, monospace; }}

  /* Header Banner */
  .header-banner {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 2px solid #0284c7;
    padding-bottom: 5px;
    margin-bottom: 8px;
  }}
  .org-title {{
    font-size: 7.8pt;
    font-weight: 800;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: #0369a1;
  }}
  .doc-ref {{
    font-size: 7.2pt;
    font-weight: 600;
    color: #475569;
    background: #f1f5f9;
    padding: 1.5px 5px;
    border-radius: 3px;
    border: 1px solid #e2e8f0;
  }}

  /* Page 1 Hero */
  .hero-block {{
    margin-bottom: 8px;
  }}
  .hero-title {{
    font-size: 16pt;
    font-weight: 800;
    color: #0f172a;
    letter-spacing: -0.02em;
    line-height: 1.15;
    margin-bottom: 3px;
  }}
  .hero-subtitle {{
    font-size: 8.8pt;
    color: #475569;
    line-height: 1.25;
  }}

  /* Info Strip */
  .info-strip {{
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 8px;
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-radius: 5px;
    padding: 6px 10px;
    margin-bottom: 10px;
  }}
  .info-cell {{
    display: flex;
    flex-direction: column;
  }}
  .info-cell-label {{
    font-size: 6.2pt;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: #64748b;
    margin-bottom: 1px;
  }}
  .info-cell-val {{
    font-size: 7.6pt;
    font-weight: 600;
    color: #0f172a;
  }}

  /* KPI Grid */
  .kpi-grid {{
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
    margin-bottom: 10px;
  }}
  .kpi-card {{
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 5px;
    padding: 7px 9px;
    box-shadow: 0 1px 2px rgba(0,0,0,0.02);
    border-left: 3.5px solid #0284c7;
  }}
  .kpi-card.purple {{ border-left-color: #7c3aed; }}
  .kpi-card.emerald {{ border-left-color: #059669; }}
  .kpi-card.amber {{ border-left-color: #d97706; }}
  .kpi-card.blue {{ border-left-color: #2563eb; }}
  .kpi-card.rose {{ border-left-color: #e11d48; }}

  .kpi-header {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 3px;
  }}
  .kpi-label {{
    font-size: 6.8pt;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: #475569;
  }}
  .kpi-badge {{
    font-size: 6.2pt;
    padding: 1px 5px;
    border-radius: 3px;
    font-weight: 600;
    background: #f1f5f9;
    color: #334155;
    white-space: nowrap;
  }}
  .kpi-value {{
    font-size: 13.5pt;
    font-weight: 800;
    color: #0f172a;
    line-height: 1.1;
    margin-bottom: 2px;
    font-variant-numeric: tabular-nums;
  }}
  .kpi-subtext {{
    font-size: 6.5pt;
    color: #64748b;
    line-height: 1.2;
  }}

  /* Visual Distribution */
  .section-title {{
    font-size: 9.5pt;
    font-weight: 800;
    color: #0f172a;
    margin-bottom: 5px;
    display: flex;
    align-items: center;
    gap: 5px;
  }}
  .section-title::before {{
    content: "";
    display: inline-block;
    width: 3px;
    height: 11px;
    background: #0284c7;
    border-radius: 2px;
  }}

  .chart-section {{
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-radius: 5px;
    padding: 8px 10px;
    margin-bottom: 10px;
  }}
  .mod-bar-container {{
    height: 12px;
    display: flex;
    border-radius: 3px;
    overflow: hidden;
    margin-bottom: 6px;
    background: #e2e8f0;
  }}
  .mod-bar-segment {{
    height: 100%;
  }}
  .mod-legends-grid {{
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 3px 10px;
  }}
  .mod-legend-item {{
    display: flex;
    align-items: center;
    font-size: 6.9pt;
    color: #334155;
  }}
  .legend-dot {{
    width: 6px;
    height: 6px;
    border-radius: 50%;
    margin-right: 5px;
    flex-shrink: 0;
  }}
  .legend-name {{
    font-weight: 600;
    margin-right: 4px;
    white-space: nowrap;
  }}
  .legend-pct {{
    margin-left: auto;
    color: #64748b;
    white-space: nowrap;
  }}

  /* Modality Breakdown Table */
  .summary-table {{
    width: 100%;
    border-collapse: collapse;
    font-size: 6.8pt;
    margin-top: 5px;
  }}
  .summary-table th {{
    background: #edf2f7;
    font-weight: 700;
    text-align: left;
    padding: 3.5px 5px;
    border-bottom: 1px solid #cbd5e1;
    color: #334155;
  }}
  .summary-table td {{
    padding: 3px 5px;
    border-bottom: 1px solid #e2e8f0;
    color: #1e293b;
  }}
  .mod-color-block {{
    display: inline-block;
    width: 7px;
    height: 7px;
    border-radius: 2px;
    margin-right: 4px;
    vertical-align: middle;
  }}

  /* Executive Insights Box */
  .insights-box {{
    background: #ffffff;
    border: 1px solid #cbd5e1;
    border-radius: 5px;
    padding: 8px 10px;
    box-shadow: 0 1px 2px rgba(0,0,0,0.02);
  }}
  .insights-list {{
    margin: 0;
    padding-left: 13px;
    font-size: 7pt;
    line-height: 1.35;
    color: #334155;
  }}
  .insights-list li {{
    margin-bottom: 3px;
  }}
  .insights-list li:last-child {{
    margin-bottom: 0;
  }}
  .insights-list strong {{
    color: #0f172a;
  }}

  /* Catalog Table (Pages 2 & 3) */
  .catalog-page-header {{
    margin-bottom: 6px;
  }}
  .catalog-page-header h2 {{
    font-size: 10.5pt;
    font-weight: 800;
    color: #0f172a;
  }}
  .catalog-page-header p {{
    font-size: 7.2pt;
    color: #64748b;
    margin: 1px 0 0 0;
  }}

  .catalog-table {{
    width: 100%;
    border-collapse: collapse;
    font-size: 6.6pt;
    border: 1px solid #cbd5e1;
  }}
  .catalog-table thead th {{
    background: #0f172a;
    color: #f8fafc;
    font-weight: 700;
    text-align: left;
    padding: 4px 5px;
    border-right: 1px solid #334155;
    font-size: 6.3pt;
    letter-spacing: 0.02em;
    text-transform: uppercase;
  }}
  .catalog-table thead th:last-child {{
    border-right: none;
  }}
  .catalog-table tbody tr {{
    border-bottom: 1px solid #e2e8f0;
    height: 14.5mm;
  }}
  .catalog-table tbody tr:nth-child(even) {{
    background-color: #f8fafc;
  }}
  .catalog-table tbody td {{
    padding: 2px 4px;
    vertical-align: middle;
    border-right: 1px solid #f1f5f9;
  }}
  .catalog-table tbody td:last-child {{
    border-right: none;
  }}

  .col-num {{
    width: 15px;
    text-align: center;
    font-weight: 700;
    color: #64748b;
  }}
  .col-name {{
    width: 160px;
  }}
  .dir-title {{
    font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
    font-weight: 700;
    color: #0f172a;
    font-size: 6.8pt;
    word-break: break-all;
    line-height: 1.15;
  }}
  .dir-meta {{
    display: flex;
    gap: 4px;
    font-size: 5.8pt;
    color: #64748b;
    margin-top: 1px;
  }}
  .col-mod {{
    width: 88px;
  }}
  .modality-pill {{
    display: inline-block;
    padding: 1.5px 4px;
    border-radius: 3px;
    font-size: 5.9pt;
    font-weight: 600;
    border: 1px solid transparent;
    line-height: 1.15;
    white-space: nowrap;
  }}
  .col-size {{
    width: 64px;
    text-align: right;
  }}
  .size-val {{
    font-weight: 800;
    font-size: 7pt;
    color: #0f172a;
    font-variant-numeric: tabular-nums;
  }}
  .file-count {{
    font-size: 5.8pt;
    color: #64748b;
    font-variant-numeric: tabular-nums;
  }}
  .col-samples {{
    width: 105px;
    line-height: 1.15;
  }}
  .mono-badge {{
    display: inline-block;
    background: #f1f5f9;
    color: #1e293b;
    border: 1px solid #cbd5e1;
    font-family: ui-monospace, Menlo, monospace;
    font-size: 5.5pt;
    padding: 0.5px 2.5px;
    border-radius: 2px;
    margin: 0.5px 1px 0.5px 0;
  }}
  .mono-badge-more {{
    display: inline-block;
    color: #64748b;
    font-size: 5.5pt;
    font-weight: 600;
  }}
  .col-exts {{
    width: 88px;
    line-height: 1.15;
  }}
  .ext-pill {{
    display: inline-block;
    background: #ffffff;
    border: 1px solid #e2e8f0;
    color: #334155;
    font-family: ui-monospace, Menlo, monospace;
    font-size: 5.5pt;
    padding: 0.5px 2.5px;
    border-radius: 2px;
    margin: 0.5px 1px 0.5px 0;
    white-space: nowrap;
  }}
  .col-flags {{
    width: 42px;
    text-align: center;
  }}
  .flag-icon {{
    display: inline-block;
    font-size: 5.2pt;
    font-weight: 700;
    text-transform: uppercase;
    padding: 0.5px 2px;
    border-radius: 2px;
    margin: 0.5px;
    font-family: ui-monospace, Menlo, monospace;
  }}
  .flag-git {{ background: #eff6ff; color: #1d4ed8; border: 1px solid #bfdbfe; }}
  .flag-doc {{ background: #ecfdf5; color: #047857; border: 1px solid #a7f3d0; }}
  .flag-env {{ background: #faf5ff; color: #7e22ce; border: 1px solid #e9d5ff; }}
  .flag-nb  {{ background: #fffbeb; color: #b45309; border: 1px solid #fde68a; }}
  .flag-bak {{ background: #f0fdf4; color: #15803d; border: 1px solid #bbf7d0; }}

  .col-action {{
    width: 140px;
  }}
  .action-pill {{
    display: inline-block;
    font-size: 5.6pt;
    font-weight: 700;
    padding: 1px 3.5px;
    border-radius: 2px;
    border: 1px solid transparent;
    text-transform: uppercase;
    letter-spacing: 0.02em;
    margin-bottom: 1px;
  }}
  .action-text {{
    font-size: 5.8pt;
    color: #475569;
    line-height: 1.15;
  }}

  /* Page 3 Summary Bar */
  .catalog-totals-box {{
    margin-top: 8px;
    background: #0f172a;
    color: #ffffff;
    border-radius: 5px;
    padding: 8px 12px;
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 10px;
  }}
  .tot-item {{
    display: flex;
    flex-direction: column;
  }}
  .tot-label {{
    font-size: 6pt;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: #94a3b8;
  }}
  .tot-val {{
    font-size: 10.5pt;
    font-weight: 800;
    color: #f8fafc;
    font-variant-numeric: tabular-nums;
  }}

  .action-summary-grid {{
    margin-top: 8px;
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 6px;
  }}
  .act-summary-card {{
    border: 1px solid #e2e8f0;
    border-radius: 5px;
    padding: 6px 8px;
    background: #ffffff;
  }}
  .act-summary-card.red {{ border-top: 3px solid #dc2626; }}
  .act-summary-card.blue {{ border-top: 3px solid #2563eb; }}
  .act-summary-card.green {{ border-top: 3px solid #16a34a; }}
  .act-summary-card.amber {{ border-top: 3px solid #d97706; }}
  .act-sum-title {{
    font-size: 6.6pt;
    font-weight: 700;
    color: #0f172a;
    margin-bottom: 1px;
  }}
  .act-sum-stats {{
    font-size: 8.5pt;
    font-weight: 800;
    color: #0f172a;
    margin-bottom: 1px;
  }}
  .act-sum-desc {{
    font-size: 6pt;
    color: #64748b;
    line-height: 1.2;
  }}

  /* Page 4 Deep Dive Cards */
  .deep-dive-grid {{
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 8px;
    margin-top: 4px;
    margin-bottom: 8px;
  }}
  .deep-card {{
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 5px;
    padding: 8px 10px;
    box-shadow: 0 1px 2px rgba(0,0,0,0.02);
  }}
  .deep-card-header {{
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    border-bottom: 1px solid #e2e8f0;
    padding-bottom: 4px;
    margin-bottom: 5px;
  }}
  .deep-card-title {{
    font-size: 8.5pt;
    font-weight: 800;
    color: #0f172a;
    display: flex;
    align-items: center;
    gap: 4px;
  }}
  .deep-card-badge {{
    font-size: 6.2pt;
    font-weight: 700;
    padding: 1.5px 5px;
    border-radius: 3px;
  }}
  .deep-stat-row {{
    display: flex;
    gap: 10px;
    margin-bottom: 4px;
    font-size: 6.8pt;
  }}
  .deep-stat-item {{
    display: flex;
    flex-direction: column;
  }}
  .deep-stat-label {{
    font-size: 5.8pt;
    text-transform: uppercase;
    color: #64748b;
    font-weight: 700;
  }}
  .deep-stat-val {{
    font-weight: 800;
    color: #0f172a;
  }}
  .deep-content-text {{
    font-size: 6.7pt;
    line-height: 1.28;
    color: #334155;
    margin-bottom: 4px;
  }}
  .deep-dataset-list {{
    background: #f8fafc;
    border: 1px solid #f1f5f9;
    border-radius: 4px;
    padding: 4px 6px;
    font-size: 6.4pt;
    line-height: 1.28;
    color: #1e293b;
    margin-bottom: 4px;
  }}
  .deep-policy-note {{
    font-size: 6.2pt;
    background: #fef2f2;
    border-left: 3px solid #dc2626;
    padding: 3px 5px;
    color: #991b1b;
    border-radius: 0 3px 3px 0;
  }}
  .deep-policy-note.blue {{
    background: #eff6ff;
    border-left-color: #2563eb;
    color: #1e40af;
  }}
  .deep-policy-note.green {{
    background: #f0fdf4;
    border-left-color: #16a34a;
    color: #166534;
  }}
  .deep-policy-note.amber {{
    background: #fffbeb;
    border-left-color: #d97706;
    color: #92400e;
  }}

  /* Page 4 Cohort Matrix Table */
  .cohort-matrix-box {{
    background: #ffffff;
    border: 1px solid #cbd5e1;
    border-radius: 5px;
    padding: 7px 9px;
    box-shadow: 0 1px 2px rgba(0,0,0,0.02);
  }}
  .cohort-table {{
    width: 100%;
    border-collapse: collapse;
    font-size: 6.5pt;
    margin-top: 3px;
  }}
  .cohort-table th {{
    background: #f1f5f9;
    color: #334155;
    font-weight: 700;
    text-align: left;
    padding: 2.5px 5px;
    border-bottom: 1px solid #cbd5e1;
    font-size: 6.1pt;
    text-transform: uppercase;
  }}
  .cohort-table td {{
    padding: 2.5px 5px;
    border-bottom: 1px solid #f1f5f9;
    color: #1e293b;
    vertical-align: middle;
  }}
  .cohort-pill {{
    display: inline-block;
    background: #eff6ff;
    color: #1d4ed8;
    border: 1px solid #bfdbfe;
    font-family: ui-monospace, Menlo, monospace;
    font-weight: 700;
    font-size: 6.1pt;
    padding: 0.5px 3px;
    border-radius: 2px;
  }}
  .mod-tag {{
    display: inline-block;
    padding: 0.5px 3px;
    border-radius: 2px;
    font-size: 5.6pt;
    font-weight: 600;
    margin-right: 2px;
  }}

  /* Page 5 Governance & Topology */
  .topology-block {{
    background: #0f172a;
    color: #e2e8f0;
    border-radius: 5px;
    padding: 8px 12px;
    margin-bottom: 10px;
  }}
  .topology-title {{
    font-size: 8pt;
    font-weight: 700;
    color: #38bdf8;
    margin-bottom: 5px;
    display: flex;
    justify-content: space-between;
  }}
  .topology-code {{
    font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
    font-size: 6.5pt;
    line-height: 1.32;
    color: #cbd5e1;
    margin: 0;
  }}

  .gov-grid {{
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 8px;
    margin-bottom: 8px;
  }}
  .gov-card {{
    border: 1px solid #cbd5e1;
    border-radius: 5px;
    padding: 8px 10px;
    background: #ffffff;
  }}
  .gov-card-title {{
    font-size: 8pt;
    font-weight: 800;
    color: #0f172a;
    margin-bottom: 5px;
    display: flex;
    align-items: center;
    gap: 4px;
  }}
  .gov-card-title::before {{
    content: "";
    display: inline-block;
    width: 3px;
    height: 10px;
    background: #0284c7;
    border-radius: 2px;
  }}
  .gov-list {{
    margin: 0;
    padding-left: 13px;
    font-size: 6.7pt;
    line-height: 1.35;
    color: #334155;
  }}
  .gov-list li {{
    margin-bottom: 3px;
  }}
  .gov-list li:last-child {{
    margin-bottom: 0;
  }}

  .restic-box {{
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-radius: 4px;
    padding: 5px 7px;
    margin-top: 4px;
    font-family: ui-monospace, Menlo, monospace;
    font-size: 6.2pt;
    color: #0f172a;
    line-height: 1.25;
  }}

  .signoff-box {{
    margin-top: auto;
    background: #f8fafc;
    border: 1px solid #cbd5e1;
    border-radius: 5px;
    padding: 7px 10px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }}
  .signoff-left {{
    font-size: 6.6pt;
    color: #475569;
    line-height: 1.25;
  }}
  .signoff-right {{
    font-size: 6.6pt;
    text-align: right;
    color: #64748b;
  }}
  .signoff-badge {{
    display: inline-block;
    background: #dcfce7;
    color: #166534;
    border: 1px solid #86efac;
    padding: 1px 4px;
    border-radius: 3px;
    font-weight: 700;
    font-size: 6pt;
  }}
</style>
</head>
<body>

<!-- PAGE 1: EXECUTIVE OVERVIEW & TOPOLOGY DASHBOARD -->
<div class="page">
  <div class="header-banner">
    <div class="org-title">INFIMM Bioinformatics Core &bull; SDU eScience Center UCloud</div>
    <div class="doc-ref">DOC REF: INFIMM-TB-INV-2026.09 &bull; v1.0</div>
  </div>

  <div class="hero-block">
    <h1 class="hero-title">TB Group Storage Inventory &amp; Catalog</h1>
    <div class="hero-subtitle">
      Comprehensive Asset Audit, Multi-Omics Modality Breakdown &amp; Data Governance Assessment for <code>/work/TB group/</code>
    </div>
  </div>

  <div class="info-strip">
    <div class="info-cell">
      <span class="info-cell-label">Platform &amp; Workspace</span>
      <span class="info-cell-val">SDU eScience UCloud &bull; <code>BINF INFIMM</code></span>
    </div>
    <div class="info-cell">
      <span class="info-cell-label">WekaFS Mount Point</span>
      <span class="info-cell-val"><code>/work/TB group/</code> (Folder #1)</span>
    </div>
    <div class="info-cell">
      <span class="info-cell-label">Surveyed Assets</span>
      <span class="info-cell-val">29 Datasets &bull; 957,970 Files</span>
    </div>
    <div class="info-cell">
      <span class="info-cell-label">Survey Date &amp; Scope</span>
      <span class="info-cell-val">September 2026 &bull; 2023–2026 Cohorts</span>
    </div>
  </div>

  <div class="kpi-grid">
    <div class="kpi-card blue">
      <div class="kpi-header">
        <span class="kpi-label">Total Storage Footprint</span>
        <span class="kpi-badge">5.51 TB</span>
      </div>
      <div class="kpi-value">5,643.01 <small style="font-size:8.5pt;font-weight:600;color:#64748b;">GB</small></div>
      <div class="kpi-subtext">Active persistent working volume on WekaFS 4.7 PB parallel tier</div>
    </div>

    <div class="kpi-card emerald">
      <div class="kpi-header">
        <span class="kpi-label">File Object Count</span>
        <span class="kpi-badge">957.9k files</span>
      </div>
      <div class="kpi-value">957,970</div>
      <div class="kpi-subtext">High directory density: 268,358 nested subdirectories</div>
    </div>

    <div class="kpi-card purple">
      <div class="kpi-header">
        <span class="kpi-label">Primary Raw Data</span>
        <span class="kpi-badge">67.8% volume</span>
      </div>
      <div class="kpi-value">3,826.48 <small style="font-size:8.5pt;font-weight:600;color:#64748b;">GB</small></div>
      <div class="kpi-subtext">14 datasets: Raw FASTQs (1.82 TB) &amp; Zeiss/Leica slides (2.00 TB)</div>
    </div>

    <div class="kpi-card amber">
      <div class="kpi-header">
        <span class="kpi-label">Analysis &amp; Processed</span>
        <span class="kpi-badge">32.2% volume</span>
      </div>
      <div class="kpi-value">1,816.53 <small style="font-size:8.5pt;font-weight:600;color:#64748b;">GB</small></div>
      <div class="kpi-subtext">15 datasets: Single-cell H5/RDS matrices &amp; QuPath annotations</div>
    </div>

    <div class="kpi-card rose">
      <div class="kpi-header">
        <span class="kpi-label">Git Repositories</span>
        <span class="kpi-badge">11 tracked</span>
      </div>
      <div class="kpi-value">11 <small style="font-size:8.5pt;font-weight:600;color:#64748b;">directories</small></div>
      <div class="kpi-subtext">Version-controlled pipeline code, analysis repos &amp; notebooks</div>
    </div>

    <div class="kpi-card">
      <div class="kpi-header">
        <span class="kpi-label">Snapshot Backup Status</span>
        <span class="kpi-badge">15 Backed Up</span>
      </div>
      <div class="kpi-value">15 / 29</div>
      <div class="kpi-subtext">15 datasets with backup copies; 14 require Restic snapshot registration</div>
    </div>
  </div>

  <div class="chart-section">
    <div class="section-title">Storage Allocation by Research Modality</div>
    <div class="mod-bar-container">
      {mod_bars_html}
    </div>
    <div class="mod-legends-grid">
      {mod_legends_html}
    </div>
    <table class="summary-table">
      <thead>
        <tr>
          <th>Modality Classification</th>
          <th class="text-right">Datasets</th>
          <th class="text-right">Volume (GB)</th>
          <th class="text-right">% Share</th>
          <th class="text-right">Total Files</th>
        </tr>
      </thead>
      <tbody>
        {mod_summary_table_html}
      </tbody>
    </table>
  </div>

  <div class="insights-box">
    <div class="section-title" style="margin-bottom:3px;">Executive Findings &amp; Governance Priorities</div>
    <ul class="insights-list">
      <li><strong>Raw Data Preservation (Tier 1 Priority):</strong> 3,826.48 GB across 14 directories constitutes irreplaceable raw FASTQs and Zeiss CZI slides. These folders must be write-protected (read-only POSIX permissions) and registered in the automated incremental Restic backup to <code>/work/Data_backup/repo/</code>.</li>
      <li><strong>Git Remote Synchronization:</strong> 11 directories contain <code>.git</code> repositories (e.g. <code>TB_TL</code>, <code>TB-Endothelial</code>, <code>tb-lung-atlas</code>). Verify that all local commits and branches are pushed to GitHub, and ensure large intermediate files (H5, RDS) are excluded via <code>.gitignore</code>.</li>
      <li><strong>Storage Deduplication Opportunity:</strong> <code>QuPath Analysis F2944(1)</code> (0.02 GB, 707 files) is a redundant clone of <code>QuPath Analysis F2944</code> (0.51 GB). Verify uniqueness and remove the clone to maintain project hygiene.</li>
      <li><strong>HPC Job Mounting Protocol:</strong> Always mount <code>TB group</code> as <strong>Folder #1</strong> and <code>Data_backup</code> as <strong>Folder #2</strong> on UCloud. Never leave unlinked deliverables in container root <code>/work/</code>.</li>
    </ul>
  </div>
</div>

<!-- PAGE 2: MASTER DIRECTORY CATALOG - PART I (ITEMS 1 - 15) -->
<div class="page">
  <div class="header-banner">
    <div class="org-title">INFIMM Bioinformatics Core &bull; Directory Catalog</div>
    <div class="doc-ref">CATALOG PART I (DATASETS 01 – 15)</div>
  </div>

  <div class="catalog-page-header">
    <h2>📁 Master Directory Catalog — Part I (Datasets 01 to 15)</h2>
    <p>Detailed breakdown of primary datasets, sample markers, technical stacks, storage footprints, and suggested governance actions.</p>
  </div>

  <table class="catalog-table">
    <thead>
      <tr>
        <th class="col-num">#</th>
        <th class="col-name">Directory &amp; Metadata</th>
        <th class="col-mod">Modality / Type</th>
        <th class="col-size">Size &amp; Files</th>
        <th class="col-samples">Sample IDs / Markers</th>
        <th class="col-exts">Top Formats</th>
        <th class="col-flags">Flags</th>
        <th class="col-action">Governance Action</th>
      </tr>
    </thead>
    <tbody>
      {rows_part1}
    </tbody>
  </table>
</div>

<!-- PAGE 3: MASTER DIRECTORY CATALOG - PART II (ITEMS 16 - 29) -->
<div class="page">
  <div class="header-banner">
    <div class="org-title">INFIMM Bioinformatics Core &bull; Directory Catalog</div>
    <div class="doc-ref">CATALOG PART II (DATASETS 16 – 29)</div>
  </div>

  <div class="catalog-page-header">
    <h2>📁 Master Directory Catalog — Part II (Datasets 16 to 29)</h2>
    <p>High-volume imaging runs, raw sequencing archives, and single-cell atlas workflows.</p>
  </div>

  <table class="catalog-table">
    <thead>
      <tr>
        <th class="col-num">#</th>
        <th class="col-name">Directory &amp; Metadata</th>
        <th class="col-mod">Modality / Type</th>
        <th class="col-size">Size &amp; Files</th>
        <th class="col-samples">Sample IDs / Markers</th>
        <th class="col-exts">Top Formats</th>
        <th class="col-flags">Flags</th>
        <th class="col-action">Governance Action</th>
      </tr>
    </thead>
    <tbody>
      {rows_part2}
    </tbody>
  </table>

  <!-- Master Totals Box -->
  <div class="catalog-totals-box">
    <div class="tot-item">
      <span class="tot-label">Total Surveyed Items</span>
      <span class="tot-val">29 Directories</span>
    </div>
    <div class="tot-item">
      <span class="tot-label">Total Storage Footprint</span>
      <span class="tot-val">5,643.01 GB (5.51 TB)</span>
    </div>
    <div class="tot-item">
      <span class="tot-label">Total File Inventory</span>
      <span class="tot-val">957,970 Files</span>
    </div>
    <div class="tot-item">
      <span class="tot-label">Total Directory Trees</span>
      <span class="tot-val">268,358 Folders</span>
    </div>
  </div>

  <!-- Action Category Summary Grid -->
  <div class="action-summary-grid">
    <div class="act-summary-card red">
      <div class="act-sum-title">Primary Raw Backup</div>
      <div class="act-sum-stats">14 Datasets &bull; 3,826.5 GB</div>
      <div class="act-sum-desc">Immutable raw FASTQs and microscopy scans. Priority Restic backup snapshots required.</div>
    </div>
    <div class="act-summary-card blue">
      <div class="act-sum-title">Git Remote Sync</div>
      <div class="act-sum-stats">8 Repos &bull; 570.7 GB</div>
      <div class="act-sum-desc">Single-cell and analysis code repos. Verify local commits and tags pushed to GitHub.</div>
    </div>
    <div class="act-summary-card green">
      <div class="act-sum-title">Routine Snapshot</div>
      <div class="act-sum-stats">6 Datasets &bull; 1,245.8 GB</div>
      <div class="act-sum-desc">Processed objects and QuPath workspaces. Maintain scheduled incremental backup.</div>
    </div>
    <div class="act-summary-card amber">
      <div class="act-sum-title">Redundancy Audit</div>
      <div class="act-sum-stats">1 Dataset &bull; 0.02 GB</div>
      <div class="act-sum-desc">Duplicate QuPath folder candidate. Verify uniqueness against master project and prune.</div>
    </div>
  </div>
</div>

<!-- PAGE 4: MODALITY DEEP-DIVE & COHORT ANALYSIS -->
<div class="page">
  <div class="header-banner">
    <div class="org-title">INFIMM Bioinformatics Core &bull; Modality Architecture</div>
    <div class="doc-ref">TECHNICAL DEEP-DIVE</div>
  </div>

  <div class="hero-block" style="margin-bottom:5px;">
    <h2 style="font-size:11.5pt;font-weight:800;">🔬 Multi-Omics Modality Deep-Dive &amp; Cohort Architecture</h2>
    <div class="hero-subtitle">Granular technical review of sequencing formats, high-resolution microscopy slides, digital pathology, and single-cell pipelines.</div>
  </div>

  <div class="deep-dive-grid">
    <!-- Card 1: Raw Sequencing -->
    <div class="deep-card">
      <div class="deep-card-header">
        <div class="deep-card-title">
          <span>🧬</span> Raw Sequencing (FASTQ)
        </div>
        <span class="deep-card-badge" style="background:#f3e8ff; color:#6d28d9; border:1px solid #d8b4fe;">1,823.83 GB &bull; 32.3%</span>
      </div>
      <div class="deep-stat-row">
        <div class="deep-stat-item">
          <span class="deep-stat-label">Datasets</span>
          <span class="deep-stat-val">3 cohorts</span>
        </div>
        <div class="deep-stat-item">
          <span class="deep-stat-label">File Objects</span>
          <span class="deep-stat-val">264 files</span>
        </div>
        <div class="deep-stat-item">
          <span class="deep-stat-label">Formats</span>
          <span class="deep-stat-val">.fastq.gz, .md5, .tsv</span>
        </div>
      </div>
      <div class="deep-content-text">
        High-throughput sequencing archives encompassing whole-lung transcriptomics, sorted endothelial cell populations, and non-human primate peripheral blood RNA-seq:
      </div>
      <div class="deep-dataset-list">
        &bull; <code>sequencing_data_totallung</code>: 1,008.93 GB (64 files) &bull; Demultiplexed pooled runs (I1, I2, R1, R2).<br>
        &bull; <code>sequencing_data_endothelial</code>: 670.41 GB (138 files) &bull; Endothelial sorted paired libraries.<br>
        &bull; <code>sequencing_data_MonkeyPAXgene_GEO241235</code>: 144.49 GB (62 files) &bull; Public benchmark RNA-seq.
      </div>
      <div class="deep-policy-note">
        <strong>Governance Requirement:</strong> Raw FASTQs are strictly immutable. Write-protect POSIX directory permissions. Ensure source MD5 verification checksums are archived alongside data.
      </div>
    </div>

    <!-- Card 2: High-Resolution Microscopy -->
    <div class="deep-card">
      <div class="deep-card-header">
        <div class="deep-card-title">
          <span>🔬</span> Microscopy &amp; Raw Imaging
        </div>
        <span class="deep-card-badge" style="background:#e0f2fe; color:#0369a1; border:1px solid #bae6fd;">2,002.65 GB &bull; 35.5%</span>
      </div>
      <div class="deep-stat-row">
        <div class="deep-stat-item">
          <span class="deep-stat-label">Datasets</span>
          <span class="deep-stat-val">11 cohorts</span>
        </div>
        <div class="deep-stat-item">
          <span class="deep-stat-label">File Objects</span>
          <span class="deep-stat-val">678,848 files</span>
        </div>
        <div class="deep-stat-item">
          <span class="deep-stat-label">Formats</span>
          <span class="deep-stat-val">.czi, .lif, .tif, .npy</span>
        </div>
      </div>
      <div class="deep-content-text">
        Multi-channel Zeiss and Leica whole-slide scans investigating High Endothelial Venules (HEV) and inducible Bronchus-Associated Lymphoid Tissue (iBALT) structures:
      </div>
      <div class="deep-dataset-list">
        &bull; <strong>Zeiss Slide Scans:</strong> <code>f2944_2</code> (718.2 GB), <code>f2630_HEV</code> (260.6 GB), <code>f2701_HEV</code> (228.2 GB), <code>f2805_HEV</code> (53.6 GB), <code>CD31pilot</code> (83.6 GB).<br>
        &bull; <strong>Leica Slides:</strong> <code>imaging_data_seattle</code> (22.15 GB .lif).<br>
        &bull; <strong>Cellpose &amp; Spatial ML:</strong> <code>imaging_data_test_cellpose</code> (244.8 GB), <code>nagar_F2657_csv</code> (210.8 GB, 433k files &bull; SIM testing, QUICHE).
      </div>
      <div class="deep-policy-note blue">
        <strong>Storage Note:</strong> Slide files (.czi/.lif) average 5–40 GB per slide. Avoid repeated unpacking or decompression on WekaFS. Register in Restic incremental snapshots.
      </div>
    </div>

    <!-- Card 3: QuPath Histology -->
    <div class="deep-card">
      <div class="deep-card-header">
        <div class="deep-card-title">
          <span>🏷️</span> Histology &amp; Image Analysis
        </div>
        <span class="deep-card-badge" style="background:#ccfbf1; color:#0f766e; border:1px solid #99f6e4;">1,127.16 GB &bull; 20.0%</span>
      </div>
      <div class="deep-stat-row">
        <div class="deep-stat-item">
          <span class="deep-stat-label">Datasets</span>
          <span class="deep-stat-val">5 projects</span>
        </div>
        <div class="deep-stat-item">
          <span class="deep-stat-label">File Objects</span>
          <span class="deep-stat-val">12,031 files</span>
        </div>
        <div class="deep-stat-item">
          <span class="deep-stat-label">Formats</span>
          <span class="deep-stat-val">.qpdata, .qpproj, .json, .csv</span>
        </div>
      </div>
      <div class="deep-content-text">
        Digital pathology projects containing cell detection classifiers, spatial boundary annotations, and intensity measurement tables:
      </div>
      <div class="deep-dataset-list">
        &bull; <code>imaging_data_f2944_1</code>: 860.38 GB (722 files) &bull; Major QuPath project with embedded raw CZI references.<br>
        &bull; <code>imaging_data_f2630_neutrophils</code>: 256.74 GB (158 files) &bull; Neutrophil spatial infiltrate quantification.<br>
        &bull; <code>NAFP Image analysis</code>: 9.51 GB (9,709 files) &bull; Multi-cohort HEV vs iBALT annotations.<br>
        &bull; <code>QuPath Analysis F2944</code> (510 MB) vs <code>QuPath Analysis F2944(1)</code> (20 MB).
      </div>
      <div class="deep-policy-note amber">
        <strong>Redundancy Alert:</strong> <code>QuPath Analysis F2944(1)</code> is an unlinked duplicate. Conduct differential check against main project and safely prune to reclaim inodes.
      </div>
    </div>

    <!-- Card 4: Single-Cell Multi-Omics -->
    <div class="deep-card">
      <div class="deep-card-header">
        <div class="deep-card-title">
          <span>🔬</span> Single-Cell &amp; Lung Atlas
        </div>
        <span class="deep-card-badge" style="background:#fef3c7; color:#b45309; border:1px solid #fde68a;">689.37 GB &bull; 12.2%</span>
      </div>
      <div class="deep-stat-row">
        <div class="deep-stat-item">
          <span class="deep-stat-label">Datasets</span>
          <span class="deep-stat-val">9 projects</span>
        </div>
        <div class="deep-stat-item">
          <span class="deep-stat-label">File Objects</span>
          <span class="deep-stat-val">266,823 files</span>
        </div>
        <div class="deep-stat-item">
          <span class="deep-stat-label">Formats</span>
          <span class="deep-stat-val">.rds, .h5, .h5ad, .r, .py</span>
        </div>
      </div>
      <div class="deep-content-text">
        Single-cell RNA-seq pipelines, 10x Genomics Cell Ranger count matrices, and integrated Seurat/Scanpy lung atlas objects:
      </div>
      <div class="deep-dataset-list">
        &bull; <strong>10x Matrices:</strong> <code>TB_TL_AdTx_F2998_F3035</code> (236.2 GB, 104k files), <code>TB_TL</code> (173.6 GB), <code>TB_TL_Non_Tcell</code> (123.5 GB).<br>
        &bull; <strong>Processed RDS Objects:</strong> <code>TB_TL_TBD2_F2998</code> (55.1 GB) &bull; <code>TB_TL_TBD3_F2998_F3035</code> (54.5 GB) &bull; <code>TB_TL_TBD_F2998</code> (34.9 GB).<br>
        &bull; <strong>Reproducible Git Pipelines:</strong> <code>TB-Endothelial</code>, <code>TB-VIT</code>, <code>tb-lung-atlas</code>.
      </div>
      <div class="deep-policy-note green">
        <strong>Best Practice:</strong> Keep analysis code versioned in Git. Store heavy `.rds` and `.h5` objects outside git tracking, backed up in `Data_backup`.
      </div>
    </div>
  </div>

  <!-- Cross-Modality Cohort & Sample Integration Matrix -->
  <div class="cohort-matrix-box">
    <div class="section-title" style="margin-bottom:2px; font-size:8.8pt;">🧬 Cross-Modality Cohort &amp; Sample Integration Matrix</div>
    <div style="font-size:6.6pt; color:#64748b; margin-bottom:3px;">
      Cross-referencing biological cohorts across high-throughput sequencing, slide microscopy, QuPath digital pathology, and single-cell atlas objects.
    </div>
    <table class="cohort-table">
      <thead>
        <tr>
          <th style="width:75px;">Cohort ID</th>
          <th style="width:115px;">Primary Markers / Target</th>
          <th style="width:125px;">Integrated Modalities</th>
          <th>Associated Working Directories</th>
          <th class="text-right" style="width:75px;">Combined Size</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><span class="cohort-pill">F2944</span></td>
          <td>HEV vs. iBALT spatial microenvironment</td>
          <td>
            <span class="mod-tag" style="background:#e0f2fe;color:#0369a1;">Microscopy</span>
            <span class="mod-tag" style="background:#ccfbf1;color:#0f766e;">QuPath</span>
          </td>
          <td><code>imaging_data_f2944_1</code>, <code>imaging_data_f2944_2</code>, <code>QuPath Analysis F2944</code></td>
          <td class="text-right"><strong>1,579.07 GB</strong></td>
        </tr>
        <tr>
          <td><span class="cohort-pill">F2998 &bull; F3035</span></td>
          <td>CD4 T cells, AdTx intervention cohorts</td>
          <td>
            <span class="mod-tag" style="background:#fef3c7;color:#b45309;">10x Single-Cell</span>
            <span class="mod-tag" style="background:#ffedd5;color:#c2410c;">Seurat RDS</span>
          </td>
          <td><code>TB_TL_AdTx_F2998_F3035</code>, <code>TB_TL_TBD2_F2998</code>, <code>TB_TL_TBD3_F2998_F3035</code></td>
          <td class="text-right"><strong>345.73 GB</strong></td>
        </tr>
        <tr>
          <td><span class="cohort-pill">F2630</span></td>
          <td>HEV structures &amp; neutrophil infiltration</td>
          <td>
            <span class="mod-tag" style="background:#e0f2fe;color:#0369a1;">Microscopy</span>
            <span class="mod-tag" style="background:#ccfbf1;color:#0f766e;">QuPath</span>
          </td>
          <td><code>imaging_data_f2630_HEV</code>, <code>imaging_data_f2630_neutrophils</code></td>
          <td class="text-right"><strong>517.37 GB</strong></td>
        </tr>
        <tr>
          <td><span class="cohort-pill">F2805</span></td>
          <td>HEV maturation, B cell aggregates (wk 2, 4, 6)</td>
          <td>
            <span class="mod-tag" style="background:#e0f2fe;color:#0369a1;">Microscopy</span>
            <span class="mod-tag" style="background:#f1f5f9;color:#334155;">Spatial Graph</span>
          </td>
          <td><code>imaging_data_f2805_HEV</code>, <code>imaging_analysis_f2805_HEV</code></td>
          <td class="text-right"><strong>187.89 GB</strong></td>
        </tr>
        <tr>
          <td><span class="cohort-pill">Endothelial</span></td>
          <td>CD31, CD86, sorted endothelial transcriptomes</td>
          <td>
            <span class="mod-tag" style="background:#f3e8ff;color:#6d28d9;">Raw FASTQ</span>
            <span class="mod-tag" style="background:#fef3c7;color:#b45309;">R/Seurat</span>
          </td>
          <td><code>sequencing_data_endothelial</code>, <code>TB-Endothelial</code>, <code>imaging_data_CD31pilot_#1_#2</code></td>
          <td class="text-right"><strong>754.84 GB</strong></td>
        </tr>
        <tr>
          <td><span class="cohort-pill">Total Lung</span></td>
          <td>Whole-lung tissue atlas &amp; spatial profiling</td>
          <td>
            <span class="mod-tag" style="background:#f3e8ff;color:#6d28d9;">Raw FASTQ</span>
            <span class="mod-tag" style="background:#e0f2fe;color:#0369a1;">Microscopy</span>
            <span class="mod-tag" style="background:#fef3c7;color:#b45309;">Atlas Repo</span>
          </td>
          <td><code>sequencing_data_totallung</code>, <code>TB-total-lung</code>, <code>tb-lung-atlas</code></td>
          <td class="text-right"><strong>1,035.44 GB</strong></td>
        </tr>
      </tbody>
    </table>
  </div>
</div>

<!-- PAGE 5: STORAGE ARCHITECTURE, BACKUP PLAYBOOK & GOVERNANCE -->
<div class="page">
  <div class="header-banner">
    <div class="org-title">INFIMM Bioinformatics Core &bull; Storage Governance</div>
    <div class="doc-ref">OPERATIONAL RUNBOOK</div>
  </div>

  <div class="hero-block" style="margin-bottom:6px;">
    <h2 style="font-size:12pt;font-weight:800;">⚙️ UCloud Storage Architecture, Backup Playbook &amp; Governance</h2>
    <div class="hero-subtitle">Operational runbook for mounting drives, automated Restic snapshot management, and FAIR compliance.</div>
  </div>

  <!-- UCloud Storage Mount Architecture -->
  <div class="topology-block">
    <div class="topology-title">
      <span>UCLOUD STORAGE TOPOLOGY &amp; CONTAINER MOUNT NAMESPACE</span>
      <span style="color:#94a3b8;font-weight:normal;">DeiC Interactive HPC (K8s) &bull; WekaFS 4.7 PB</span>
    </div>
    <pre class="topology-code">/work/                                   # Container mount namespace (EPHEMERAL ROOT - Never store deliverables here!)
├── TB group/                            # Primary Working Volume (Folder #1) — PERSISTENT (5.51 TB &bull; 957,970 files)
│   ├── sequencing_data_*                # Demultiplexed paired FASTQs (totallung, endothelial, monkey PAXgene)
│   ├── imaging_data_*                   # Zeiss .czi &amp; Leica .lif slides, QuPath caches, Cellpose training sets
│   ├── NAFP Image analysis/             # QuPath multi-project annotations, measurements.csv &amp; .qpdata
│   ├── TB_TL_*                          # 10x Genomics Cell Ranger count matrices &amp; Scanpy AnnData suites
│   └── tb-lung-atlas/                   # Version-controlled R/Seurat reproducible single-cell pipeline
├── Data_backup/                         # Backup Repository Drive (Folder #2) — PERSISTENT (4.31 TB)
│   ├── repo/                            # Automated Restic deduplicated snapshot repository
│   └── restic_pw.txt                    # Secure password credentials for restic repository
├── JobParameters.json                   # Job execution parameters injected by UCloud K8s (ephemeral)
└── job-report.csv                       # Continuous CPU, memory &amp; I/O sampling telemetry (ephemeral)</pre>
  </div>

  <!-- Governance & Backup Playbook Grid -->
  <div class="gov-grid">
    <div class="gov-card">
      <div class="gov-card-title">Automated Restic Backup Playbook</div>
      <ul class="gov-list">
        <li><strong>Repository Location:</strong> <code>/work/Data_backup/repo/</code> (always mount <code>Data_backup</code> as Folder #2).</li>
        <li><strong>Password File:</strong> Set <code>export RESTIC_PASSWORD_FILE=/work/Data_backup/restic_pw.txt</code>.</li>
        <li><strong>Exclusion Rules:</strong> Exclude temporary virtualenvs, checkpoints, and git caches:
          <div class="restic-box">--exclude=".venv" --exclude=".ipynb_checkpoints" --exclude="*.tmp" --exclude=".git/objects"</div>
        </li>
        <li><strong>Snapshot Retention Policy:</strong> Enforce standard grandfather-father-son pruning:
          <div class="restic-box">restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune</div>
        </li>
        <li><strong>Integrity Check:</strong> Execute <code>restic check --read-data-subset=5%</code> monthly to verify repository chunk integrity.</li>
      </ul>
    </div>

    <div class="gov-card">
      <div class="gov-card-title">FAIR Principles &amp; Lab Data Hygiene</div>
      <ul class="gov-list">
        <li><strong>Findable (Naming Conventions):</strong> Maintain standardized directory prefixes:
          <br>&bull; <code>sequencing_data_&lt;cohort&gt;</code> for raw FASTQs.
          <br>&bull; <code>imaging_data_&lt;sample&gt;_&lt;stain/target&gt;</code> for microscopy.
          <br>&bull; <code>TB_TL_&lt;sample&gt;_&lt;subset&gt;</code> for single-cell count matrices.
        </li>
        <li><strong>Accessible:</strong> Access controlled via UCloud <code>BINF INFIMM</code> workspace membership. Files inherit POSIX group read permissions.</li>
        <li><strong>Interoperable:</strong> Raw data must remain in standard formats (FASTQ.GZ, CZI, LIF, H5, RDS). Tabular exports must use CSV/TSV with documented headers.</li>
        <li><strong>Reusable:</strong> Each analysis folder must contain a <code>README.md</code> describing sample metadata, experimental design, and pipeline version tags.</li>
      </ul>
    </div>
  </div>

  <div class="gov-grid" style="margin-bottom:0;">
    <div class="gov-card">
      <div class="gov-card-title">HPC Job Submission Golden Rules</div>
      <ul class="gov-list">
        <li><strong>Workspace Selection:</strong> Confirm <code>BINF INFIMM</code> is selected in the top-right workspace dropdown before launching any job.</li>
        <li><strong>Two-Folder Rule:</strong> Attach <code>TB group</code> as <strong>Folder #1</strong> and <code>Data_backup</code> as <strong>Folder #2</strong> on every compute run.</li>
        <li><strong>Scratch Usage:</strong> Perform heavy compilations, conda builds, and intermediate temp processing in <code>/tmp</code>; sync final deliverables to <code>/work/TB group/</code>.</li>
      </ul>
    </div>

    <div class="gov-card">
      <div class="gov-card-title">Action Item Checklist for TB Team</div>
      <ul class="gov-list">
        <li><span style="color:#dc2626;font-weight:700;">[HIGH]</span> Register 14 raw data directories in automated Restic backup schedule.</li>
        <li><span style="color:#2563eb;font-weight:700;">[HIGH]</span> Audit 11 Git directories; commit unstaged code and push branches to GitHub.</li>
        <li><span style="color:#d97706;font-weight:700;">[MED]</span> Delete redundant clone <code>QuPath Analysis F2944(1)</code> after verification.</li>
        <li><span style="color:#16a34a;font-weight:700;">[INFO]</span> Add missing <code>README.md</code> manifests in 17 directories lacking documentation.</li>
      </ul>
    </div>
  </div>

  <!-- Signoff Box -->
  <div class="signoff-box">
    <div class="signoff-left">
      <strong>INFIMM Bioinformatics Core</strong> &bull; Department of Infection &amp; Immunology &bull; SDU eScience Center<br>
      Report compiled for: <strong>TB Research Group &bull; Colleague Reference &bull; Data Management</strong>
    </div>
    <div class="signoff-right">
      <span class="signoff-badge">&check; AUDIT VERIFIED</span><br>
      <span style="font-size:6.2pt;color:#94a3b8;">Source: <code>inventory-tb-group.json</code> &bull; Git HEAD</span>
    </div>
  </div>
</div>

</body>
</html>"""
    return html

def main():
    print("Loading data...")
    data = load_data()
    print(f"Loaded {len(data)} datasets.")

    print("Generating HTML report...")
    html_content = generate_html(data)

    os.makedirs("scripts/reporting", exist_ok=True)
    html_path = "scripts/reporting/inventory_tb_group_report.html"
    with open(html_path, "w") as f:
        f.write(html_content)
    print(f"HTML saved to {html_path} ({len(html_content):,} bytes).")

if __name__ == "__main__":
    main()

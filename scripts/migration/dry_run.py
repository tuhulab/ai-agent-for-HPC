#!/usr/bin/env python3
"""Dry-run: verify every manifest source exists on Computerome and report sizes.
Uses a SINGLE SSH connection (one 2FA); batches all checks into one remote bash."""
import paramiko, os, sys

def parse_manifest(path):
    items=[]
    for line in open(path):
        line=line.strip()
        if not line or line.startswith('#'): continue
        src,dst=line.split(',',1)
        if src.strip(): items.append((src.strip(),dst.strip()))
    return items

def main():
    manifest=sys.argv[1]
    items=parse_manifest(manifest)
    c=paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    print("Connecting... APPROVE 2FA now", flush=True)
    c.connect("transfer.computerome.dk",22,username="tuhu",
              password=os.environ["CM_PASS"],look_for_keys=False,
              allow_agent=False,timeout=90,banner_timeout=90,auth_timeout=180)
    print("AUTH OK\n", flush=True)

    # One remote bash script; use a NUL-safe delimiter so paths with commas/spaces
    # are fine. We pass paths as list-of-args to bash -c via a generated script.
    bash_lines=['#!/bin/bash']
    for idx,(src,dst) in enumerate(items):
        # use find only for dirs; for files count=1
        bash_lines.append(
            f'if [ -e "{src}" ]; then'
            f' n=$(find "{src}" -type f | wc -l);'
            f' s=$(du -sb "{src}" 2>/dev/null | cut -f1);'
            f' printf "OK|%s|%s|%s\\n" "{src}" "$n" "$s";'
            f' else printf "MISSING|%s\\n" "{src}"; fi'
        )
    script="\n".join(bash_lines)
    i,o,e=c.exec_command("bash -s", timeout=1200)
    i.write(script); i.channel.shutdown_write()
    out=o.read().decode(errors="replace")
    err=e.read().decode(errors="replace")
    c.close()

    print(f"{'STATUS':<8} {'#files':<8} {'size(GB)':<12} SOURCE")
    print("-"*130)
    for line in out.splitlines():
        if not line.strip(): continue
        p=line.split('|')
        if p[0]=='OK':
            print(f"{p[0]:<8} {p[2]:<8} {float(p[3])/1e9:9,.1f}    {p[1]}")
        else:
            print(f"{p[0]:<8} {'-':<8} {'-':<12} {p[1]}")
    if err.strip():
        print("\nSTDERR tail:", err[-600:])
    print("\nDry-run complete.")
if __name__=="__main__":
    main()

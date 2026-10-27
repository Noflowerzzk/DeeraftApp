"""Collect non-system transitive DLL dependencies from the local UCRT64 prefix."""
import argparse
import pathlib
import re
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("prefix", type=pathlib.Path)
parser.add_argument("destination", type=pathlib.Path)
args = parser.parse_args()
known = {path.name.lower(): path for path in (args.prefix / "bin").glob("*.dll")}
pending = list(args.destination.rglob("*.exe")) + list(args.destination.rglob("*.dll"))
seen = set()
while pending:
    binary = pending.pop()
    if binary.name.lower() in seen:
        continue
    seen.add(binary.name.lower())
    result = subprocess.run([str(args.prefix / "bin/objdump.exe"), "-p", str(binary)],
                            check=True, capture_output=True, text=True, encoding="utf-8", errors="replace")
    for name in re.findall(r"DLL Name:\s*(\S+)", result.stdout):
        source = known.get(name.lower())
        if source:
            destination = args.destination / source.name
            if not destination.exists():
                shutil.copy2(source, destination)
            pending.append(destination)
print(f"Checked {len(seen)} executable and DLL dependencies")

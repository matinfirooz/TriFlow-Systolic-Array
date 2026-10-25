#!/usr/bin/env python3
"""Make a validated, source-only GitHub ZIP with reproducible per-file hashes."""
from __future__ import annotations
import argparse,hashlib,json,pathlib,re,zipfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
SKIP_PARTS={'.git','build','dist','__pycache__','.venv'}
def selected(path):
    rel=path.relative_to(ROOT)
    if any(part in SKIP_PARTS for part in rel.parts):return False
    if path.is_symlink():raise ValueError('Symlink in release tree: '+str(rel))
    if path.suffix in {'.pyc','.vvp'} or path.name=='MANIFEST.sha256':return False
    if path.suffix=='.vcd' and rel.as_posix()!='reports/sample_trace.vcd':return False
    if path.name in {'triflow_sim','core'}:return False
    return path.is_file()
def validate():
    report=json.loads((ROOT/'reports/verification.json').read_text())
    if report['failed'] or report['passed']!=29:raise ValueError('Full 29-configuration regression required')
    if any(r['status']!='PASS' for r in json.loads((ROOT/'reports/lint.json').read_text())['results']):raise ValueError('Lint must pass')
    summary=json.loads((ROOT/'reports/summary.json').read_text())
    for rel,digest in summary['source_sha256'].items():
        if hashlib.sha256((ROOT/rel).read_bytes()).hexdigest()!=digest:raise ValueError('Source changed since result collection: '+rel)
    for md in ROOT.rglob('*.md'):
        if any(x in SKIP_PARTS for x in md.relative_to(ROOT).parts):continue
        for target in re.findall(r'\]\(([^)]+)\)',md.read_text()):
            if '://' in target or target.startswith('#'):continue
            dest=target.split('#')[0]
            if dest and not (md.parent/dest).exists():raise ValueError(f'Broken local link in {md.relative_to(ROOT)}: {target}')
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output');args=ap.parse_args();validate()
    files=sorted(f for f in ROOT.rglob('*') if selected(f))
    manifest=''.join(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+f.relative_to(ROOT).as_posix()+'\n' for f in files)
    (ROOT/'MANIFEST.sha256').write_text(manifest)
    files.append(ROOT/'MANIFEST.sha256')
    out=pathlib.Path(args.output).resolve() if args.output else ROOT/'dist/TriFlow-SA-v2.zip'
    out.parent.mkdir(parents=True,exist_ok=True)
    if ROOT in out.parents and out.parent!=ROOT/'dist':raise ValueError('Use dist/ for in-repository output')
    with zipfile.ZipFile(out,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for f in sorted(files):z.write(f,'TriFlow-SA/'+f.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(out) as z:
        if z.testzip():raise ValueError('ZIP integrity check failed')
        for line in manifest.splitlines():
            digest,name=line.split('  ',1)
            if hashlib.sha256(z.read('TriFlow-SA/'+name)).hexdigest()!=digest:raise ValueError('Manifest mismatch')
    print(f'{out}: {len(files)} files, {out.stat().st_size:,} bytes, all manifest hashes verified')
if __name__=='__main__':main()

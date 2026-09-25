import sys, statistics as st
rows = {}; cfg = {}
for line in open(sys.argv[1]):
    f = line.split()
    if f[2] == 'SAMPLE':
        v, case, ms, n = f[0], f[3], int(f[4]), int(f[5])
        rows.setdefault((case, v), []).append(ms * 1000.0 / n)   # microseconds per call
    elif f[2] == 'CONFIG':
        cfg[f[3]] = int(f[4])
cases = sorted({c for c, _ in rows})
print("per-call latency, microseconds (each sample = one timed batch; ms clock)")
print(f"{'case':40} {'v':>3} {'n':>3} {'median':>9} {'min':>9} {'max':>9} {'IQR':>9}")
for c in cases:
    for v in ('v74', 'v80'):
        xs = sorted(rows.get((c, v), []))
        if not xs: continue
        q = st.quantiles(xs, n=4) if len(xs) > 1 else [xs[0]] * 3
        print(f"{c:40} {v[1:]:>3} {len(xs):>3} {st.median(xs):9.1f} {xs[0]:9.1f} {xs[-1]:9.1f} {q[2]-q[0]:9.1f}")
    a, b = rows.get((c, 'v74')), rows.get((c, 'v80'))
    if a and b:
        d = st.median(b) - st.median(a)
        print(f"{'':40} delta median {d:+.1f} us ({100.0*d/st.median(a):+.1f}%)")
print("retained config, bytes of canonical-encoded JSON")
for k2 in sorted(cfg): print(f"  {k2:24} {cfg[k2]}")

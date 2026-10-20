import re,sys,collections
cats=[
 ("trace-json", r'^\{"schema_version"'),
 ("lock-warning", r"^(Warning: dependency sunholo/motoko_ext_herdr|Run 'ailang lock')"),
 ("herdr-effect-site", r'^packages/motoko-ext-herdr/'),
 ("corpus-bank", r'^(CORPUSROW|JUDGE|JUDGEROW|seed-\d+ \[|identity:|trajectory:|manifest:|artifact:|✓ seed-\d+|why:|classes:|branches:|constructed-)'),
 ("timing", r'<T>|load \d|WHOLE TARGET|slowest'),
]
c=collections.Counter(); other=[]
for l in open(sys.argv[1]):
    if l[:1] not in "<>": continue
    s=l[2:].strip()
    for n,p in cats:
        if re.search(p,s): c[(n,l[0])]+=1; break
    else: other.append(l.rstrip())
for k,v in sorted(c.items()): print(v,*k)
print("other",len(other))
open(sys.argv[2],"w").write("\n".join(other)+"\n")

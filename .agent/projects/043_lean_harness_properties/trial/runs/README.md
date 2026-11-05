# W3: the trial's outputs and its answer key

Committed at W3, once all 24 arm sessions had ended (`../sequence.log`).

## What is here

- **`planter/`** holds the answer key, unsealed:
  - `manifest.tsv`, the 14 seeds
  - `seeds.patch` and `seeds/`, one patch per seed
  - `validation/`, the planter's logs that the manifest cites
  - `HASHES`

  These match the hashes committed at W1.
- **`t043-t<target>-<arm><replicate>/`**, one directory per arm session, laid out like
  `../dryrun/`:
  - `brief.md`, the brief as sent
  - `settings.json`, the session's deny rules
  - `meta`, the start and stop times and the hashes
  - `FILES.sha256`, the sha256 of every file the session wrote to its output directory
  - `LINKS.txt`, where present, the session's symlinks into its own tree
  - the session's text files of at most 100 KiB, with `reports.tsv` and `SUMMARY.md` among
    them. AILANG's caches are left out.

## What is not here, and where it is

Whole, the output directories hold 4,261 files and about 790 MB, mostly generated test data and
raw captures, with files of up to 89 MB. That would have tripled the size of the repository, so
W3 departs from the plan here (`../sequence.log`, the W3 deviation).

The whole of every output directory is in **`t043-runs.tar.xz`**. That is a release asset, a
file attached to the repository's
[`trial-043-data`](https://github.com/arniwesth/motoko_agent/releases/tag/trial-043-data)
release and kept outside git history. Its sha256 is in `../sequence.log`. Besides the 24
output directories, it holds:

- the dry run's two output directories
- the operator's `collect/` directory: the briefs, the deny rules and `meta` of every session,
  the clock and memwatch logs, the audits, and the outputs of batch 1's lost first attempt
  (without that attempt's copies of the tree)

To check it:

```bash
gh release download trial-043-data -R arniwesth/motoko_agent -p t043-runs.tar.xz
sha256sum t043-runs.tar.xz        # as in ../sequence.log
mkdir x && tar -xJf t043-runs.tar.xz -C x
# x/s/<session>/out hashes to the session's W2 out_sha256 with hash_dir in ../scripts/common.sh
```

The seeded tree is not kept. `../scripts/build_tree.sh` with `planter/seeds.patch` rebuilds it,
and W1 checked that the rebuilt tree matches `seeded_tree_sha256`.

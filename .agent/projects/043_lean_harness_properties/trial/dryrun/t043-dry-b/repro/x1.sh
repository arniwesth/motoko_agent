#!/usr/bin/env bash
# X-1: [asst(a), tool(a), tool(a)] -- a second result for an answered call. Exit 1 if the real fold accepts.
exec bash /home/motoko/trial-043/s/t043-dry-b/out/repro/fold1.sh x1 '1,4,4|accept||0'

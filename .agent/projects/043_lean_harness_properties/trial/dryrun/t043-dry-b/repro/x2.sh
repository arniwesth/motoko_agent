#!/usr/bin/env bash
# X-2: [asst(a), tool(a), user, tool(a)] -- a result after a user message. Exit 1 if the real fold accepts.
exec bash /home/motoko/trial-043/s/t043-dry-b/out/repro/fold1.sh x2 '1,4,7,4|accept||0'

# OpenKB Extension Test Document

This is a test document created during the OpenKB extension smoke test on 2026-05-08.

## Purpose

Verify that `OpenKbAdd` correctly indexes new documents into the knowledge base.

## Key Findings

1. `OpenKbStatus` works - reports 166 indexed documents
2. `OpenKbList` works - lists all 166 documents  
3. `OpenKbLint` times out (272s+) - known issue with large KBs
4. `OpenKbQuery` times out for substantive queries (~58s+) - known issue with model routing
5. `OpenKbAdd` reports "Path does not exist" for missing files

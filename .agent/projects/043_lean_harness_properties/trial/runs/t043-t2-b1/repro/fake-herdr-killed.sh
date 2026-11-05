#!/usr/bin/env bash
# A stand-in herdr binary for waiter_signal.ts: prints herdr's agent_not_found envelope on
# stderr, as herdr does, and is then killed by SIGTERM before it exits (the "server crash
# mid-call" / external kill case MEASUREMENTS-2026-08-31 lists as not measured).
echo '{"error":{"code":"agent_not_found","message":"x"},"id":"cli:agent:get"}' >&2
kill -TERM $$

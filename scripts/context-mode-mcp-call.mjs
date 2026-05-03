#!/usr/bin/env node
import { spawn } from 'node:child_process';

function parseArg(name, fallback = '') {
  const i = process.argv.indexOf(name);
  if (i < 0) return fallback;
  return process.argv[i + 1] ?? fallback;
}

const contextModeBin = parseArg('--context-mode-bin', 'context-mode');
const tool = parseArg('--tool', '');
const argsJson = parseArg('--args-json', '{}');
const timeoutMs = Number(parseArg('--timeout-ms', '25000')) || 25000;

if (!tool) {
  console.error('missing --tool');
  process.exit(2);
}

let toolArgs;
try {
  toolArgs = JSON.parse(argsJson || '{}');
} catch {
  console.error('invalid --args-json');
  process.exit(2);
}

const child = spawn(contextModeBin, [], {
  stdio: ['pipe', 'pipe', 'pipe'],
  env: process.env,
});

let stderr = '';
let stdoutBuf = '';
let settled = false;
let nextId = 1;

function finish(code, out = '', err = '') {
  if (settled) return;
  settled = true;
  clearTimeout(timer);
  try { child.kill('SIGTERM'); } catch {}
  if (out) process.stdout.write(out);
  if (err) process.stderr.write(err);
  process.exit(code);
}

function send(msg) {
  child.stdin.write(JSON.stringify(msg) + '\n');
}

function textFromResult(result) {
  const content = Array.isArray(result?.content) ? result.content : [];
  const lines = [];
  for (const part of content) {
    if (part && part.type === 'text' && typeof part.text === 'string') {
      lines.push(part.text);
    }
  }
  if (lines.length === 0) return JSON.stringify(result ?? {});
  return lines.join('\n');
}

const timer = setTimeout(() => {
  finish(1, '', 'context-mode bridge timeout\n');
}, timeoutMs);

child.stderr.on('data', (d) => {
  stderr += d.toString('utf8');
});

child.stdout.on('data', (d) => {
  stdoutBuf += d.toString('utf8');
  for (;;) {
    const idx = stdoutBuf.indexOf('\n');
    if (idx < 0) break;
    const line = stdoutBuf.slice(0, idx).trim();
    stdoutBuf = stdoutBuf.slice(idx + 1);
    if (!line) continue;
    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      continue;
    }

    if (msg.id === 1) {
      // initialize response
      send({ jsonrpc: '2.0', method: 'notifications/initialized', params: {} });
      send({
        jsonrpc: '2.0',
        id: 2,
        method: 'tools/call',
        params: { name: tool, arguments: toolArgs },
      });
      continue;
    }

    if (msg.id === 2) {
      if (msg.error) {
        finish(1, '', `MCP error: ${JSON.stringify(msg.error)}\n${stderr}`);
        return;
      }
      const result = msg.result ?? {};
      const text = textFromResult(result);
      if (result.isError) {
        finish(1, '', `${text}\n${stderr}`);
      } else {
        finish(0, text, stderr);
      }
      return;
    }
  }
});

child.on('error', (err) => {
  finish(1, '', `${String(err.message || err)}\n`);
});

child.on('exit', (code) => {
  if (!settled) {
    finish(code ?? 1, '', stderr || 'context-mode exited before response\n');
  }
});

send({
  jsonrpc: '2.0',
  id: nextId++,
  method: 'initialize',
  params: {
    protocolVersion: '2025-03-26',
    capabilities: {},
    clientInfo: { name: 'motoko-context-mode-bridge', version: '0.1.0' },
  },
});

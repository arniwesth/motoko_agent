#!/usr/bin/env node

function parseArg(name, fallback = '') {
  const i = process.argv.indexOf(name);
  if (i < 0) return fallback;
  return process.argv[i + 1] ?? fallback;
}

function hasFlag(name) {
  return process.argv.includes(name);
}

function printJson(obj) {
  process.stdout.write(`${JSON.stringify(obj)}\n`);
}

function extractSseOrPlainJson(text) {
  const raw = String(text ?? '').trim();
  if (!raw) return { error: 'empty response body' };

  const lines = raw.split(/\r?\n/);
  let candidate = raw;
  for (const line of lines) {
    const t = line.trim();
    if (t.startsWith('data:')) {
      candidate = t.slice(5).trim();
      break;
    }
  }

  try {
    return { value: JSON.parse(candidate) };
  } catch {
    return { error: `invalid JSON response: ${candidate.slice(0, 200)}` };
  }
}

function mcpErrorToString(err) {
  if (!err) return 'unknown MCP error';
  if (typeof err.message === 'string' && err.message.trim() !== '') return err.message;
  return JSON.stringify(err);
}

function textFromResult(result) {
  const content = Array.isArray(result?.content) ? result.content : [];
  const texts = [];
  for (const part of content) {
    if (part && typeof part.text === 'string') {
      texts.push(part.text);
    }
  }
  if (texts.length > 0) return texts.join('\n');
  if (typeof result?.text === 'string') return result.text;
  return JSON.stringify(result ?? {});
}

function buildRequestBody(method, tool, toolArgs) {
  if (method === 'tools/list') {
    return { jsonrpc: '2.0', method: 'tools/list', params: {}, id: 1 };
  }

  return {
    jsonrpc: '2.0',
    method: method || 'tools/call',
    params: {
      name: tool,
      arguments: toolArgs,
    },
    id: 1,
  };
}

function buildRequestUrl(baseUrl, authStyle, apiKey, toolsCsv) {
  const url = new URL(baseUrl);

  if (authStyle.startsWith('query:')) {
    const param = authStyle.slice('query:'.length).trim();
    if (param === '') return { error: 'invalid --auth-style query param' };
    url.searchParams.set(param, apiKey);
  } else if (!authStyle.startsWith('header:')) {
    return { error: 'invalid --auth-style (expected query:<param> or header:Bearer)' };
  }

  if (toolsCsv.trim() !== '') {
    url.searchParams.set('tools', toolsCsv.trim());
  }

  return { value: url };
}

async function main() {
  const baseUrl = parseArg('--base-url', '');
  const authEnvVar = parseArg('--auth-env-var', '');
  const authStyle = parseArg('--auth-style', '');
  const toolsCsv = parseArg('--tools', '');
  const method = parseArg('--method', 'tools/call') || 'tools/call';
  const tool = parseArg('--tool', '');
  const argsJson = parseArg('--args-json', '{}');
  const timeoutMs = Number(parseArg('--timeout-ms', '30000')) || 30000;
  const dryRun = hasFlag('--dry-run');

  if (!baseUrl || !authEnvVar || !authStyle) {
    printJson({ error: 'missing required flags: --base-url, --auth-env-var, --auth-style' });
    return;
  }

  if (method !== 'tools/list' && !tool) {
    printJson({ error: 'missing --tool for tools/call' });
    return;
  }

  let toolArgs = {};
  if (method !== 'tools/list') {
    try {
      toolArgs = JSON.parse(argsJson || '{}');
    } catch {
      printJson({ error: 'invalid --args-json' });
      return;
    }
  }

  const apiKey = process.env[authEnvVar] || '';
  if (apiKey === '') {
    printJson({ error: `missing API key in env var ${authEnvVar}` });
    return;
  }

  const builtUrl = buildRequestUrl(baseUrl, authStyle, apiKey, toolsCsv);
  if (builtUrl.error) {
    printJson({ error: builtUrl.error });
    return;
  }
  const url = builtUrl.value;

  const headers = {
    'Content-Type': 'application/json',
    Accept: 'application/json, text/event-stream',
  };

  if (authStyle.startsWith('header:')) {
    const headerMode = authStyle.slice('header:'.length).trim();
    if (headerMode !== 'Bearer') {
      printJson({ error: 'unsupported --auth-style header mode (expected header:Bearer)' });
      return;
    }
    headers.Authorization = `Bearer ${apiKey}`;
  }

  const body = buildRequestBody(method, tool, toolArgs);

  if (dryRun) {
    printJson({
      output: JSON.stringify({
        url: url.toString(),
        method: 'POST',
        headers,
        body,
      }),
    });
    return;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
      signal: controller.signal,
    });

    const rawText = await response.text();

    if (!response.ok) {
      const snippet = rawText.trim().slice(0, 240);
      const suffix = snippet ? `: ${snippet}` : '';
      printJson({ error: `HTTP ${response.status} ${response.statusText}${suffix}` });
      return;
    }

    const parsed = extractSseOrPlainJson(rawText);
    if (parsed.error) {
      printJson({ error: parsed.error });
      return;
    }

    const payload = parsed.value;
    if (payload?.error) {
      printJson({ error: mcpErrorToString(payload.error) });
      return;
    }

    if (method === 'tools/list') {
      const result = payload?.result;
      const tools = Array.isArray(result?.tools) ? result.tools : result;
      printJson({ output: JSON.stringify(tools ?? []) });
      return;
    }

    const result = payload?.result ?? {};
    const text = textFromResult(result);

    if (result?.isError === true) {
      printJson({ error: text || 'MCP tool returned isError=true' });
      return;
    }

    printJson({ output: text });
  } catch (err) {
    const msg = err && typeof err === 'object' && 'name' in err && err.name === 'AbortError'
      ? `request timed out after ${timeoutMs}ms`
      : String(err?.message || err);
    printJson({ error: msg });
  } finally {
    clearTimeout(timeout);
  }
}

main().catch((err) => {
  printJson({ error: String(err?.message || err) });
});

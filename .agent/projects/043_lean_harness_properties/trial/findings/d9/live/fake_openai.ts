// W5 follow-up (D9): a fake OpenAI-compatible endpoint on 127.0.0.1, so that a live Motoko
// session needs no network provider. It logs every request it receives, as one JSON line, to
// the file named by FAKE_LOG, and answers chat completions with the assistant text "ok" and
// finish_reason "stop" (streamed as SSE when the request asks for a stream). Anything else gets
// a 404, which the log then shows.
import { appendFileSync } from "node:fs";

const port = Number(process.env.FAKE_PORT ?? "18732");
const logFile = process.env.FAKE_LOG ?? "fake_openai.log.jsonl";
const reply = process.env.FAKE_REPLY ?? "ok";

function log(entry: unknown): void {
  appendFileSync(logFile, JSON.stringify(entry) + "\n");
}

Bun.serve({
  hostname: "127.0.0.1",
  port,
  async fetch(req) {
    const url = new URL(req.url);
    const text = req.method === "POST" ? await req.text() : "";
    let body: any = null;
    try { body = text ? JSON.parse(text) : null; } catch { body = { unparsed: text.slice(0, 2000) }; }
    log({ at: new Date().toISOString(), method: req.method, path: url.pathname, body });
    if (req.method === "GET" && url.pathname.endsWith("/models")) {
      return Response.json({ object: "list", data: [{ id: "fake-model", object: "model", owned_by: "w5" }] });
    }
    if (req.method === "POST" && url.pathname.endsWith("/chat/completions")) {
      const model = body?.model ?? "fake-model";
      const usage = { prompt_tokens: 10, completion_tokens: 1, total_tokens: 11 };
      if (body?.stream) {
        const chunk = (delta: unknown, finish: string | null, extra: object = {}) =>
          `data: ${JSON.stringify({ id: "chatcmpl-w5", object: "chat.completion.chunk", created: 0, model,
            choices: [{ index: 0, delta, finish_reason: finish }], ...extra })}\n\n`;
        const sse = chunk({ role: "assistant", content: reply }, null) + chunk({}, "stop") +
          `data: ${JSON.stringify({ id: "chatcmpl-w5", object: "chat.completion.chunk", created: 0, model, choices: [], usage })}\n\n` +
          "data: [DONE]\n\n";
        return new Response(sse, { headers: { "content-type": "text/event-stream" } });
      }
      return Response.json({ id: "chatcmpl-w5", object: "chat.completion", created: 0, model,
        choices: [{ index: 0, message: { role: "assistant", content: reply }, finish_reason: "stop" }], usage });
    }
    return new Response("not found", { status: 404 });
  },
});
log({ at: new Date().toISOString(), started: true, port });

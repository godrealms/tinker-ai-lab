// Tinker AI — Resilient SSE Stream Reader with Mid-Stream Error Detection
const API_URL = "http://127.0.0.1:11434/v1/chat/completions";
const IDLE_TIMEOUT_MS = Number("15000");

export async function consumeLlmStream(payload) {
  const res = await fetch(API_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ...payload, stream: true }),
  });

  if (!res.ok || !res.body) {
    throw new Error(`Pre-stream HTTP failure: ${res.status}`);
  }

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let output = "";

  while (true) {
    const timer = setTimeout(() => reader.cancel("SSE chunk idle timeout"), IDLE_TIMEOUT_MS);
    const { value, done } = await reader.read().finally(() => clearTimeout(timer));
    if (done) break;

    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split("\n");
    buffer = lines.pop() ?? "";

    for (const raw of lines) {
      const line = raw.trim();
      if (!line.startsWith("data:")) continue;
      const data = line.slice(5).trim();
      if (data === "[DONE]") return { output, completed: true };

      const event = JSON.parse(data);
      // Catch mid-stream error frame sent AFTER HTTP 200 OK
      if (event.error || event.type === "error") {
        throw new Error(`Mid-stream SSE error after HTTP 200: ${ JSON.stringify(event.error || event) }`);
      }
      const delta = event.choices?.[0]?.delta?.content ?? "";
      output += delta;
    }
  }
  return { output, completed: false };
}

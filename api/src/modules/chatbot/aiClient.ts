import { env } from "../../config/env";
import { AiProvider } from "../../lib/aiSecrets";

export type AiChatRole = "system" | "user" | "assistant";

export interface AiChatMessage {
  role: AiChatRole;
  content: string;
}

interface AiCompletionInput {
  provider: AiProvider;
  apiKey: string;
  model: string;
  temperature: number;
  messages: AiChatMessage[];
  maxTokens: number;
  maxResponseChars: number;
}

export interface AiCompletionResult {
  text: string;
  latencyMs: number;
}

const PROVIDER_ENDPOINTS: Record<AiProvider, string> = {
  deepseek: "https://api.deepseek.com/v1/chat/completions",
  openai: "https://api.openai.com/v1/chat/completions",
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function readCompletionText(payload: unknown): string | null {
  if (!isRecord(payload) || !Array.isArray(payload.choices)) return null;
  const firstChoice = payload.choices[0];
  if (!isRecord(firstChoice) || !isRecord(firstChoice.message)) return null;
  const content = firstChoice.message.content;
  return typeof content === "string" && content.trim() ? content.trim() : null;
}

/** Faz uma chamada somente aos endpoints oficiais, com timeout e resposta limitada. */
export async function requestAiCompletion(
  input: AiCompletionInput
): Promise<AiCompletionResult | null> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), env.AI_REQUEST_TIMEOUT_MS);
  const startedAt = Date.now();

  try {
    const response = await fetch(PROVIDER_ENDPOINTS[input.provider], {
      method: "POST",
      headers: {
        Authorization: `Bearer ${input.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: input.model,
        messages: input.messages,
        max_tokens: input.maxTokens,
        temperature: input.temperature,
      }),
      signal: controller.signal,
    });
    if (!response.ok) return null;

    const payload: unknown = await response.json();
    const text = readCompletionText(payload);
    if (!text) return null;

    return {
      text: text.slice(0, input.maxResponseChars),
      latencyMs: Date.now() - startedAt,
    };
  } catch {
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

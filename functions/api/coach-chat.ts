const MODEL = '@cf/google/gemma-4-26b-a4b-it';

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  });
}

function extractJson(text: string): Record<string, unknown> | null {
  const cleaned = text
    .trim()
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/i, '')
    .trim();
  try {
    return JSON.parse(cleaned) as Record<string, unknown>;
  } catch (_) {
    const start = cleaned.indexOf('{');
    const end = cleaned.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      return JSON.parse(cleaned.slice(start, end + 1)) as Record<string, unknown>;
    } catch (_) {
      return null;
    }
  }
}

function textFromContent(content: unknown): string {
  if (typeof content === 'string') return content.trim();
  if (!Array.isArray(content)) return '';
  return content
    .map((part) => {
      if (typeof part === 'string') return part;
      if (!part || typeof part !== 'object') return '';
      const value = part as Record<string, unknown>;
      if (typeof value.text === 'string') return value.text;
      if (typeof value.content === 'string') return value.content;
      return '';
    })
    .filter(Boolean)
    .join('\n')
    .trim();
}

function extractModelText(result: any): string {
  if (typeof result === 'string') return result.trim();
  if (!result || typeof result !== 'object') return '';
  if (typeof result.output_text === 'string') return result.output_text.trim();
  if (typeof result.text === 'string') return result.text.trim();
  if (typeof result.response === 'string') return result.response.trim();

  if (Array.isArray(result.choices) && result.choices.length > 0) {
    const choice = result.choices[0];
    const fromMessage = textFromContent(choice?.message?.content);
    if (fromMessage) return fromMessage;
    if (typeof choice?.text === 'string') return choice.text.trim();
  }

  if (result.result && typeof result.result === 'object') {
    if (typeof result.result.response === 'string') return result.result.response.trim();
    if (typeof result.result.text === 'string') return result.result.text.trim();
    const nested = textFromContent(result.result.content);
    if (nested) return nested;
  }

  return '';
}

function directObject(result: any): Record<string, unknown> | null {
  if (!result || typeof result !== 'object') return null;
  const candidates = [
    result?.choices?.[0]?.message?.parsed,
    result,
    result.response,
    result.result,
    result.data,
  ];
  for (const candidate of candidates) {
    if (!candidate || typeof candidate !== 'object' || Array.isArray(candidate)) {
      continue;
    }
    if ('reply' in candidate) {
      return candidate as Record<string, unknown>;
    }
  }
  return null;
}

type ChatMessage = { role: string; text: string };

function normalizeHistory(value: unknown): ChatMessage[] {
  if (!Array.isArray(value)) return [];
  const messages = value
    .map((item) => {
      if (!item || typeof item !== 'object') return null;
      const row = item as Record<string, unknown>;
      const role = row.role === 'user' ? 'user' : 'coach';
      const text = typeof row.text === 'string' ? row.text.trim() : '';
      if (!text) return null;
      return { role, text };
    })
    .filter((m): m is ChatMessage => m !== null);
  // Defensive server-side cap, regardless of what the client already
  // truncated to -- this is the boundary that actually controls prompt size.
  return messages.slice(-8);
}

const systemPrompt = `
You are a warm, practical, supportive personal coach inside a Hebrew-language
healthy-lifestyle app (nutrition, fitness, daily planning, motivation) --
NOT a doctor and NOT a psychologist.

Ground every answer only in the "context" JSON given to you (today's calorie/
protein targets and progress, kosher status text, today's workout, water,
weight trend, food suggestions, daily insight) plus the recent conversation
history. Never invent numbers that aren't in context.

Kosher: NEVER decide or guess kosher status yourself. Only ever repeat or
refer to context.kosherStateText as given -- kosher status is always an
explicit user choice elsewhere in this app, never something you infer.

Medical / mental health: never diagnose a medical or mental-health condition
and never give medical advice (medication, calorie targets far outside what
context already sets, treating an eating disorder, etc). If the question
raises something concerning (signs of disordered eating, real emotional
distress, self-harm, etc.), respond gently, briefly acknowledge the feeling,
and suggest talking to a suitable professional (doctor, dietitian,
therapist) -- do not attempt to counsel or treat it yourself.

Scope: stay on this app's topics -- nutrition, fitness, motivation, and this
user's daily plan. If asked something entirely unrelated, gently steer the
conversation back.

Style: Hebrew, warm and conversational, relatively short -- a chat bubble
reply, a few sentences at most, not an essay.

Return exactly one JSON object with a single key: reply (the Hebrew chat
reply as a string).
`;

async function runCoachChat(
  ai: any,
  question: string,
  history: ChatMessage[],
  context: unknown,
) {
  const historyMessages = history.map((m) => ({
    role: m.role === 'user' ? 'user' : 'assistant',
    content: m.text,
  }));

  return ai.run(MODEL, {
    messages: [
      { role: 'system', content: systemPrompt },
      {
        role: 'user',
        content: `context (JSON, already computed by the app -- do not recompute or contradict it):\n${JSON.stringify(context)}`,
      },
      ...historyMessages,
      { role: 'user', content: question },
    ],
    response_format: { type: 'json_object' },
    chat_template_kwargs: { enable_thinking: false },
    max_completion_tokens: 500,
    // Higher than the data-extraction Workers (nutrition-label-recognize,
    // meal-estimate use 0) on purpose -- this one needs a warm, varied
    // conversational tone, not a single deterministic extraction.
    temperature: 0.65,
  });
}

function diagnosticShape(result: any) {
  const choice = Array.isArray(result?.choices) ? result.choices[0] : null;
  const message = choice?.message;
  return {
    responseShape: Object.keys(result ?? {}).slice(0, 12).join(','),
    choiceShape:
      choice && typeof choice === 'object'
        ? Object.keys(choice).slice(0, 12).join(',')
        : '',
    messageShape:
      message && typeof message === 'object'
        ? Object.keys(message).slice(0, 12).join(',')
        : '',
    finishReason:
      typeof choice?.finish_reason === 'string' ? choice.finish_reason : '',
    completionTokens: Number(result?.usage?.completion_tokens ?? 0),
  };
}

export async function onRequestGet(context: any) {
  return jsonResponse({
    status: 'ok',
    aiBinding: Boolean(context.env?.AI),
    model: MODEL,
    pipeline: 'coach-chat-json-object-v1',
  });
}

export async function onRequestPost(context: any) {
  const request = context.request as Request;
  const ai = context.env?.AI;

  let body: any;
  try {
    body = await request.json();
  } catch (_) {
    return jsonResponse({ error: 'invalid_json' }, 400);
  }

  const question =
    typeof body?.question === 'string' ? body.question.trim().slice(0, 2000) : '';
  if (!question) {
    return jsonResponse({ error: 'invalid_input' }, 400);
  }

  const history = normalizeHistory(body?.history);
  const requestContext =
    body?.context && typeof body.context === 'object' ? body.context : {};

  if (!ai) {
    return jsonResponse({ error: 'ai_binding_missing' }, 503);
  }

  let result: any = null;
  try {
    result = await runCoachChat(ai, question, history, requestContext);

    const direct = directObject(result);
    const raw = extractModelText(result);
    const parsed = direct ?? (raw ? extractJson(raw) : null);

    const reply = typeof parsed?.reply === 'string' ? parsed.reply.trim() : '';
    if (!reply) {
      return jsonResponse(
        {
          error: 'empty_model_response',
          ...diagnosticShape(result),
        },
        502,
      );
    }

    return jsonResponse({
      reply,
      model: MODEL,
      pipeline: 'coach-chat-json-object-v1',
    });
  } catch (error) {
    console.error('coach chat failed', error);
    return jsonResponse(
      {
        error: 'ai_request_failed',
        ...diagnosticShape(result),
      },
      502,
    );
  }
}

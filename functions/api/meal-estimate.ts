const MODEL = '@cf/google/gemma-4-26b-a4b-it';

type Estimate = {
  recognized: boolean;
  name: string;
  caloriesPer100g: number;
  proteinPer100g: number;
  carbsPer100g: number;
  fatPer100g: number;
  servingName: string;
  servingGrams: number;
  confidence: number;
  reason: string;
};

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
    if ('recognized' in candidate || 'caloriesPer100g' in candidate) {
      return candidate as Record<string, unknown>;
    }
  }
  return null;
}

function numberValue(value: unknown, max: number): number {
  const number = Number(value);
  if (!Number.isFinite(number)) return 0;
  return Math.max(0, Math.min(max, number));
}

function normalizeEstimate(
  parsed: Record<string, unknown>,
  servingName: string,
): Estimate {
  const name = typeof parsed.name === 'string' ? parsed.name.trim() : '';
  const caloriesPer100g = numberValue(parsed.caloriesPer100g, 900);
  const proteinPer100g = numberValue(parsed.proteinPer100g, 100);
  const carbsPer100g = numberValue(parsed.carbsPer100g, 100);
  const fatPer100g = numberValue(parsed.fatPer100g, 100);
  const servingGrams = numberValue(parsed.servingGrams, 3000);
  const hasValues =
    caloriesPer100g > 0 || proteinPer100g > 0 || carbsPer100g > 0 || fatPer100g > 0;
  const recognized = parsed.recognized === true && name.length > 0 && hasValues;
  const rawConfidence = numberValue(parsed.confidence, 1);

  return {
    recognized,
    name: recognized ? name : '',
    caloriesPer100g: recognized ? caloriesPer100g : 0,
    proteinPer100g: recognized ? proteinPer100g : 0,
    carbsPer100g: recognized ? carbsPer100g : 0,
    fatPer100g: recognized ? fatPer100g : 0,
    servingName: recognized ? servingName : '',
    servingGrams: recognized ? servingGrams : 0,
    confidence: rawConfidence,
    reason: typeof parsed.reason === 'string' ? parsed.reason.trim() : '',
  };
}

const promptRules = `
Estimate a home-cooked or unpackaged meal -- a full plate/portion of food, NOT a
packaged product and NOT a nutrition facts label.

Return, for THIS specific portion:
- caloriesPer100g, proteinPer100g, carbsPer100g, fatPer100g: your best estimate
  of this food's nutrition values PER 100 GRAMS (not for the whole portion).
- servingGrams: your best estimate of the TOTAL weight of the portion described,
  in grams.

Rules:
- Use Hebrew for name and reason.
- Do not invent a specific brand, packaging or exact ingredient list -- this is
  a visual/descriptive estimate of a home meal, not a scanned label.
- Do not infer or mention kosher status, meat/dairy/pareve classification,
  allergens or certification -- that is never part of this estimate.
- If what's shown/described is too vague to estimate at all (e.g. no food
  visible, or a description with no identifiable dish), set recognized=false,
  empty name, all numeric fields 0, and explain briefly in reason.
- confidence should reflect how certain the estimate is, lower for vague
  photos/descriptions or unusual/mixed dishes.

Return exactly one JSON object with these keys: recognized, name,
caloriesPer100g, proteinPer100g, carbsPer100g, fatPer100g, servingGrams,
confidence, reason.
`;

async function runVisionEstimate(ai: any, dataUrl: string) {
  return ai.run(MODEL, {
    messages: [
      {
        role: 'system',
        content: 'You are a careful nutrition estimator for home-cooked meals shown in photos.',
      },
      {
        role: 'user',
        content: [
          { type: 'text', text: `Estimate the meal shown in this photo.\n${promptRules}` },
          { type: 'image_url', image_url: { url: dataUrl } },
        ],
      },
    ],
    response_format: { type: 'json_object' },
    chat_template_kwargs: { enable_thinking: false },
    max_completion_tokens: 1900,
    temperature: 0,
  });
}

async function runTextEstimate(ai: any, description: string) {
  return ai.run(MODEL, {
    messages: [
      {
        role: 'system',
        content: 'You are a careful nutrition estimator for home-cooked meals described in free text.',
      },
      {
        role: 'user',
        content: `Estimate the meal described below.\n${promptRules}\n\nDescription:\n${description.slice(0, 2000)}`,
      },
    ],
    response_format: { type: 'json_object' },
    chat_template_kwargs: { enable_thinking: false },
    max_completion_tokens: 1900,
    temperature: 0,
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
    pipeline: 'meal-estimate-json-object-v1',
  });
}

export async function onRequestPost(context: any) {
  const request = context.request as Request;
  const ai = context.env?.AI;
  const contentLength = Number(request.headers.get('content-length') ?? '0');
  if (contentLength > 6_000_000) {
    return jsonResponse({ error: 'image_too_large' }, 413);
  }

  let body: any;
  try {
    body = await request.json();
  } catch (_) {
    return jsonResponse({ error: 'invalid_json' }, 400);
  }

  const imageBase64 =
    typeof body?.imageBase64 === 'string' ? body.imageBase64.trim() : '';
  const mimeType =
    typeof body?.mimeType === 'string'
      ? body.mimeType.trim().toLowerCase()
      : 'image/jpeg';
  const text = typeof body?.text === 'string' ? body.text.trim() : '';

  // An image, when present, always takes priority over accompanying text.
  const usingImage = imageBase64.length > 0;

  if (!usingImage && !text) {
    return jsonResponse({ error: 'invalid_input' }, 400);
  }

  if (usingImage) {
    if (imageBase64.length > 5_500_000) {
      return jsonResponse({ error: 'invalid_image' }, 400);
    }
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(mimeType)) {
      return jsonResponse({ error: 'unsupported_image_type' }, 415);
    }
  }

  if (!ai) {
    return jsonResponse({ error: 'ai_binding_missing' }, 503);
  }

  let result: any = null;
  try {
    if (usingImage) {
      const dataUrl = imageBase64.startsWith('data:')
        ? imageBase64
        : `data:${mimeType};base64,${imageBase64}`;
      result = await runVisionEstimate(ai, dataUrl);
    } else {
      result = await runTextEstimate(ai, text);
    }

    const direct = directObject(result);
    const raw = extractModelText(result);
    const parsed = direct ?? (raw ? extractJson(raw) : null);

    if (!parsed) {
      return jsonResponse(
        {
          error: 'empty_model_response',
          ...diagnosticShape(result),
        },
        502,
      );
    }

    const servingName = usingImage ? 'מנה כפי שנראתה בתמונה' : 'מנה כפי שתוארה';
    return jsonResponse({
      ...normalizeEstimate(parsed, servingName),
      model: MODEL,
      pipeline: usingImage ? 'meal-estimate-vision' : 'meal-estimate-text',
    });
  } catch (error) {
    console.error('meal estimate failed', error);
    return jsonResponse(
      {
        error: 'ai_request_failed',
        ...diagnosticShape(result),
      },
      502,
    );
  }
}

const MODEL = '@cf/google/gemma-4-26b-a4b-it';
const STRUCTURE_MODEL = '@cf/meta/llama-3.1-8b-instruct-fast';

const labelSchema = {
  type: 'object',
  additionalProperties: false,
  properties: {
    recognized: { type: 'boolean' },
    name: { type: 'string' },
    basisGrams: { type: 'number', minimum: 0, maximum: 5000 },
    calories: { type: 'number', minimum: 0, maximum: 10000 },
    protein: { type: 'number', minimum: 0, maximum: 5000 },
    carbs: { type: 'number', minimum: 0, maximum: 5000 },
    fat: { type: 'number', minimum: 0, maximum: 5000 },
    servingName: { type: 'string' },
    servingGrams: { type: 'number', minimum: 0, maximum: 5000 },
    confidence: { type: 'number', minimum: 0, maximum: 1 },
    reason: { type: 'string' },
  },
  required: [
    'recognized',
    'name',
    'basisGrams',
    'calories',
    'protein',
    'carbs',
    'fat',
    'servingName',
    'servingGrams',
    'confidence',
    'reason',
  ],
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
  if (typeof result.description === 'string') return result.description.trim();
  if (typeof result.output_text === 'string') return result.output_text.trim();
  if (typeof result.text === 'string') return result.text.trim();
  if (typeof result.response === 'string') return result.response.trim();
  if (result.response && typeof result.response === 'object') {
    const nested = textFromContent(result.response.content) ||
      (typeof result.response.text === 'string' ? result.response.text.trim() : '') ||
      (typeof result.response.description === 'string'
        ? result.response.description.trim()
        : '');
    if (nested) return nested;
  }
  if (Array.isArray(result.choices) && result.choices.length > 0) {
    const choice = result.choices[0];
    const fromMessage = textFromContent(choice?.message?.content);
    if (fromMessage) return fromMessage;
    if (typeof choice?.text === 'string') return choice.text.trim();
  }
  if (result.result && typeof result.result === 'object') {
    const nested = result.result;
    if (typeof nested.description === 'string') return nested.description.trim();
    if (typeof nested.response === 'string') return nested.response.trim();
    if (typeof nested.text === 'string') return nested.text.trim();
    const nestedContent = textFromContent(nested.content);
    if (nestedContent) return nestedContent;
  }
  if (result.data && typeof result.data === 'object') {
    if (typeof result.data.description === 'string') return result.data.description.trim();
    if (typeof result.data.response === 'string') return result.data.response.trim();
  }
  if (typeof result.result === 'string') return result.result.trim();
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
    if ('recognized' in candidate || 'basisGrams' in candidate || 'calories' in candidate) {
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

function normalizeLabel(parsed: Record<string, unknown>) {
  const basisGrams = numberValue(parsed.basisGrams, 5000);
  const rawCalories = numberValue(parsed.calories, 10000);
  const rawProtein = numberValue(parsed.protein, 5000);
  const rawCarbs = numberValue(parsed.carbs, 5000);
  const rawFat = numberValue(parsed.fat, 5000);
  const hasValues = rawCalories > 0 || rawProtein > 0 || rawCarbs > 0 || rawFat > 0;
  const recognized = parsed.recognized === true && basisGrams > 0 && hasValues;
  const factor = recognized ? 100 / basisGrams : 0;
  const per100 = (value: number, max: number) =>
    Math.max(0, Math.min(max, value * factor));

  return {
    recognized,
    name: typeof parsed.name === 'string' ? parsed.name.trim() : '',
    caloriesPer100g: per100(rawCalories, 2000),
    proteinPer100g: per100(rawProtein, 100),
    carbsPer100g: per100(rawCarbs, 100),
    fatPer100g: per100(rawFat, 100),
    servingName: typeof parsed.servingName === 'string'
      ? parsed.servingName.trim()
      : '',
    servingGrams: numberValue(parsed.servingGrams, 5000),
    confidence: numberValue(parsed.confidence, 1),
    reason: typeof parsed.reason === 'string' ? parsed.reason.trim() : '',
  };
}

async function structureDescription(ai: any, description: string) {
  const result = await ai.run(STRUCTURE_MODEL, {
    messages: [
      {
        role: 'system',
        content: 'Convert a visual description of a nutrition label into the requested structured object. Never invent values.',
      },
      {
        role: 'user',
        content: `Visual description:\n${description.slice(0, 6000)}\n\nReturn only values that are explicitly supported by the description. Use Hebrew for text fields.`,
      },
    ],
    response_format: { type: 'json_schema', json_schema: labelSchema },
    max_completion_tokens: 700,
    temperature: 0,
  });
  const direct = directObject(result);
  if (direct) return direct;
  const raw = extractModelText(result);
  return raw ? extractJson(raw) : null;
}

async function runVision(ai: any, dataUrl: string, prompt: string) {
  return ai.run(MODEL, {
    messages: [
      {
        role: 'system',
        content: 'You carefully read food nutrition labels from images and never fabricate missing values.',
      },
      {
        role: 'user',
        content: [
          { type: 'text', text: prompt },
          { type: 'image_url', image_url: { url: dataUrl } },
        ],
      },
    ],
    max_completion_tokens: 1400,
    reasoning_effort: 'low',
    temperature: 0.1,
  });
}

function diagnosticShape(result: any) {
  const choice = Array.isArray(result?.choices) ? result.choices[0] : null;
  const message = choice?.message;
  return {
    responseShape: Object.keys(result ?? {}).slice(0, 12).join(','),
    choiceShape: choice && typeof choice === 'object'
      ? Object.keys(choice).slice(0, 12).join(',')
      : '',
    messageShape: message && typeof message === 'object'
      ? Object.keys(message).slice(0, 12).join(',')
      : '',
    finishReason: typeof choice?.finish_reason === 'string' ? choice.finish_reason : '',
    contentType: Array.isArray(message?.content)
      ? 'array'
      : typeof message?.content,
    completionTokens: Number(result?.usage?.completion_tokens ?? 0),
  };
}

export async function onRequestGet(context: any) {
  return jsonResponse({
    status: 'ok',
    aiBinding: Boolean(context.env?.AI),
    model: MODEL,
    structureModel: STRUCTURE_MODEL,
    pipeline: 'nutrition-label-vision-v2',
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

  const imageBase64 = typeof body?.imageBase64 === 'string'
    ? body.imageBase64.trim()
    : '';
  const mimeType = typeof body?.mimeType === 'string'
    ? body.mimeType.trim().toLowerCase()
    : 'image/jpeg';

  if (!imageBase64 || imageBase64.length > 5_500_000) {
    return jsonResponse({ error: 'invalid_image' }, 400);
  }
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(mimeType)) {
    return jsonResponse({ error: 'unsupported_image_type' }, 415);
  }
  if (!ai) {
    return jsonResponse({ error: 'ai_binding_missing' }, 503);
  }

  const dataUrl = imageBase64.startsWith('data:')
    ? imageBase64
    : `data:${mimeType};base64,${imageBase64}`;

  const prompt = `
Read the nutrition facts visible in this food-label image.

Goal: propose nutrition values that the user can review before saving a food item.

Rules:
- Prefer the column explicitly stated per 100 grams.
- If there is no per-100g column, you may use a per-serving column only when the serving weight in grams is clearly visible. Put that serving weight in basisGrams so the server can normalize deterministically.
- If the visible basis is per 100 ml and no gram equivalent is shown, do not pretend it is grams.
- calories means kcal / Calories, not kJ. If only kJ is visible, leave calories as 0 rather than converting it yourself.
- protein, carbs and fat are grams for the same basisGrams column.
- Use the product/food name only if it is clearly visible; otherwise return an empty name.
- servingName and servingGrams are optional convenience fields and must be visible on the label.
- Do not infer kosher status, meat/dairy/pareve classification, ingredients, allergens, brand or category. They are not part of this output.
- Never invent a missing number.
- If a readable gram-based nutrition table is not visible, return recognized=false and low confidence.
- Use Hebrew for name, servingName and reason.

Return exactly one JSON object and no surrounding prose. It must contain all of these keys:
recognized, name, basisGrams, calories, protein, carbs, fat, servingName, servingGrams, confidence, reason.
`;

  try {
    let result = await runVision(ai, dataUrl, prompt);
    let direct = directObject(result);
    let raw = extractModelText(result);
    let parsed = direct ?? (raw ? extractJson(raw) : null);
    let pipeline = direct ? 'vision-direct-object' : 'vision-json-text';

    if (!parsed && !raw && !direct) {
      result = await runVision(
        ai,
        dataUrl,
        `${prompt}\nThis is a retry. Focus only on the visible nutrition table and return the JSON object.`,
      );
      direct = directObject(result);
      raw = extractModelText(result);
      parsed = direct ?? (raw ? extractJson(raw) : null);
      pipeline = direct ? 'vision-retry-direct-object' : 'vision-retry-json-text';
    }

    if (!parsed && raw) {
      try {
        parsed = await structureDescription(ai, raw);
        if (parsed) pipeline = 'vision-text-structured-fallback';
      } catch (fallbackError) {
        console.warn('nutrition label structured fallback failed', fallbackError);
      }
    }

    if (!parsed) {
      if (!raw && !direct) {
        const diagnostic = diagnosticShape(result);
        console.warn('nutrition label recognition returned no readable output', diagnostic);
        return jsonResponse({ error: 'empty_model_response', ...diagnostic }, 502);
      }
      return jsonResponse({ error: 'invalid_model_response_after_fallback' }, 502);
    }

    return jsonResponse({
      ...normalizeLabel(parsed),
      model: MODEL,
      structureModel: STRUCTURE_MODEL,
      pipeline,
    });
  } catch (error) {
    console.error('nutrition label recognition failed', error);
    return jsonResponse({ error: 'ai_request_failed' }, 502);
  }
}

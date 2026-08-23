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
    const message = choice?.message;
    const fromMessage = textFromContent(message?.content);
    if (fromMessage) return fromMessage;
    if (typeof message?.reasoning === 'string' && message.reasoning.trim()) {
      return message.reasoning.trim();
    }
    if (
      typeof message?.reasoning_content === 'string' &&
      message.reasoning_content.trim()
    ) {
      return message.reasoning_content.trim();
    }
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
        content:
          'Convert OCR or a visual description of a nutrition label into the requested structured object. Never invent values.',
      },
      {
        role: 'user',
        content:
          `Nutrition-label OCR/description:\n${description.slice(0, 9000)}\n\n` +
          'Prefer an explicitly visible per-100g column. If values are for a different gram basis, put that basis in basisGrams. ' +
          'Calories must be kcal, not kJ. Use Hebrew for text fields. Return only values supported by the source.',
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
        content:
          'You carefully read food nutrition labels from images and never fabricate missing values.',
      },
      {
        role: 'user',
        content: [
          { type: 'text', text: prompt },
          { type: 'image_url', image_url: { url: dataUrl } },
        ],
      },
    ],
    response_format: { type: 'json_object' },
    chat_template_kwargs: { enable_thinking: false },
    max_completion_tokens: 1400,
    temperature: 0.1,
  });
}

function base64ToBytes(imageBase64: string): Uint8Array {
  const comma = imageBase64.indexOf(',');
  const raw = comma >= 0 ? imageBase64.slice(comma + 1) : imageBase64;
  const binary = atob(raw);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function extensionForMime(mimeType: string) {
  if (mimeType === 'image/png') return 'png';
  if (mimeType === 'image/webp') return 'webp';
  return 'jpg';
}

function markdownData(result: any): string {
  const item = Array.isArray(result) ? result[0] : result;
  if (!item || typeof item !== 'object') return '';
  return typeof item.data === 'string' ? item.data.trim() : '';
}

async function markdownOcrFallback(
  ai: any,
  imageBase64: string,
  mimeType: string,
): Promise<Record<string, unknown> | null> {
  const bytes = base64ToBytes(imageBase64);
  const converted = await ai.toMarkdown(
    {
      name: `nutrition-label.${extensionForMime(mimeType)}`,
      blob: new Blob([bytes], { type: mimeType }),
    },
    {
      conversionOptions: {
        output: { format: 'text' },
      },
    },
  );
  const text = markdownData(converted);
  if (!text) return null;
  return structureDescription(ai, text);
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
    pipeline: 'nutrition-label-vision-v3',
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

  let result: any = null;
  let lastDiagnostic: Record<string, unknown> = {};

  try {
    for (let attempt = 0; attempt < 2; attempt += 1) {
      try {
        result = await runVision(
          ai,
          dataUrl,
          attempt === 0
            ? prompt
            : `${prompt}\nRetry: focus only on the visible nutrition table.`,
        );
        const direct = directObject(result);
        const raw = extractModelText(result);
        const parsed = direct ?? (raw ? extractJson(raw) : null);

        if (parsed) {
          return jsonResponse({
            ...normalizeLabel(parsed),
            model: MODEL,
            structureModel: STRUCTURE_MODEL,
            pipeline:
              attempt === 0 ? 'vision-json-object' : 'vision-json-object-retry',
          });
        }

        if (raw) {
          try {
            const structured = await structureDescription(ai, raw);
            if (structured) {
              return jsonResponse({
                ...normalizeLabel(structured),
                model: MODEL,
                structureModel: STRUCTURE_MODEL,
                pipeline: 'vision-text-structured-fallback',
              });
            }
          } catch (structureError) {
            console.warn('nutrition label structure fallback failed', structureError);
          }
        }

        lastDiagnostic = diagnosticShape(result);
      } catch (visionError) {
        console.warn('nutrition label direct vision attempt failed', visionError);
        lastDiagnostic = { visionAttemptFailed: true, attempt: attempt + 1 };
      }
    }

    try {
      const parsed = await markdownOcrFallback(ai, imageBase64, mimeType);
      if (parsed) {
        return jsonResponse({
          ...normalizeLabel(parsed),
          model: MODEL,
          structureModel: STRUCTURE_MODEL,
          pipeline: 'cloudflare-markdown-ocr-structured',
        });
      }
    } catch (markdownError) {
      console.warn('nutrition label markdown OCR fallback failed', markdownError);
      return jsonResponse(
        {
          error: 'ocr_fallback_failed',
          ...lastDiagnostic,
        },
        502,
      );
    }

    return jsonResponse(
      {
        error: 'empty_model_response',
        ...lastDiagnostic,
      },
      502,
    );
  } catch (error) {
    console.error('nutrition label recognition failed', error);
    return jsonResponse({ error: 'ai_request_failed' }, 502);
  }
}

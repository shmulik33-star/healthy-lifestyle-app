const MODEL = '@cf/google/gemma-4-26b-a4b-it';

const allowedCategories = [
  'משקולות',
  'מוטות',
  'ספסלים',
  'גומיות התנגדות',
  'קטלבל',
  'מכשירי אירובי',
  'מכשירי כוח',
  'מזרן / אביזרים',
  'אחר',
] as const;

type Recognition = {
  recognized: boolean;
  name: string;
  category: string;
  categoryDetail: string;
  notes: string;
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

  // Cloudflare's current ImageTextToText schema may return the generated text
  // as `description` rather than the Text Generation `response` field.
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
    const nestedResult = result.result;
    if (typeof nestedResult.description === 'string') {
      return nestedResult.description.trim();
    }
    if (typeof nestedResult.response === 'string') {
      return nestedResult.response.trim();
    }
    if (typeof nestedResult.text === 'string') return nestedResult.text.trim();
    const nestedContent = textFromContent(nestedResult.content);
    if (nestedContent) return nestedContent;
  }

  if (result.data && typeof result.data === 'object') {
    if (typeof result.data.description === 'string') {
      return result.data.description.trim();
    }
    if (typeof result.data.response === 'string') {
      return result.data.response.trim();
    }
  }

  if (typeof result.result === 'string') return result.result.trim();
  return '';
}

function directRecognitionObject(result: any): Record<string, unknown> | null {
  if (!result || typeof result !== 'object') return null;
  const candidates = [result, result.response, result.result, result.data];
  for (const candidate of candidates) {
    if (!candidate || typeof candidate !== 'object' || Array.isArray(candidate)) {
      continue;
    }
    if ('recognized' in candidate || 'name' in candidate || 'category' in candidate) {
      return candidate as Record<string, unknown>;
    }
  }
  return null;
}

function normalizeRecognition(parsed: Record<string, unknown>): Recognition {
  const name = typeof parsed.name === 'string' ? parsed.name.trim() : '';
  const rawCategory = typeof parsed.category === 'string'
    ? parsed.category.trim()
    : 'אחר';
  const category = allowedCategories.includes(rawCategory as any)
    ? rawCategory
    : 'אחר';
  const recognized = parsed.recognized === true && name.length > 0;
  const rawConfidence = Number(parsed.confidence);

  return {
    recognized,
    name: recognized ? name : '',
    category: recognized ? category : 'אחר',
    categoryDetail: recognized && category === 'אחר' &&
            typeof parsed.categoryDetail === 'string'
        ? parsed.categoryDetail.trim()
        : '',
    notes: recognized && typeof parsed.notes === 'string'
        ? parsed.notes.trim()
        : '',
    confidence: Number.isFinite(rawConfidence)
        ? Math.max(0, Math.min(1, rawConfidence))
        : 0,
    reason: typeof parsed.reason === 'string' ? parsed.reason.trim() : '',
  };
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

  const categories = allowedCategories.map((value) => `- ${value}`).join('\n');
  const prompt = `
Identify the main fitness or exercise equipment visible in this image.
Small home-training accessories are valid equipment, including hand grippers, resistance bands, ab wheels, jump ropes, push-up handles and foam rollers.

Return ONLY one JSON object with this exact shape:
{
  "recognized": true,
  "name": "short Hebrew name",
  "category": "one exact category from the list",
  "categoryDetail": "only if category is אחר, otherwise empty",
  "notes": "only details clearly visible in the photo, otherwise empty",
  "confidence": 0.0,
  "reason": "short Hebrew explanation"
}

Allowed categories:
${categories}

Rules:
- Use Hebrew for name, categoryDetail, notes and reason.
- Do not invent brand, model, weight, resistance level or capabilities that are not clearly visible.
- If the image does not clearly show fitness/exercise equipment, return recognized=false, empty name, category אחר and low confidence.
`;

  try {
    const result = await ai.run(MODEL, {
      messages: [
        {
          role: 'system',
          content: 'You are a careful visual classifier for gym and home-fitness equipment.',
        },
        {
          role: 'user',
          content: [
            { type: 'text', text: prompt },
            { type: 'image_url', image_url: { url: dataUrl } },
          ],
        },
      ],
      max_completion_tokens: 700,
      reasoning_effort: 'low',
      temperature: 0.1,
    });

    const direct = directRecognitionObject(result);
    const raw = extractModelText(result);
    const parsed = direct ?? (raw ? extractJson(raw) : null);

    if (!raw && !direct) {
      const responseShape = Object.keys(result ?? {}).slice(0, 12).join(',');
      console.warn('equipment recognition returned no readable text', result);
      return jsonResponse({
        error: 'empty_model_response',
        responseShape: responseShape || 'unknown',
      }, 502);
    }

    if (!parsed) {
      console.warn('equipment recognition returned non-JSON text', raw.slice(0, 800));
      return jsonResponse({ error: 'invalid_model_response' }, 502);
    }

    const recognition = normalizeRecognition(parsed);
    return jsonResponse({
      ...recognition,
      model: MODEL,
      pipeline: 'multimodal-content-parts-v2',
    });
  } catch (error) {
    console.error('equipment multimodal recognition failed', error);
    return jsonResponse({ error: 'ai_request_failed' }, 502);
  }
}

export function onRequestGet(context: any) {
  return jsonResponse({
    status: 'ok',
    feature: 'equipment-recognition',
    aiBinding: Boolean(context.env?.AI),
    model: MODEL,
    pipeline: 'multimodal-content-parts-v2',
  });
}

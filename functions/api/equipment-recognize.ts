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
  const trimmed = text.trim();
  const withoutFence = trimmed
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/i, '')
    .trim();

  try {
    return JSON.parse(withoutFence) as Record<string, unknown>;
  } catch (_) {
    const start = withoutFence.indexOf('{');
    const end = withoutFence.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      return JSON.parse(withoutFence.slice(start, end + 1)) as Record<string, unknown>;
    } catch (_) {
      return null;
    }
  }
}

export async function onRequestPost(context: any) {
  const request = context.request as Request;
  const env = context.env as { AI?: { run: Function } };

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

  const imageBase64 = typeof body?.imageBase64 === 'string' ? body.imageBase64.trim() : '';
  const mimeType = typeof body?.mimeType === 'string' && body.mimeType.startsWith('image/')
    ? body.mimeType
    : 'image/jpeg';

  if (!imageBase64 || imageBase64.length > 5_500_000) {
    return jsonResponse({ error: 'invalid_image' }, 400);
  }

  if (!env.AI) {
    return jsonResponse({ error: 'ai_binding_missing' }, 503);
  }

  const dataUrl = imageBase64.startsWith('data:')
    ? imageBase64
    : `data:${mimeType};base64,${imageBase64}`;

  const categoryText = allowedCategories.map((e) => `- ${e}`).join('\n');
  const prompt = `
Analyze the attached photo and determine whether it shows fitness or exercise equipment.
Return ONLY one JSON object, with no markdown and no extra commentary.

Use Hebrew for name, categoryDetail, notes and reason.
The category MUST be exactly one of these values:
${categoryText}

JSON shape:
{
  "recognized": true,
  "name": "short Hebrew equipment name",
  "category": "one exact category from the list",
  "categoryDetail": "only when category is אחר, otherwise empty string",
  "notes": "short useful visible details such as weight, resistance, brand/model if clearly visible; otherwise empty string",
  "confidence": 0.0,
  "reason": "short Hebrew explanation of what visual clues led to the suggestion"
}

If the photo does not clearly contain fitness equipment, return recognized=false, leave name/categoryDetail/notes empty, set category to "אחר", use a low confidence value, and explain briefly in Hebrew.
Do not invent weight, model, brand, resistance level, or capabilities that are not visibly supported by the image.
`;

  try {
    const aiResult = await env.AI.run('@cf/google/gemma-4-26b-a4b-it', {
      messages: [
        {
          role: 'system',
          content: 'You identify fitness equipment conservatively. Never fabricate details that are not visible.',
        },
        { role: 'user', content: prompt },
      ],
      image: dataUrl,
      max_tokens: 320,
      temperature: 0.1,
    });

    const raw = typeof aiResult?.response === 'string'
      ? aiResult.response
      : typeof aiResult === 'string'
        ? aiResult
        : JSON.stringify(aiResult ?? {});

    const parsed = extractJson(raw);
    if (!parsed) {
      return jsonResponse({ error: 'unparseable_ai_response' }, 502);
    }

    const recognized = parsed.recognized === true;
    const name = typeof parsed.name === 'string' ? parsed.name.trim() : '';
    const rawCategory = typeof parsed.category === 'string' ? parsed.category.trim() : 'אחר';
    const category = allowedCategories.includes(rawCategory as any) ? rawCategory : 'אחר';
    const categoryDetail = typeof parsed.categoryDetail === 'string' ? parsed.categoryDetail.trim() : '';
    const notes = typeof parsed.notes === 'string' ? parsed.notes.trim() : '';
    const reason = typeof parsed.reason === 'string' ? parsed.reason.trim() : '';
    const numericConfidence = Number(parsed.confidence);
    const confidence = Number.isFinite(numericConfidence)
      ? Math.max(0, Math.min(1, numericConfidence))
      : 0;

    return jsonResponse({
      recognized: recognized && name.length > 0,
      name: recognized ? name : '',
      category: recognized ? category : 'אחר',
      categoryDetail: recognized && category === 'אחר' ? categoryDetail : '',
      notes: recognized ? notes : '',
      confidence,
      reason,
      model: '@cf/google/gemma-4-26b-a4b-it',
    });
  } catch (error) {
    console.error('equipment recognition failed', error);
    return jsonResponse({ error: 'ai_request_failed' }, 502);
  }
}

export function onRequestGet() {
  return jsonResponse({
    status: 'ok',
    feature: 'equipment-recognition',
  });
}

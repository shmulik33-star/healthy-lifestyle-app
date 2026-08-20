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
  model?: string;
  pipeline?: string;
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

function decodeBase64(value: string): Uint8Array {
  const payload = value.startsWith('data:')
    ? value.slice(value.indexOf(',') + 1)
    : value;
  const binary = atob(payload);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function normalizedRecognition(parsed: Record<string, unknown>): Recognition {
  const recognized = parsed.recognized === true;
  const name = typeof parsed.name === 'string' ? parsed.name.trim() : '';
  const rawCategory = typeof parsed.category === 'string'
    ? parsed.category.trim()
    : 'אחר';
  const category = allowedCategories.includes(rawCategory as any)
    ? rawCategory
    : 'אחר';
  const categoryDetail = typeof parsed.categoryDetail === 'string'
    ? parsed.categoryDetail.trim()
    : '';
  const notes = typeof parsed.notes === 'string' ? parsed.notes.trim() : '';
  const reason = typeof parsed.reason === 'string' ? parsed.reason.trim() : '';
  const numericConfidence = Number(parsed.confidence);
  const confidence = Number.isFinite(numericConfidence)
    ? Math.max(0, Math.min(1, numericConfidence))
    : 0;

  return {
    recognized: recognized && name.length > 0,
    name: recognized ? name : '',
    category: recognized ? category : 'אחר',
    categoryDetail: recognized && category === 'אחר' ? categoryDetail : '',
    notes: recognized ? notes : '',
    confidence,
    reason,
  };
}

function heuristicFromDescription(description: string): Recognition | null {
  const text = description.toLowerCase();

  const hit = (
    terms: string[],
    name: string,
    category: string,
    confidence = 0.86,
  ): Recognition | null => {
    if (!terms.some((term) => text.includes(term))) return null;
    return {
      recognized: true,
      name,
      category,
      categoryDetail: '',
      notes: '',
      confidence,
      reason: 'הזיהוי מבוסס על מאפיינים חזותיים ותיאור התמונה.',
      pipeline: 'description+heuristic',
    };
  };

  return (
    hit(
      [
        'hand gripper',
        'hand grip',
        'grip strengthener',
        'grip trainer',
        'forearm strengthener',
        'finger strengthener',
      ],
      'מחזק אחיזה ליד',
      'מזרן / אביזרים',
      0.9,
    ) ??
    hit(['dumbbell', 'dumbbells', 'adjustable dumbbell'], 'משקולות יד', 'משקולות') ??
    hit(['kettlebell'], 'קטלבל', 'קטלבל') ??
    hit(['resistance band', 'exercise band', 'fitness band'], 'גומיית התנגדות', 'גומיות התנגדות') ??
    hit(['barbell', 'curl bar', 'ez bar'], 'מוט משקולות', 'מוטות') ??
    hit(['pull-up bar', 'pull up bar', 'chin-up bar'], 'מתח', 'מוטות') ??
    hit(['weight bench', 'workout bench', 'exercise bench'], 'ספסל אימון', 'ספסלים') ??
    hit(['treadmill'], 'הליכון', 'מכשירי אירובי') ??
    hit(['stationary bike', 'exercise bike', 'spin bike'], 'אופני כושר', 'מכשירי אירובי') ??
    hit(['elliptical'], 'מכשיר אליפטי', 'מכשירי אירובי') ??
    hit(['rowing machine', 'rower'], 'מכשיר חתירה', 'מכשירי אירובי') ??
    hit(['cable machine', 'lat pulldown', 'leg press', 'multi gym', 'multigym'], 'מכשיר כוח', 'מכשירי כוח') ??
    hit(['yoga mat', 'exercise mat', 'fitness mat'], 'מזרן אימון', 'מזרן / אביזרים') ??
    hit(['ab wheel', 'ab roller'], 'גלגל בטן', 'מזרן / אביזרים') ??
    hit(['jump rope', 'skipping rope'], 'חבל קפיצה', 'מזרן / אביזרים') ??
    hit(['push-up bar', 'push up bar', 'pushup handle'], 'ידיות שכיבות סמיכה', 'מזרן / אביזרים') ??
    hit(['foam roller'], 'גליל עיסוי', 'מזרן / אביזרים')
  );
}

async function describeImage(
  ai: any,
  imageBytes: Uint8Array,
  mimeType: string,
): Promise<string> {
  if (typeof ai?.toMarkdown !== 'function') return '';

  const extension = mimeType.includes('png')
    ? 'png'
    : mimeType.includes('webp')
      ? 'webp'
      : 'jpg';

  const result = await ai.toMarkdown(
    {
      name: `equipment.${extension}`,
      blob: new Blob([imageBytes], { type: mimeType }),
    },
    {
      conversionOptions: {
        output: { format: 'text' },
      },
    },
  );

  const first = Array.isArray(result) ? result[0] : result;
  return typeof first?.data === 'string' ? first.data.trim() : '';
}

async function classifyDescription(ai: any, description: string): Promise<Recognition | null> {
  const categoryText = allowedCategories.map((e) => `- ${e}`).join('\n');
  const prompt = `
You are classifying a visual description of fitness equipment.
The description was produced by a vision system from the user's photo.
Small/home fitness accessories ARE valid fitness equipment. Examples include hand grippers / grip strengtheners, ab wheels, jump ropes, push-up handles, foam rollers and resistance bands.

Image description:
"""
${description.slice(0, 6000)}
"""

Return ONLY one JSON object, no markdown.
Use Hebrew for name, categoryDetail, notes and reason.
The category MUST be exactly one of:
${categoryText}

Category guidance:
- dumbbells -> משקולות
- barbells / pull-up bars -> מוטות
- workout benches -> ספסלים
- resistance bands -> גומיות התנגדות
- kettlebells -> קטלבל
- treadmill / exercise bike / elliptical / rower -> מכשירי אירובי
- cable machine / lat pulldown / leg press / multi-gym -> מכשירי כוח
- hand gripper / grip strengthener / ab wheel / jump rope / push-up handles / foam roller / exercise mat -> מזרן / אביזרים

JSON shape:
{
  "recognized": true,
  "name": "short Hebrew equipment name",
  "category": "one exact category",
  "categoryDetail": "only when category is אחר, otherwise empty string",
  "notes": "only clearly supported visible details, otherwise empty string",
  "confidence": 0.0,
  "reason": "short Hebrew explanation"
}

If the description does not clearly indicate fitness/exercise equipment, set recognized=false and use low confidence.
Do not invent weight, model, brand or capabilities.
`;

  const result = await ai.run('@cf/google/gemma-4-26b-a4b-it', {
    messages: [
      {
        role: 'system',
        content: 'Classify fitness equipment conservatively, but treat small home training accessories as valid equipment.',
      },
      { role: 'user', content: prompt },
    ],
    max_tokens: 320,
    temperature: 0.1,
  });

  const raw = typeof result?.response === 'string'
    ? result.response
    : typeof result === 'string'
      ? result
      : '';
  if (!raw) return null;
  const parsed = extractJson(raw);
  return parsed ? normalizedRecognition(parsed) : null;
}

async function directVisionFallback(
  ai: any,
  imageBase64: string,
  mimeType: string,
): Promise<Recognition | null> {
  const dataUrl = imageBase64.startsWith('data:')
    ? imageBase64
    : `data:${mimeType};base64,${imageBase64}`;
  const categoryText = allowedCategories.map((e) => `- ${e}`).join('\n');

  const prompt = `
Identify the fitness equipment in this image. Small accessories such as a hand gripper / grip strengthener are valid equipment.
Return ONLY JSON.
Use Hebrew for text fields. Category must be exactly one of:
${categoryText}

{"recognized":true,"name":"","category":"","categoryDetail":"","notes":"","confidence":0.0,"reason":""}
If this is not fitness equipment, set recognized=false. Do not invent details.
`;

  const result = await ai.run('@cf/google/gemma-4-26b-a4b-it', {
    messages: [
      { role: 'system', content: 'You identify gym and home-fitness equipment, including small training accessories.' },
      { role: 'user', content: prompt },
    ],
    image: dataUrl,
    max_tokens: 260,
    temperature: 0.1,
  });

  const raw = typeof result?.response === 'string'
    ? result.response
    : typeof result === 'string'
      ? result
      : '';
  if (!raw) return null;
  const parsed = extractJson(raw);
  return parsed ? normalizedRecognition(parsed) : null;
}

export async function onRequestPost(context: any) {
  const request = context.request as Request;
  const env = context.env as { AI?: any };

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
  const mimeType = typeof body?.mimeType === 'string' && body.mimeType.startsWith('image/')
    ? body.mimeType
    : 'image/jpeg';

  if (!imageBase64 || imageBase64.length > 5_500_000) {
    return jsonResponse({ error: 'invalid_image' }, 400);
  }

  if (!env.AI) {
    return jsonResponse({ error: 'ai_binding_missing' }, 503);
  }

  let imageBytes: Uint8Array;
  try {
    imageBytes = decodeBase64(imageBase64);
  } catch (_) {
    return jsonResponse({ error: 'invalid_base64' }, 400);
  }

  try {
    let description = '';
    try {
      description = await describeImage(env.AI, imageBytes, mimeType);
    } catch (error) {
      console.warn('equipment image description failed', error);
    }

    if (description) {
      const heuristic = heuristicFromDescription(description);
      if (heuristic) {
        return jsonResponse({
          ...heuristic,
          visualDescription: description.slice(0, 500),
        });
      }

      try {
        const classified = await classifyDescription(env.AI, description);
        if (classified?.recognized) {
          return jsonResponse({
            ...classified,
            model: '@cf/google/gemma-4-26b-a4b-it',
            pipeline: 'description+classification',
          });
        }
      } catch (error) {
        console.warn('equipment description classification failed', error);
      }
    }

    try {
      const direct = await directVisionFallback(env.AI, imageBase64, mimeType);
      if (direct) {
        return jsonResponse({
          ...direct,
          model: '@cf/google/gemma-4-26b-a4b-it',
          pipeline: 'direct-vision-fallback',
        });
      }
    } catch (error) {
      console.warn('equipment direct vision fallback failed', error);
    }

    return jsonResponse({
      recognized: false,
      name: '',
      category: 'אחר',
      categoryDetail: '',
      notes: '',
      confidence: 0,
      reason: description
        ? 'התמונה נותחה, אך לא התקבל זיהוי מספיק בטוח.'
        : 'לא התקבל תיאור חזותי מספיק ברור מהתמונה.',
      pipeline: description ? 'description-no-match' : 'vision-no-description',
    });
  } catch (error) {
    console.error('equipment recognition failed', error);
    return jsonResponse({ error: 'ai_request_failed' }, 502);
  }
}

export function onRequestGet(context: any) {
  const ai = context?.env?.AI;
  return jsonResponse({
    status: 'ok',
    feature: 'equipment-recognition',
    aiBinding: Boolean(ai),
    imageDescriptionPipeline: typeof ai?.toMarkdown === 'function',
    pipelineVersion: 2,
  });
}

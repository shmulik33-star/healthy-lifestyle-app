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
    caloriesLabel: { type: 'string' },
    caloriesUnit: { type: 'string' },
    protein: { type: 'number', minimum: 0, maximum: 5000 },
    proteinLabel: { type: 'string' },
    carbs: { type: 'number', minimum: 0, maximum: 5000 },
    carbsLabel: { type: 'string' },
    fat: { type: 'number', minimum: 0, maximum: 5000 },
    fatLabel: { type: 'string' },
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
    'caloriesLabel',
    'caloriesUnit',
    'protein',
    'proteinLabel',
    'carbs',
    'carbsLabel',
    'fat',
    'fatLabel',
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

function semanticText(value: unknown): string {
  if (typeof value !== 'string') return '';
  return value
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[\u0591-\u05c7\u064b-\u065f\u0670]/g, '')
    .replace(/["'׳״`~!@#$%^&*()_+=\[\]{}|\\/:;,.<>?\-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function containsAny(text: string, terms: string[]) {
  return terms.some((term) => text.includes(term));
}

type NutrientKind = 'calories' | 'protein' | 'carbs' | 'fat';

function nutrientLabelMatches(kind: NutrientKind, labelValue: unknown): boolean {
  const label = semanticText(labelValue);
  if (!label) return false;

  if (kind === 'protein') {
    return containsAny(label, [
      'protein',
      'proteins',
      'חלבון',
      'חלבונים',
      'بروتين',
      'البروتين',
      'proteine',
      'proteina',
    ]);
  }

  if (kind === 'fat') {
    if (
      containsAny(label, [
        'saturated',
        'trans',
        'mono unsaturated',
        'monounsaturated',
        'poly unsaturated',
        'polyunsaturated',
        'רווי',
        'טרנס',
        'مشبعة',
        'متحولة',
      ])
    ) {
      return false;
    }
    return containsAny(label, [
      'total fat',
      'fat',
      'שומן',
      'שומנים',
      'סך השומנים',
      'دهون',
      'الدهون',
      'اجمالي الدهون',
      'مجموع الدهون',
      'lipides',
      'grasas',
    ]);
  }

  if (kind === 'carbs') {
    if (
      containsAny(label, [
        'sugar',
        'sugars',
        'fiber',
        'fibre',
        'starch',
        'סוכר',
        'סוכרים',
        'סיבים',
        'עמילן',
        'سكريات',
        'الياف',
        'نشا',
      ])
    ) {
      return false;
    }
    return containsAny(label, [
      'carbohydrate',
      'carbohydrates',
      'total carbohydrate',
      'carbs',
      'פחמימות',
      'סך הפחמימות',
      'كربوهيدرات',
      'الكربوهيدرات',
      'glucides',
      'carbohidratos',
    ]);
  }

  return containsAny(label, [
    'calorie',
    'calories',
    'kcal',
    'energy',
    'קלוריות',
    'אנרגיה',
    'سعرات',
    'طاقة',
    'calorias',
    'energie',
  ]);
}

function isKcalValue(labelValue: unknown, unitValue: unknown): boolean {
  const combined = `${semanticText(labelValue)} ${semanticText(unitValue)}`.trim();
  if (!combined) return false;
  const hasKcal = containsAny(combined, [
    'kcal',
    'calorie',
    'calories',
    'קלוריות',
    'קקל',
    'سعر حراري',
    'سعرات حرارية',
    'calorias',
  ]);
  const onlyKilojoule = containsAny(combined, ['kj', 'kilojoule', 'קילו ג אול', 'كيلوجول']);
  return hasKcal || !onlyKilojoule;
}

function normalizeLabel(parsed: Record<string, unknown>) {
  const basisGrams = numberValue(parsed.basisGrams, 5000);

  const labelChecks = {
    calories:
      nutrientLabelMatches('calories', parsed.caloriesLabel) &&
      isKcalValue(parsed.caloriesLabel, parsed.caloriesUnit),
    protein: nutrientLabelMatches('protein', parsed.proteinLabel),
    carbs: nutrientLabelMatches('carbs', parsed.carbsLabel),
    fat: nutrientLabelMatches('fat', parsed.fatLabel),
  };

  const rawCalories = labelChecks.calories ? numberValue(parsed.calories, 10000) : 0;
  const rawProtein = labelChecks.protein ? numberValue(parsed.protein, 5000) : 0;
  const rawCarbs = labelChecks.carbs ? numberValue(parsed.carbs, 5000) : 0;
  const rawFat = labelChecks.fat ? numberValue(parsed.fat, 5000) : 0;

  const rejectedFields = Object.entries(labelChecks)
    .filter(([, valid]) => !valid)
    .map(([field]) => field);

  const hasValues = rawCalories > 0 || rawProtein > 0 || rawCarbs > 0 || rawFat > 0;
  const recognized = parsed.recognized === true && basisGrams > 0 && hasValues;
  const factor = recognized ? 100 / basisGrams : 0;
  const per100 = (value: number, max: number) =>
    Math.max(0, Math.min(max, value * factor));

  const baseConfidence = numberValue(parsed.confidence, 1);
  const confidence = rejectedFields.length > 0
    ? Math.min(baseConfidence, 0.6)
    : baseConfidence;
  const reason = typeof parsed.reason === 'string' ? parsed.reason.trim() : '';
  const validationNote = rejectedFields.length > 0
    ? `לא השתמשתי בערכים שלא התאימו בבירור לשם השורה: ${rejectedFields.join(', ')}.`
    : '';

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
    confidence,
    reason: [reason, validationNote].filter(Boolean).join(' '),
    validation: 'semantic-nutrient-labels-v1',
    rejectedFields,
    sourceLabels: {
      calories: typeof parsed.caloriesLabel === 'string' ? parsed.caloriesLabel : '',
      protein: typeof parsed.proteinLabel === 'string' ? parsed.proteinLabel : '',
      carbs: typeof parsed.carbsLabel === 'string' ? parsed.carbsLabel : '',
      fat: typeof parsed.fatLabel === 'string' ? parsed.fatLabel : '',
    },
  };
}

async function structureDescription(ai: any, description: string) {
  const result = await ai.run(STRUCTURE_MODEL, {
    messages: [
      {
        role: 'system',
        content:
          'Convert OCR or a visual description of a nutrition label into a structured object. The order of rows is irrelevant. Identify each nutrient by the text label next to it. Never infer a nutrient from row position. Never invent values.',
      },
      {
        role: 'user',
        content:
          `Nutrition-label OCR/description:\n${description.slice(0, 9000)}\n\n` +
          'For calories, protein, carbs and fat, also copy the exact visible row label into caloriesLabel, proteinLabel, carbsLabel and fatLabel. ' +
          'Copy the calories unit into caloriesUnit. Protein must only come from a protein row; fat only from a TOTAL fat row, never saturated/trans/unsaturated fat; carbs only from a carbohydrate row, never sugars/fibre/starch. ' +
          'Prefer an explicitly visible per-100g column. If values are for a different gram basis, put that basis in basisGrams. Calories must be kcal, not kJ. ' +
          'If a target row is absent or ambiguous, use 0 for its number and an empty string for its label instead of guessing. Use Hebrew for text fields such as name, servingName and reason.',
      },
    ],
    response_format: { type: 'json_schema', json_schema: labelSchema },
    max_completion_tokens: 900,
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
          'Read nutrition labels semantically. Row order is irrelevant: match every number to the nutrient name printed on the same row. Never fabricate or infer a macro from its position.',
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
    max_completion_tokens: 1600,
    temperature: 0,
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
    pipeline: 'nutrition-label-vision-v4-semantic-labels',
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

Critical semantic-mapping rule:
- Nutrition labels can list rows in ANY order. Never use row order or position to decide what a number means.
- First read the nutrient NAME printed on a row, then take the value from that same row and the chosen basis column.
- Copy the exact visible row name used for each target into its corresponding *Label field so the server can verify the mapping.

Target mapping:
- protein: only a row whose label means Protein / חלבון / بروتين.
- fat: only a row whose label means TOTAL fat / שומן כולל or סך השומנים / إجمالي الدهون. Never use saturated fat, trans fat, mono/poly-unsaturated fat or cholesterol.
- carbs: only a row whose label means Carbohydrates / פחמימות / كربوهيدرات. Never use sugars, fibre or starch as the carbs value.
- calories: only kcal / Calories / קלוריות / سعرات حرارية. Never use kJ as calories.

Column rules:
- Prefer the column explicitly stated per 100 grams.
- If there is no per-100g column, use a different gram-based column only when its gram basis is clearly visible and put that basis in basisGrams.
- If both per-100g and per-serving columns are visible, use the per-100g values for calories/protein/carbs/fat.
- All four macro values must come from the SAME basis column.

Output evidence fields:
- caloriesLabel: exact visible row label used for calories.
- caloriesUnit: exact visible unit for the calories number, such as kcal.
- proteinLabel: exact visible row label used for protein.
- carbsLabel: exact visible row label used for carbohydrates.
- fatLabel: exact visible row label used for total fat.
- If a target row is missing or ambiguous, return 0 for the value and an empty string for its label. Do not guess.

Other rules:
- Use the product/food name only if clearly visible; otherwise return an empty name.
- servingName and servingGrams are optional convenience fields and must be visible on the label.
- Do not infer kosher status, meat/dairy/pareve classification, ingredients, allergens, brand or category.
- Never invent a missing number.
- If a readable gram-based nutrition table is not visible, return recognized=false and low confidence.
- Use Hebrew for name, servingName and reason.

Return exactly one JSON object and no surrounding prose. It must contain all of these keys:
recognized, name, basisGrams, calories, caloriesLabel, caloriesUnit, protein, proteinLabel, carbs, carbsLabel, fat, fatLabel, servingName, servingGrams, confidence, reason.
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
            : `${prompt}\nRetry: ignore row position completely. Re-read the printed nutrient names and pair each target value only with its matching row label.`,
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

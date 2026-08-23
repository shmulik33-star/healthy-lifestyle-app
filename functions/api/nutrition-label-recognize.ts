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
    if (
      'rows' in candidate ||
      'basisGrams' in candidate ||
      'caloriesKcal' in candidate ||
      'recognized' in candidate
    ) {
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

type NutrientKind = 'protein' | 'carbs' | 'fat';

type NutritionRow = {
  label: string;
  value: number;
  unit: string;
};

function nutritionRows(value: unknown): NutritionRow[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (!item || typeof item !== 'object') return null;
      const row = item as Record<string, unknown>;
      const label = typeof row.label === 'string' ? row.label.trim() : '';
      const unit = typeof row.unit === 'string' ? row.unit.trim() : '';
      const number = numberValue(row.value, 10000);
      if (!label) return null;
      return { label, value: number, unit };
    })
    .filter((row): row is NutritionRow => row !== null);
}

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
        'cholesterol',
        'רווי',
        'טרנס',
        'חד בלתי רווי',
        'רב בלתי רווי',
        'כולסטרול',
        'مشبعة',
        'متحولة',
        'كوليسترول',
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
      'שומן כולל',
      'دهون',
      'الدهون',
      'اجمالي الدهون',
      'إجمالي الدهون',
      'مجموع الدهون',
      'lipides',
      'grasas',
    ]);
  }

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
      'ألياف',
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

function rowScore(kind: NutrientKind, row: NutritionRow): number {
  const label = semanticText(row.label);
  let score = 1;
  if (
    kind === 'fat' &&
    containsAny(label, [
      'total fat',
      'סך השומנים',
      'שומן כולל',
      'اجمالي الدهون',
      'إجمالي الدهون',
    ])
  ) {
    score += 3;
  }
  if (kind === 'carbs' && containsAny(label, ['total carbohydrate', 'סך הפחמימות'])) {
    score += 2;
  }
  if (kind === 'protein' && containsAny(label, ['protein', 'חלבון', 'بروتين'])) {
    score += 2;
  }
  const unit = semanticText(row.unit);
  if (containsAny(unit, ['g', 'gram', 'גרם', 'غ'])) score += 1;
  return score;
}

function selectRow(kind: NutrientKind, rows: NutritionRow[]): NutritionRow | null {
  const candidates = rows.filter((row) => nutrientLabelMatches(kind, row.label));
  if (candidates.length === 0) return null;
  return candidates.sort((a, b) => rowScore(kind, b) - rowScore(kind, a))[0];
}

function isKcalUnit(value: unknown): boolean {
  const unit = semanticText(value);
  if (!unit) return false;
  if (containsAny(unit, ['kj', 'kilojoule', 'kilojoules', 'كيلوجول'])) return false;
  return containsAny(unit, [
    'kcal',
    'k cal',
    'kilocalorie',
    'kilocalories',
    'calorie',
    'calories',
    'קקל',
    'קק ל',
    'קלוריות',
    'קלוריה',
    'سعر حراري',
    'سعرات حرارية',
    'كالوري',
    'كيلوكالوري',
  ]);
}

function normalizeLabel(parsed: Record<string, unknown>) {
  const basisGrams = numberValue(parsed.basisGrams, 5000);
  const rows = nutritionRows(parsed.rows);
  const proteinRow = selectRow('protein', rows);
  const carbsRow = selectRow('carbs', rows);
  const fatRow = selectRow('fat', rows);

  const caloriesUnit =
    typeof parsed.caloriesUnit === 'string' ? parsed.caloriesUnit.trim() : '';
  const directCalories = isKcalUnit(caloriesUnit)
    ? numberValue(parsed.caloriesKcal, 10000)
    : 0;

  const rawProtein = proteinRow?.value ?? 0;
  const rawCarbs = carbsRow?.value ?? 0;
  const rawFat = fatRow?.value ?? 0;
  const hasValues = directCalories > 0 || rawProtein > 0 || rawCarbs > 0 || rawFat > 0;
  const recognized = parsed.recognized === true && basisGrams > 0 && hasValues;
  const factor = recognized ? 100 / basisGrams : 0;
  const per100 = (value: number, max: number) =>
    Math.max(0, Math.min(max, value * factor));

  const caloriesPer100g = per100(directCalories, 2000);
  const proteinPer100g = per100(rawProtein, 100);
  const carbsPer100g = per100(rawCarbs, 100);
  const fatPer100g = per100(rawFat, 100);

  const missingFields = [
    caloriesPer100g <= 0 ? 'calories' : '',
    !proteinRow ? 'protein' : '',
    !carbsRow ? 'carbs' : '',
    !fatRow ? 'fat' : '',
  ].filter(Boolean);

  let energyMismatch = false;
  let energyDifferenceRatio = 0;
  if (
    caloriesPer100g > 0 &&
    proteinPer100g > 0 &&
    carbsPer100g > 0 &&
    fatPer100g > 0
  ) {
    const macroCalories =
      proteinPer100g * 4 + carbsPer100g * 4 + fatPer100g * 9;
    energyDifferenceRatio = Math.abs(macroCalories - caloriesPer100g) / caloriesPer100g;
    energyMismatch = energyDifferenceRatio > 0.35;
  }

  const baseConfidence = numberValue(parsed.confidence, 1);
  const confidence = missingFields.length > 0 || energyMismatch
    ? Math.min(baseConfidence, 0.65)
    : baseConfidence;
  const reason = typeof parsed.reason === 'string' ? parsed.reason.trim() : '';
  const validationNotes = [
    missingFields.length > 0
      ? `לא נמצאה קריאה ברורה עבור: ${missingFields.join(', ')}.`
      : '',
    energyMismatch
      ? 'יש אי־התאמה גדולה בין הקלוריות לבין החלבון/פחמימות/שומן; מומלץ לבדוק את התווית.'
      : '',
  ].filter(Boolean);

  return {
    recognized,
    name: typeof parsed.name === 'string' ? parsed.name.trim() : '',
    caloriesPer100g,
    proteinPer100g,
    carbsPer100g,
    fatPer100g,
    servingName: typeof parsed.servingName === 'string'
      ? parsed.servingName.trim()
      : '',
    servingGrams: numberValue(parsed.servingGrams, 5000),
    confidence,
    reason: [reason, ...validationNotes].filter(Boolean).join(' '),
    validation: 'semantic-row-macros-direct-kcal-v8',
    missingFields,
    energyMismatch,
    energyDifferenceRatio,
    basisLabel: typeof parsed.basisLabel === 'string' ? parsed.basisLabel.trim() : '',
    sourceLabels: {
      calories:
        typeof parsed.caloriesLabel === 'string' ? parsed.caloriesLabel.trim() : '',
      protein: proteinRow?.label ?? '',
      carbs: carbsRow?.label ?? '',
      fat: fatRow?.label ?? '',
    },
    sourceUnits: {
      calories: caloriesUnit,
      protein: proteinRow?.unit ?? '',
      carbs: carbsRow?.unit ?? '',
      fat: fatRow?.unit ?? '',
    },
    extractedRowCount: rows.length,
  };
}

async function runVision(ai: any, dataUrl: string) {
  const prompt = `
Read the nutrition table visible in this food-label image.

IMPORTANT: rows can appear in ANY order. Never infer a nutrient from row position.

Use ONE nutrition-value column only. Prefer a column explicitly labeled per 100 g / 100 grams. If there is no 100 g column, use another clearly labeled gram basis and put that gram amount in basisGrams.

For protein, fat and carbohydrates, do transcription first:
- rows must contain the printed nutrient label, the number from that SAME row in the chosen column, and its printed unit.
- Keep labels as literally as possible.
- Do not map a neighboring number to a row.
- Include all visible nutrition rows so the server can map labels deterministically.

Calories/energy are handled separately in the SAME model call:
- caloriesKcal: copy ONLY the kcal / Calories / kilocalorie number from the Energy/Calories row in the SAME chosen column.
- caloriesUnit: copy the unit that proves this is kcal/Calories, for example kcal, Calories, קק״ל, קלוריות, سعرات حرارية.
- caloriesLabel: copy the printed Energy/Calories row label.
- If both kJ and kcal appear, caloriesKcal MUST be the kcal value, never the kJ value.
- If kcal is not clearly visible, set caloriesKcal=0 and caloriesUnit="". Do not convert kJ and do not calculate calories from macros.

Other rules:
- Use product/food name only if clearly visible; otherwise name="".
- servingName and servingGrams are optional and must be visible.
- Do not infer kosher status, meat/dairy/pareve, ingredients, allergens, brand or category.
- If a readable gram-based nutrition table is not visible, recognized=false and confidence low.
- Use Hebrew for name, servingName and reason, but preserve nutrition row labels in their original language.

Return exactly one JSON object with these keys:
recognized, name, basisGrams, basisLabel, caloriesKcal, caloriesUnit, caloriesLabel, rows, servingName, servingGrams, confidence, reason.
`;

  return ai.run(MODEL, {
    messages: [
      {
        role: 'system',
        content:
          'Read nutrition labels faithfully. Preserve each nutrient label with the number printed on the same row. Row order is irrelevant. Read kcal separately from kJ. Do not calculate or invent values.',
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
    pipeline: 'nutrition-label-direct-vision-v8',
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

  let result: any = null;
  try {
    result = await runVision(ai, dataUrl);
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

    return jsonResponse({
      ...normalizeLabel(parsed),
      model: MODEL,
      pipeline: 'direct-vision-semantic-rows-plus-kcal',
    });
  } catch (error) {
    console.error('nutrition label recognition failed', error);
    return jsonResponse(
      {
        error: 'ai_request_failed',
        ...diagnosticShape(result),
      },
      502,
    );
  }
}

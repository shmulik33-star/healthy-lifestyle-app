const STRUCTURE_MODEL = '@cf/meta/llama-3.1-8b-instruct-fast';

const nutritionRowSchema = {
  type: 'object',
  additionalProperties: false,
  properties: {
    label: { type: 'string' },
    value: { type: 'number', minimum: 0, maximum: 10000 },
    unit: { type: 'string' },
  },
  required: ['label', 'value', 'unit'],
};

const labelSchema = {
  type: 'object',
  additionalProperties: false,
  properties: {
    recognized: { type: 'boolean' },
    name: { type: 'string' },
    basisGrams: { type: 'number', minimum: 0, maximum: 5000 },
    basisLabel: { type: 'string' },
    calories: { type: 'number', minimum: 0, maximum: 10000 },
    caloriesLabel: { type: 'string' },
    caloriesUnit: { type: 'string' },
    rows: {
      type: 'array',
      items: nutritionRowSchema,
      maxItems: 80,
    },
    servingName: { type: 'string' },
    servingGrams: { type: 'number', minimum: 0, maximum: 5000 },
    confidence: { type: 'number', minimum: 0, maximum: 1 },
    reason: { type: 'string' },
  },
  required: [
    'recognized',
    'name',
    'basisGrams',
    'basisLabel',
    'calories',
    'caloriesLabel',
    'caloriesUnit',
    'rows',
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
  if (typeof result.response === 'string') return result.response.trim();
  if (typeof result.text === 'string') return result.text.trim();
  if (typeof result.output_text === 'string') return result.output_text.trim();

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
    if ('rows' in candidate || 'basisGrams' in candidate || 'recognized' in candidate) {
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

  return containsAny(label, [
    'calorie',
    'calories',
    'kcal',
    'kilocalorie',
    'kilocalories',
    'energy',
    'קלוריות',
    'קלוריה',
    'אנרגיה',
    'קקל',
    'קק ל',
    'سعرات',
    'طاقة',
    'كالوري',
    'كيلوكالوري',
    'calorias',
    'energie',
  ]);
}

function kcalRow(row: NutritionRow): boolean {
  if (!nutrientLabelMatches('calories', row.label)) return false;
  const label = semanticText(row.label);
  const unit = semanticText(row.unit);
  if (containsAny(unit, ['kj', 'kilojoule', 'kilojoules', 'كيلوجول'])) return false;
  return (
    containsAny(unit, [
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
    ]) ||
    containsAny(label, [
      'kcal',
      'k cal',
      'kilocalorie',
      'kilocalories',
      'calorie',
      'calories',
      'קלוריות',
      'קלוריה',
      'קקל',
      'קק ל',
      'سعرات',
      'كالوري',
      'كيلوكالوري',
    ])
  );
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
  if (kind === 'calories' && kcalRow(row)) score += 4;
  const unit = semanticText(row.unit);
  if (kind !== 'calories' && containsAny(unit, ['g', 'gram', 'גרם', 'غ'])) {
    score += 1;
  }
  return score;
}

function selectRow(kind: NutrientKind, rows: NutritionRow[]): NutritionRow | null {
  const candidates = rows.filter((row) => {
    if (kind === 'calories') return kcalRow(row);
    return nutrientLabelMatches(kind, row.label);
  });
  if (candidates.length === 0) return null;
  return candidates.sort((a, b) => rowScore(kind, b) - rowScore(kind, a))[0];
}

function normalizeLabel(parsed: Record<string, unknown>) {
  const basisGrams = numberValue(parsed.basisGrams, 5000);
  const rows = nutritionRows(parsed.rows);
  const caloriesRow = selectRow('calories', rows);
  const proteinRow = selectRow('protein', rows);
  const carbsRow = selectRow('carbs', rows);
  const fatRow = selectRow('fat', rows);

  const directCaloriesRow: NutritionRow = {
    label: typeof parsed.caloriesLabel === 'string' ? parsed.caloriesLabel.trim() : '',
    value: numberValue(parsed.calories, 10000),
    unit: typeof parsed.caloriesUnit === 'string' ? parsed.caloriesUnit.trim() : '',
  };
  const directCaloriesValid =
    directCaloriesRow.value > 0 && kcalRow(directCaloriesRow);

  const rawCalories = directCaloriesValid
    ? directCaloriesRow.value
    : caloriesRow?.value ?? 0;
  const rawProtein = proteinRow?.value ?? 0;
  const rawCarbs = carbsRow?.value ?? 0;
  const rawFat = fatRow?.value ?? 0;
  const hasValues = rawCalories > 0 || rawProtein > 0 || rawCarbs > 0 || rawFat > 0;
  const recognized = parsed.recognized === true && basisGrams > 0 && hasValues;
  const factor = recognized ? 100 / basisGrams : 0;
  const per100 = (value: number, max: number) =>
    Math.max(0, Math.min(max, value * factor));

  const caloriesPer100g = per100(rawCalories, 2000);
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
    energyMismatch = energyDifferenceRatio > 0.4;
  }

  const baseConfidence = numberValue(parsed.confidence, 1);
  const confidence = missingFields.length > 0 || energyMismatch
    ? Math.min(baseConfidence, 0.6)
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
    validation: 'semantic-nutrition-rows-v5-direct-calories',
    missingFields,
    energyMismatch,
    energyDifferenceRatio,
    basisLabel: typeof parsed.basisLabel === 'string' ? parsed.basisLabel.trim() : '',
    sourceLabels: {
      calories: directCaloriesValid
        ? directCaloriesRow.label
        : caloriesRow?.label ?? '',
      protein: proteinRow?.label ?? '',
      carbs: carbsRow?.label ?? '',
      fat: fatRow?.label ?? '',
    },
    sourceUnits: {
      calories: directCaloriesValid
        ? directCaloriesRow.unit
        : caloriesRow?.unit ?? '',
      protein: proteinRow?.unit ?? '',
      carbs: carbsRow?.unit ?? '',
      fat: fatRow?.unit ?? '',
    },
    extractedRowCount: rows.length,
    calorieSource: directCaloriesValid ? 'direct-kcal-field' : 'row-kcal',
  };
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

async function imageToText(ai: any, imageBase64: string, mimeType: string) {
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
  return markdownData(converted);
}

async function structureNutritionText(
  ai: any,
  description: string,
): Promise<Record<string, unknown> | null> {
  const result = await ai.run(STRUCTURE_MODEL, {
    messages: [
      {
        role: 'system',
        content:
          'Transcribe a nutrition table into structured rows. Preserve the pairing between each printed nutrient label and the number from the SAME row. Row order is irrelevant. Never shift values between neighboring rows. Read calories separately only from a clearly identified kcal/Calories value, never from kJ.',
      },
      {
        role: 'user',
        content:
          `Nutrition-label OCR:\n${description.slice(0, 10000)}\n\n` +
          'Choose ONE nutrition-value column, preferring an explicitly labeled per-100-g column. Put its gram basis in basisGrams and its heading in basisLabel. ' +
          'CALORIES: in addition to the row transcription, explicitly read the kcal/Calories value from the Energy/Calories row in that SAME chosen column. Put its numeric value in calories, the printed energy/calorie row label in caloriesLabel, and its kcal/Calories notation in caloriesUnit. Never use or convert kJ. If both kJ and kcal are printed, calories must be the kcal value. ' +
          'ROWS: output every nutrition row from that same column as {label,value,unit}; keep the printed label as literally as possible. Do not map protein/fat/carbs to app fields. The server will map them by their row names. ' +
          'Energy is special: if the OCR contains both kJ and kcal/Calories for the same energy row, you may output two row objects with the same energy label, one for kJ and one for kcal; still fill the dedicated calories fields from kcal. ' +
          'Recognize kcal forms including kcal, kCal, Kcal, Calories, קק״ל, קק\"ל, קלוריות, سعرات حرارية. ' +
          'Do not mix per-serving and per-100-g values. If a row is unreadable, omit it rather than guessing. ' +
          'Use Hebrew only for name, servingName and reason; preserve nutrition row labels in their original language.',
      },
    ],
    response_format: { type: 'json_schema', json_schema: labelSchema },
    max_completion_tokens: 1300,
    temperature: 0,
  });
  const direct = directObject(result);
  if (direct) return direct;
  const raw = extractModelText(result);
  return raw ? extractJson(raw) : null;
}

export async function onRequestGet(context: any) {
  return jsonResponse({
    status: 'ok',
    aiBinding: Boolean(context.env?.AI),
    structureModel: STRUCTURE_MODEL,
    pipeline: 'nutrition-label-ocr-v8-direct-calories-fast',
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

  try {
    const text = await imageToText(ai, imageBase64, mimeType);
    if (!text) {
      return jsonResponse({ error: 'empty_ocr_response' }, 502);
    }

    const parsed = await structureNutritionText(ai, text);
    if (!parsed) {
      return jsonResponse({ error: 'empty_structure_response' }, 502);
    }

    return jsonResponse({
      ...normalizeLabel(parsed),
      structureModel: STRUCTURE_MODEL,
      pipeline: 'cloudflare-markdown-ocr-direct-calories-fast',
    });
  } catch (error) {
    console.error('nutrition label recognition failed', error);
    return jsonResponse({ error: 'ai_request_failed' }, 502);
  }
}

const MODEL = '@cf/google/gemma-4-26b-a4b-it';
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
  if (typeof result.description === 'string') return result.description.trim();
  if (typeof result.output_text === 'string') return result.output_text.trim();
  if (typeof result.text === 'string') return result.text.trim();
  if (typeof result.response === 'string') return result.response.trim();

  if (result.response && typeof result.response === 'object') {
    const nested =
      textFromContent(result.response.content) ||
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
  if (kind === 'fat' && containsAny(label, ['total fat', 'סך השומנים', 'שומן כולל', 'اجمالي الدهون', 'إجمالي الدهون'])) {
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
  if (kind !== 'calories' && containsAny(unit, ['g', 'gram', 'גרם', 'غ'])) score += 1;
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

  const rawCalories = caloriesRow?.value ?? 0;
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
    !caloriesRow ? 'calories' : '',
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
      ? `לא נמצאה שורה מזוהה בבירור עבור: ${missingFields.join(', ')}.`
      : '',
    energyMismatch
      ? 'יש אי־התאמה גדולה בין הקלוריות לבין החלבון/פחמימות/שומן; נדרש אימות נוסף.'
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
    validation: 'semantic-nutrition-rows-v3-calorie-crosscheck',
    missingFields,
    energyMismatch,
    energyDifferenceRatio,
    basisLabel: typeof parsed.basisLabel === 'string' ? parsed.basisLabel.trim() : '',
    sourceLabels: {
      calories: caloriesRow?.label ?? '',
      protein: proteinRow?.label ?? '',
      carbs: carbsRow?.label ?? '',
      fat: fatRow?.label ?? '',
    },
    sourceUnits: {
      calories: caloriesRow?.unit ?? '',
      protein: proteinRow?.unit ?? '',
      carbs: carbsRow?.unit ?? '',
      fat: fatRow?.unit ?? '',
    },
    extractedRowCount: rows.length,
  };
}

function candidateScore(candidate: any): number {
  let score = 0;
  if (candidate?.caloriesPer100g > 0) score += 2;
  if (candidate?.proteinPer100g > 0) score += 3;
  if (candidate?.carbsPer100g > 0) score += 3;
  if (candidate?.fatPer100g > 0) score += 3;
  if (candidate?.energyMismatch === true) score -= 3;
  score += numberValue(candidate?.confidence, 1);
  return score;
}

function needsCrossCheck(candidate: any): boolean {
  return (
    !(candidate?.caloriesPer100g > 0) ||
    !(candidate?.proteinPer100g > 0) ||
    !(candidate?.carbsPer100g > 0) ||
    !(candidate?.fatPer100g > 0) ||
    candidate?.energyMismatch === true
  );
}

async function structureDescription(ai: any, description: string) {
  const result = await ai.run(STRUCTURE_MODEL, {
    messages: [
      {
        role: 'system',
        content:
          'Transcribe a nutrition table into structured rows. Preserve the semantic pairing between each printed nutrient label and the number on that SAME row. Row order is irrelevant. Never rename a row before pairing its value and never shift a value to a neighboring row.',
      },
      {
        role: 'user',
        content:
          `Nutrition-label OCR:\n${description.slice(0, 10000)}\n\n` +
          'Choose one nutrition-value column: prefer the column explicitly labeled per 100 g. Put its gram basis in basisGrams and copy its column header into basisLabel. ' +
          'Then output rows as an array. For EVERY visible nutrition row in that chosen column, copy the row label as literally as possible into label, copy the number from that SAME row into value, and copy its printed unit into unit. ' +
          'Do not convert or classify rows into protein/fat/carbs yourself. The server will do that later. ' +
          'Energy is special: many labels print both kJ and kcal on the SAME energy row. Preserve BOTH values by emitting two row objects with the same energy label, one with the kJ value/unit and one with the kcal value/unit. Never drop the kcal value merely because kJ appears first. ' +
          'If kcal is written as kCal, Kcal, Calories, קק״ל, קק\"ל, קלוריות, سعرات حرارية or another clear kilocalorie notation, preserve that notation in unit. ' +
          'Do not use values from a different column. If the table cannot be read reliably, set recognized=false. Use Hebrew only for name, servingName and reason; preserve nutrition row labels in their original language.',
      },
    ],
    response_format: { type: 'json_schema', json_schema: labelSchema },
    max_completion_tokens: 1700,
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
          'Transcribe nutrition-table rows faithfully. Keep each visible row label attached to the number printed on that same row. Do not map nutrients to app fields; the server performs that mapping.',
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
    max_completion_tokens: 2300,
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
    pipeline: 'nutrition-label-vision-v6-calorie-crosscheck',
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
Read the nutrition table visible in this food-label image.

IMPORTANT: nutrition rows may appear in ANY order. Do not decide what a number means from its vertical position.

Your task is transcription first, not app-field mapping:
1. Choose ONE nutrition-value column. Prefer a column explicitly labeled per 100 g / 100 grams.
2. Set basisGrams to that column's gram basis and copy the visible column heading into basisLabel.
3. For EVERY visible nutrition row in that chosen column, emit one item in rows with:
   - label: copy the printed nutrient name as literally as possible.
   - value: copy the number printed on that SAME row in the chosen column.
   - unit: copy the unit printed for that value.
4. Never shift a value up/down to a neighboring row. Never rename a row before copying its value.
5. Do NOT decide which row is protein, fat, carbs or calories. The server will map row names deterministically after extraction.
6. Energy is special: labels often print BOTH kJ and kcal on the same Energy/אנרגיה/طاقة row. If both are visible, emit TWO row items with the same label: one for the kJ value and one for the kcal/Calories value. Do not discard kcal if kJ is also present.
7. Preserve the energy unit exactly enough to distinguish kJ from kcal/Calories, including forms such as kcal, kCal, Kcal, Calories, קק״ל, קק\"ל, קלוריות, سعرات حرارية.
8. Do not mix values from per-serving and per-100g columns.
9. If a row or number is not readable, omit that row rather than guessing.

Other rules:
- Use product/food name only if clearly visible; otherwise name="".
- servingName and servingGrams are optional and must be visible.
- Do not infer kosher status, meat/dairy/pareve, ingredients, allergens, brand or category.
- If a readable gram-based nutrition table is not visible, recognized=false and confidence low.
- Use Hebrew for name, servingName and reason, but preserve nutrition row labels in their original printed language.

Return exactly one JSON object with these keys:
recognized, name, basisGrams, basisLabel, rows, servingName, servingGrams, confidence, reason.
`;

  let result: any = null;
  let lastDiagnostic: Record<string, unknown> = {};
  let bestCandidate: any = null;
  let bestPipeline = '';

  try {
    for (let attempt = 0; attempt < 2; attempt += 1) {
      try {
        result = await runVision(
          ai,
          dataUrl,
          attempt === 0
            ? prompt
            : `${prompt}\nRetry: transcribe the table row-by-row. Keep each exact printed label paired with the value horizontally aligned with that label in the selected column. Pay special attention to the Energy row and preserve the kcal value separately from kJ.`,
        );
        const direct = directObject(result);
        const raw = extractModelText(result);
        const parsed = direct ?? (raw ? extractJson(raw) : null);

        if (parsed) {
          const normalized = normalizeLabel(parsed);
          const pipeline =
            attempt === 0 ? 'vision-row-first' : 'vision-row-first-retry';
          if (!bestCandidate || candidateScore(normalized) > candidateScore(bestCandidate)) {
            bestCandidate = normalized;
            bestPipeline = pipeline;
          }
          if (!needsCrossCheck(normalized)) {
            return jsonResponse({
              ...normalized,
              model: MODEL,
              structureModel: STRUCTURE_MODEL,
              pipeline,
            });
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
        const normalized = normalizeLabel(parsed);
        const pipeline = 'cloudflare-markdown-ocr-row-first';
        if (!bestCandidate || candidateScore(normalized) > candidateScore(bestCandidate)) {
          bestCandidate = normalized;
          bestPipeline = pipeline;
        }
      }
    } catch (markdownError) {
      console.warn('nutrition label markdown OCR fallback failed', markdownError);
      if (!bestCandidate) {
        return jsonResponse(
          {
            error: 'ocr_fallback_failed',
            ...lastDiagnostic,
          },
          502,
        );
      }
    }

    if (bestCandidate) {
      return jsonResponse({
        ...bestCandidate,
        model: MODEL,
        structureModel: STRUCTURE_MODEL,
        pipeline: bestPipeline,
      });
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

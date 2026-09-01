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
    if ('exerciseIds' in candidate) {
      return candidate as Record<string, unknown>;
    }
  }
  return null;
}

type CatalogItem = { id: string; nameHe: string; muscleGroup: string };

function normalizeCatalog(value: unknown): CatalogItem[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (!item || typeof item !== 'object') return null;
      const row = item as Record<string, unknown>;
      const id = typeof row.id === 'string' ? row.id.trim() : '';
      const nameHe = typeof row.nameHe === 'string' ? row.nameHe.trim() : '';
      const muscleGroup = typeof row.muscleGroup === 'string' ? row.muscleGroup.trim() : '';
      if (!id || !nameHe) return null;
      return { id, nameHe, muscleGroup };
    })
    .filter((item): item is CatalogItem => item !== null);
}

const systemPrompt = `
You are a fitness planner inside a Hebrew-language healthy-lifestyle app --
NOT a doctor or physical therapist, and you never give medical advice.

You choose today's workout by picking 4 to 6 exercises FROM THE GIVEN
CATALOG ONLY (a JSON array of {id, nameHe, muscleGroup}) -- never invent an
exercise, an id, or a set/rep scheme that isn't in the catalog; sets/reps
for each exercise are fixed elsewhere and are not your job.

Use "context" (primaryGoal, activityLevel, workoutDaysPerWeek, dayOfWeek,
recentMuscleGroups -- muscle groups already trained on recent days) to:
- Build a sensible, balanced session: prefer 2-3 different muscle groups
  over 5 exercises for the same one, unless the catalog genuinely only
  covers one group right now.
- Rotate the split: prefer muscle groups that are NOT in recentMuscleGroups
  over ones that are, so the plan doesn't repeat the same day two days
  running. If everything reasonable is in recentMuscleGroups (e.g. a very
  small catalog), it's fine to reuse -- just prefer variety when there's a
  real choice.
- Lean the emphasis (not the exact numbers) toward the goal: e.g. more
  compound/multi-muscle picks for muscle gain, a broader full-body mix for
  weight loss or general fitness -- but every pick must still come from the
  catalog.

Selection should reflect well-established exercise-science consensus, not
just "pick something from each group" at random:
- Prioritize compound, multi-joint movements (e.g. squat/press/row/pull/hinge
  patterns) over single-joint isolation picks when the catalog offers both
  for a needed muscle group -- compounds train more muscle per exercise and
  are the backbone of most evidence-based programs.
- Favor training a muscle group roughly every 48-72 hours over very long
  gaps between sessions for the same group (frequency supports better
  results than the same weekly volume crammed rarely) -- this is what
  recentMuscleGroups rotation above is for.
- For workoutDaysPerWeek that's low (e.g. 2-3), lean toward full-body /
  compound-heavy sessions each time rather than narrow splits; for higher
  frequency, a body-part split is reasonable.
Never present this as citing a specific study or live statistic -- it's
general, broadly-accepted training guidance being applied to catalog
selection, not a claim of real-time or personalized medical research.

Return exactly one JSON object with a single key: exerciseIds (an array of
catalog id strings, in the order the workout should be performed).
`;

async function runFitnessPlan(ai: any, context: unknown, catalog: CatalogItem[]) {
  return ai.run(MODEL, {
    messages: [
      { role: 'system', content: systemPrompt },
      {
        role: 'user',
        content: `context (JSON, already computed by the app):\n${JSON.stringify(context)}\n\ncatalog (JSON, the only exercises you may choose from):\n${JSON.stringify(catalog)}`,
      },
    ],
    response_format: { type: 'json_object' },
    chat_template_kwargs: { enable_thinking: false },
    max_completion_tokens: 300,
    // Moderate -- some variety in exercise selection is welcome, but this
    // is a constrained pick from a fixed catalog, not open conversation
    // (coach-chat.ts uses 0.65 for that reason; this is more conservative).
    temperature: 0.4,
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
    pipeline: 'fitness-plan-json-object-v1',
  });
}

export async function onRequestPost(context: any) {
  const request = context.request as Request;
  const ai = context.env?.AI;

  let body: any;
  try {
    body = await request.json();
  } catch (_) {
    return jsonResponse({ error: 'invalid_json' }, 400);
  }

  const catalog = normalizeCatalog(body?.catalog);
  if (catalog.length === 0) {
    return jsonResponse({ error: 'invalid_input' }, 400);
  }

  const requestContext =
    body?.context && typeof body.context === 'object' ? body.context : {};

  if (!ai) {
    return jsonResponse({ error: 'ai_binding_missing' }, 503);
  }

  let result: any = null;
  try {
    result = await runFitnessPlan(ai, requestContext, catalog);

    const direct = directObject(result);
    const raw = extractModelText(result);
    const parsed = direct ?? (raw ? extractJson(raw) : null);

    const rawIds = Array.isArray(parsed?.exerciseIds) ? parsed!.exerciseIds : [];
    const catalogIds = new Set(catalog.map((item) => item.id));
    // Defensive: only ever return ids that were actually offered in this
    // request's catalog -- the client trusts these to look up a real
    // exercise (name/sets/reps/image), so a hallucinated id must never
    // reach it. Duplicates collapsed, order preserved.
    const exerciseIds = [...new Set(rawIds.filter((id: unknown) => typeof id === 'string' && catalogIds.has(id)))];

    if (exerciseIds.length === 0) {
      return jsonResponse(
        {
          error: 'empty_model_response',
          ...diagnosticShape(result),
        },
        502,
      );
    }

    return jsonResponse({
      exerciseIds,
      model: MODEL,
      pipeline: 'fitness-plan-json-object-v1',
    });
  } catch (error) {
    console.error('fitness plan failed', error);
    return jsonResponse(
      {
        error: 'ai_request_failed',
        ...diagnosticShape(result),
      },
      502,
    );
  }
}

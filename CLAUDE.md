# healthy-lifestyle-app — הקשר קבוע ל-Claude Code

> קובץ זה נטען אוטומטית ע"י Claude Code (CLI/דפדפן) בכל הפעלה בריפו הזה.
> הוא עותק-ליבה של תיק פרויקט מלא ("healthy-lifestyle") שמתוחזק בפרויקט Claude נפרד
> (Cowork) ומתעדכן שם בפירוט רב יותר אחרי כל PR — לצלילה עמוקה/היסטוריה מלאה, שם המקום.
> **אל תמחק היסטוריה מקובץ זה — רק עדכן/הוסף.**

## המצב הנוכחי (מעודכן ל-26.08.2026)

`main` כולל סנכרון ענן דו-כיווני מלא (Supabase) לכל הישויות: פרופיל, מטרות, ארוחות,
מזווה, רשימת קניות, משקל, מזונות אישיים, ציוד מותאם אישית. PR #25-#36 כולם ממוזגים
ומאומתים (CI + בדיקה ידנית). כיוון הפיתוח הנוכחי: לחזק את עמוד התזונה (תיעוד מהיר,
הצעות AI אמיתיות), ואז מאמן AI אמיתי (רגשי+מעשי), ואז מאמן כושר AI אמיתי, ואז מעבר
עיצוב כולל לממשק (יעד: אינטואיטיבי, קליל, צעיר ועכשווי — הפלטה הנוכחית ב-`AppTheme`
היא Material 3 גנרי, לא "סקסי").

**המאמן (`coachResponse()`) והתאמת הכושר (`_fitnessTodayWorkout`) הם עדיין rule-based
בלבד — לא LLM, לא זיכרון שיחה. זה הפער העיקרי מול החזון של בעל הפרויקט.**

## סטאק טכני (תמציתי)

Flutter Web 3.44.9 (יעד עיקרי), `AppState extends ChangeNotifier` מרכזי (חלוקה ל-part
files: `app_state_nutrition/_shopping/_fitness/_profile.dart`), SharedPreferences
(local-first), Supabase (`healthy-lifestyle-app`, ref `efhdmatwcmqqqdjdhfly`,
publishable key בלבד), Cloudflare Pages+Workers AI (מודל `@cf/google/gemma-4-26b-a4b-it`
ל-vision: `functions/api/equipment-recognize.ts`, `nutrition-label-recognize.ts`).
CI: `.github/workflows/flutter-ci.yml` — analyze→test→build→preview deploy→smoke→
production deploy (main). Repo: `shmulik33-star/healthy-lifestyle-app`.

**⚠️ יש פרויקט Supabase אחר לגמרי לא קשור: `architect-ai-cloud-pilot`
(ref `demkxppvmlxcfmhyygap`) — אסור לגעת בו בשום אופן.**

## כללי זהב — לא הצעות, אילוצים מחייבים

1. **אל תתחיל rewrite.** הרבה edge cases כבר נפתרו ומכוסים בטסטים.
2. **אל תמחק SharedPreferences** ואל תהפוך את המודל ל-cloud-only — local-first הוא
   עיקרון יסוד: המשתמש צבר נתונים מקומיים לפני login, ה-offline חייב להמשיך לעבוד.
3. **יום לוגי לא מתחיל בחצות** — `dayStartMinutes` (ברירת מחדל 05:00). שימוש ב-
   `dayStartAt`/`dayEndAt`/`day_key`, **לא** `DateTime.day` גולמי.
4. **כשרות**: תמיכה בשרי/חלבי/פרווה, זמן המתנה **לא hardcoded ל-6 שעות** — המשתמש
   בוחר בפרופיל. **אסור להסיק כשרות מתמונה/AI** — רק בחירת משתמש מפורשת.
5. **AI ממלא טופס להצגה/עריכה בלבד, לא שומר אוטומטית.** מיפוי סמנטי לפי תוכן
   (לא מיקום קבוע) לקריאת תוויות תזונה.
6. **מזווה/שיוך מזון**: matching לפי food ID קודם, name matching = fallback בלבד
   (מונע בלבול "ביצה" מול "סלט ביצים").
7. **אכילה מפחיתה מהמזווה רק אם `MealEntry.fromHome == true`** (ארוחה בחוץ/הזמנה לא
   נוגעת במלאי).
8. **תפריט שבועי**: כל פול אפשרויות (`_pickPlannedMeal`) חייב להיות בגודל **שאינו
   כפולה של 7** (אחרת המחזור מתיישר עם השבוע וחוזר על עצמו לנצח), ובחירת וראייטי
   חייבת להיות דירוג LRU (לא סינון בינארי — נשבר ברגע שכל הפול "נחשב לאחרונה").
9. **סנכרון ענן**: תבנית קבועה לכל ישות חדשה = embed בתוך `user_app_state` snapshot
   (לא טבלה נפרדת, אלא אם היא צריכה conflict semantics שונים כמו daily progress) +
   tombstones (`deletedXIds` map) למחיקות + `revision`/fingerprint בצד שרת למניעת
   race. **אל תשתמש בשעון המכשיר לזיהוי קונפליקטים.**
10. **בדיקות cross-device חובה על ה-stable preview URL**
    (`preview.healthy-lifestyle-app.pages.dev`) — **לא** hash URL (origin נפרד לגמרי,
    שובר session/localStorage).
11. **Secrets**: לעולם לא Cloudflare API token / Supabase service-role בקוד לקוח.
12. **UI**: עברית תקנית, RTL, labels טבעיים (לא טכניים). מטרות = multi-select +
    primary goal, לא single-select.
13. **תהליך עבודה**: בעל הפרויקט לא מתכנת ידנית. branch→PR→CI ירוק→בדיקה ידנית
    (הוראות קצרות)→merge→אימות production. לא לדחוף שינוי משמעותי ל-main בלי CI+בדיקה
    כשיש סיכון לנתוני משתמש (קובצי תיעוד בלבד, כמו זה, בטוחים לדחוף ישירות ל-main).

## גישות שכבר נכשלו — אל תחזור עליהן

Local-only cross-device (צריך Supabase), בדיקת sync על hash URL, manual sync כברירת
מחדל, nutrition label positional parsing, name-only matching במזווה, סינון בינארי
לוראייטי בתפריט, פול בגודל כפולה-של-7. פירוט מלא + הסברים בתיק הפרויקט המלא (Cowork).

## איפה למצוא עוד

תיק פרויקט מלא, כולל יומן שינויים מפורט לכל PR, טבלת PRs, החלטות ארכיטקטורה עם
הנמקות, ורשימת TODO לפי עדיפות — מתוחזק במסמך `PROJECT_BRIEF.md` בפרויקט Claude
"healthy-lifestyle" (Cowork). אם אתה Claude Code וקיבלת שאלה שדורשת הקשר היסטורי
עמוק שלא מכוסה כאן, ציין זאת למשתמש כדי שיוכל להביא את התשובה מהשיחה שם.

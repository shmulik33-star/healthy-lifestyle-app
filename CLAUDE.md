# healthy-lifestyle-app — הקשר קבוע ל-Claude Code

> קובץ זה נטען אוטומטית ע"י Claude Code (CLI/דפדפן) בכל הפעלה בריפו הזה.
> הוא עותק-ליבה של תיק פרויקט מלא ("healthy-lifestyle") שמתוחזק בפרויקט Claude נפרד
> (Cowork) ומתעדכן שם בפירוט רב יותר אחרי כל PR — לצלילה עמוקה/היסטוריה מלאה, שם המקום.
> **אל תמחק היסטוריה מקובץ זה — רק עדכן/הוסף.**

## המצב הנוכחי (מעודכן ל-15.10.2026)

`main` כולל סנכרון ענן דו-כיווני מלא דרך **Appwrite** לכל הישויות: פרופיל, מטרות,
ארוחות, מזווה, רשימת קניות, משקל, מזונות אישיים וציוד מותאם אישית. PR #25-#61 כולם ממוזגים
ומאומתים (CI + בדיקה ידנית של בעל הפרויקט, כולל production). מאמן AI אמיתי (LLM, PR #46) ומאמן כושר
AI אמיתי (LLM, PR #47) כבר במיזוג — השורה הקודמת כאן ש"שניהם עדיין rule-based" אינה
מעודכנת יותר. **מ-PR #55 האפליקציה דורשת התחברות/הרשמה בכניסה** (ראה כלל #16). כיוון
הפיתוח הנוכחי: לחזק את עמוד התזונה (תיעוד מהיר, הצעות AI אמיתיות). `main` הנוכחי
הוא commit `e2968c6` (PR #61), והרצת ה-CI האחרונה עליו עברה analyze, tests, build,
פריסת production ובדיקות smoke של Appwrite וה-offline shell בהצלחה.

**PR #61 (08.10.2026) — מעבר production מ-Supabase ל-Appwrite:** אתר ה-production
ב-Cloudflare Pages נבנה עם `CLOUD_BACKEND=appwrite`. Appwrite Cloud בפרנקפורט
(`https://fra.cloud.appwrite.io/v1`, project `6ac5fccb0004756daef1`) מספק Auth
ואחסון/סנכרון נתונים דרך מתאם same-origin תחת `/api/cloud/*`; מפתח השרת נשאר
ב-Cloudflare Secret ואינו נחשף ללקוח. נוספו revision CAS, מיזוג daily מסוג
max/max/OR, פתרון מפורש של קונפליקט מזון בשיטת keep-both, בידוד בעלים, rate limiter
פרטי ו-cache סטטי ל-offline שאינו שומר API/נתוני משתמש. Supabase הוא מקור ההגירה
וה-rollback ההיסטורי בלבד ואינו backend ה-production. קוד ה-Supabase נשאר זמנית
כמסלול fallback/השוואה; אין להחזיר production אליו בלי החלטה מפורשת ובדיקת נתונים.
יש לוודא שמפתח ה-runtime של Appwrite חודש/סובב לאחר המפתח קצר-החיים ששימש לחיתוך.

**PR #60 (16.09.2026) — מיתוג FIT HAPPENS ולוגו חדש:** שם התצוגה של האפליקציה
הוחלף ל-**FIT HAPPENS** והתווסף לוגו קטלבל קורץ במסכי הכניסה, ה-onboarding,
מסך הטעינה, splash ה-Web, favicon ו-PWA manifest. שם החבילה והמזהים הפנימיים
(`healthy_lifestyle_stage9`) נשארו ללא שינוי בכוונה. זהו שינוי מיתוג/UI בלבד —
ללא שינוי ב-state, בסנכרון או בלוגיקה העסקית.

**PR #59 (15.09.2026) — אשף onboarding למשתמש חדש:** לאחר הרשמה/כניסה ראשונה
מוצג אשף בן 6 שלבים: היכרות, מטרות, פרופיל בסיסי, ציוד, הסבר וסיכום. השדה
`AppState.onboardingCompleted` נשמר מקומית ומסתנכרן בענן; `resetForNewAccount()`
מאפס אותו עבור חשבון חדש. סיום האשף מעביר פעם אחת למסך הפרופיל להשלמת יעדי
קלוריות/חלבון והגדרות נוספות; דילוג אינו מבצע את ההעברה הזאת.

**PR #58 (14.09.2026) — שדרוג מסך הכושר:** נוספו רישום סטים/חזרות/משקל לכל
תרגיל, מילוי מראש לפי האימון הקודם, טיימר מנוחה של 60 שניות עם אפשרות לצבור סבב
נוסף, מוזיקת רקע וספירה לאחור מוקלטת 5→1. `AppState.workoutSetLogs` הוא היסטוריה
קבועה שמסונכרנת בענן וממופתחת לפי שם התרגיל, משום שאין ID יציב משותף למסלול AI
ולמסלול rule-based. באותו PR תוקן גם טקסט בלתי נראה בצ'יפים נבחרים במסך הפרופיל.
קובצי האודיו הם assets מקומיים שסופקו ע"י בעל הפרויקט, ללא תלות בשירות חיצוני.

**PR #57 (10.09.2026) — מעבר עיצוב UI למניפת "נייבי/טרה-קוטה":** `AppTheme`
(`lib/core/theme/app_theme.dart`) עודכן (הורחב, לא נכתב מחדש) לפי מוקאפ שאושר
ע"י המשתמש (5 מסכים, Claude Design/Cowork — מיפוי סמנטי מלא לכל מסך לא מתועד
בקובץ הזה, רק התוצאה). נייבי (`#28536B`) ← אקצנט ראשי, טרה-קוטה (`#C2948A`) ←
אקצנט משני, פלוס חאקי/כחול-רך. השמות הישנים (`coral`/`teal`/`lavender`/`sunny`/
`ink`/`background`) נשארו כ-aliases שממופים לצבעים החדשים, כך שכל מסך קיים שכבר
משתמש בהם קיבל את המראה החדש בלי לגעת בו — `mint`/`softMint`/`purple` נשארו כמו
שהיו (לא מכוסים במסמך העיצוב; `purple` קדם לפלטות האלה מלכתחילה). כפתורים/צ'יפים
עברו ל-pill מלא (`StadiumBorder`) עם צל, רדיוס כרטיסים 20→22. **גופן Rubik**: היה
מוזכר בקוד (`fontFamily: 'Rubik'`) כבר לפני ה-PR הזה אבל מעולם לא נרשם כ-asset אמיתי
(כלומר תמיד נפל ל-fallback בשקט) — עכשיו 4 משקלים (400/500/600/700) מצורפים כקבצים
מקומיים תחת `assets/fonts/` (**לא** `google_fonts`, כדי שיעבוד גם offline — עקרון
local-first, כלל #2). **מעבר עיצוב זה הוא לתמה בלבד** — לא נגע ב-state/sync/לוגיקה.

**PR #56 (08.09.2026) — "בא לי לנשנש" הציג הצעה אחת בלבד:** `_nutritionSmartSnackSuggestions`
החזירה *רק* פריטים מקטגוריית "חטיפים וממתקים" ברגע שהיה ולו אחד כזה בקטלוג המותר —
כך שחשבון עם מזון אישי יחיד מהקטגוריה הזו קיבל רשימה של פריט אחד בלבד במקום 3. עכשיו
עדיין מעדיפים חטיפים אמיתיים קודם, אבל משלימים ל-3 מהדירוג הכללי (ללא כפילויות) אם
יש פחות מ-3 חטיפים אמיתיים. **לא היה קשור לבאג ה-scroll הקודם (PR #53/#54)** — זו
התנהגות נפרדת לגמרי שהתגלתה רק אחרי שנוסף מזון אישי אחד מהקטגוריה.

**PR #51 (06.09.2026) — "לכידת מזון חכמה" (PR א'+ב') תוקנה אחרי בדיקה ידנית שגילתה
שלוש תקלות נפרדות, כולן ב-`quick_add_food_sheet.dart` וסביבתו:**
1. **דיאלוג טעינה שנתקע לנצח** (גם בסריקת ברקוד וגם בהערכת AI ל"אכלתי"): שורש
   הבעיה האמיתי היה ש-`showDialog()` כברירת מחדל דוחף ל-**root Navigator** של
   האפליקציה, בעוד `Navigator.of(context)` באפליקציה הזו (שמשתמשת ב-go_router
   `StatefulShellRoute.indexedStack`, כלומר Navigator נפרד לכל טאב) מחזיר את
   ה-Navigator של הטאב — שני stacks שונים. `navigator.pop()` סגר את ה-Navigator
   הלא נכון, אז הדיאלוג נשאר על המסך גם כשהפעולה הצליחה. **תמיד להעביר
   `useRootNavigator: false` ל-`showDialog`/`showModalBottomSheet` כשמשתמשים ב-
   `Navigator.of(context)` שאינו root** — אחרת זה יכול "להיראות תקוע" בלי שום
   exception לתפוס. (תוקן גם: פענוח JSON חיצוני — OFF/AI — שקרה מחוץ ל-try/catch
   וגם cast לא בטוח מסוג `as num?` שיכול לזרוק על ערך שאינו null/num.)
2. **הרשמת משתמש חדש הראתה נתונים של משתמש אחר** ("שלום שמוליק" + משקל/גובה/גיל
   מלאים): שני באגים — (א) `AppState` הכיל ברירות מחדל שנראות כמו נתוני אמת
   (`firstName='שמוליק'`, גיל 50, גובה 175, משקל 105→90) במקום ריק/0; (ב) האפליקציה
   local-first לפי עקרון, אז נתונים מקומיים קיימים "נסעו" לחשבון החדש בסנכרון
   הראשון. נוסף `AppState.resetForNewAccount()` (מאופס `_readJson` מול `AppState()`
   טרייה, כדי לא לסטות מרשימת השדות האמיתית) שמופעל לפני קריאת `signUp()` (לא
   אחרי — יש race עם ה-listener של `onAuthStateChange` שמפעיל סנכרון אוטומטי ברגע
   שנוצר session), עם דיאלוג אישור מפורש כשיש נתונים מקומיים. **חשוב: התחברות
   (sign-in) לחשבון קיים ממשיכה להתנהג הפוך — למזג, לא לאפס.**

## סטאק טכני (תמציתי)

Flutter Web 3.44.9 (יעד עיקרי), `AppState extends ChangeNotifier` מרכזי (חלוקה ל-part
files: `app_state_nutrition/_shopping/_fitness/_profile.dart`), SharedPreferences
(local-first), Appwrite Cloud (Auth + TablesDB דרך Cloudflare Pages Functions),
Cloudflare Pages+Workers AI (מודל `@cf/google/gemma-4-26b-a4b-it` ל-vision:
`functions/api/equipment-recognize.ts`, `nutrition-label-recognize.ts`).
CI: `.github/workflows/flutter-ci.yml` — analyze→test→build→preview deploy→smoke→
production deploy (main). Repo: `shmulik33-star/healthy-lifestyle-app`.

Supabase `healthy-lifestyle-app` (ref `efhdmatwcmqqqdjdhfly`) הוא מקור ההגירה הישן,
לא production. **⚠️ פרויקט Supabase `architect-ai-cloud-pilot`
(ref `demkxppvmlxcfmhyygap`) אינו קשור ואסור לגעת בו.**

`https://mcp.appwrite.io/` הוא חיבור ניהול אופציונלי ל-Codex/ChatGPT באמצעות OAuth;
הוא אינו תלות runtime ואינו נדרש כדי שהאפליקציה, ה-CI או הסנכרון יעבדו.

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
11. **Secrets**: לעולם לא Cloudflare API token, `APPWRITE_API_KEY` או Supabase
    service-role בקוד לקוח. Appwrite session נשמר רק ב-cookie מסוג HttpOnly/Host-only.
12. **UI**: עברית תקנית, RTL, labels טבעיים (לא טכניים). מטרות = multi-select +
    primary goal, לא single-select.
13. **תהליך עבודה**: בעל הפרויקט לא מתכנת ידנית. branch→PR→CI ירוק→בדיקה ידנית
    (הוראות קצרות)→merge→אימות production. לא לדחוף שינוי משמעותי ל-main בלי CI+בדיקה
    כשיש סיכון לנתוני משתמש (קובצי תיעוד בלבד, כמו זה, בטוחים לדחוף ישירות ל-main).
14. **דיאלוגים/bottom sheets עם `Navigator.of(context)`**: האפליקציה משתמשת ב-
    go_router `StatefulShellRoute.indexedStack` — יש Navigator נפרד לכל טאב, לא רק
    root אחד. `showDialog`/`showModalBottomSheet` על `NavigatorState` שהתקבל מ-
    `Navigator.of(context)` (לא root) **חייבים** `useRootNavigator: false`, אחרת
    ה-pop המאוחר סוגר Navigator אחר לגמרי וה-UI "נתקע" בלי exception לתפוס (ראה
    PR #51).
15. **ברירות מחדל של `AppState` לעולם לא ייראו כמו נתוני אמת** — שם/גיל/גובה/משקל
    חדשים מתחילים ריקים/0, לא ערך שרירותי שנראה כמו פרופיל אמיתי (ראה PR #51:
    `firstName='שמוליק'` היה ברירת מחדל שרדה מבדיקות, לא onboarding מכוון).
16. **כניסה לאפליקציה דורשת התחברות/הרשמה** (PR #55, הועבר ל-Appwrite ב-PR #61): `AppStateGate`
    (`lib/app/app_state_gate.dart`) שומר `_signedIn` ומחליף את כל עץ ה-routes
    ב-`AuthGateScreen` (`lib/features/profile/auth_gate_screen.dart`) כל עוד אין
    session פעיל. במסלול production של Appwrite, `CloudGateway` משחזר hint מקומי
    לצורך פתיחה offline ומאמת את ה-session דרך cookie מאובטח כשהרשת זמינה; סוד
    Appwrite אינו נשמר בלקוח. ה-gate מאזין ל-`CloudGateway.authChanges` כדי להחליף
    מסך ברגע שההתחברות/הרשמה מצליחה. **AppState
    עדיין נטען תמיד ראשון, ללא תלות באימות** (עקרון local-first, כלל #2) — ה-gate
    חוסם רק איזה מסך מוצג, לא את טעינת הנתונים המקומיים; זרימת האיפוס-לפני-signUp
    (כלל #15/PR #51) עדיין חלה במלואה ב-`AuthGateScreen`.

## גישות שכבר נכשלו — אל תחזור עליהן

Local-only cross-device (צריך backend ענן; כיום Appwrite), בדיקת sync על hash URL, manual sync כברירת
מחדל, nutrition label positional parsing, name-only matching במזווה, סינון בינארי
לוראייטי בתפריט, פול בגודל כפולה-של-7. פירוט מלא + הסברים בתיק הפרויקט המלא (Cowork).

## איפה למצוא עוד

תיק פרויקט מלא, כולל יומן שינויים מפורט לכל PR, טבלת PRs, החלטות ארכיטקטורה עם
הנמקות, ורשימת TODO לפי עדיפות — מתוחזק במסמך `PROJECT_BRIEF.md` בפרויקט Claude
"healthy-lifestyle" (Cowork). אם אתה Claude Code וקיבלת שאלה שדורשת הקשר היסטורי
עמוק שלא מכוסה כאן, ציין זאת למשתמש כדי שיוכל להביא את התשובה מהשיחה שם.

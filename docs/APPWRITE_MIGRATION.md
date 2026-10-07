# Appwrite migration checkpoint — 2026-10-07

Target: `healthy-lifestyle-app-clean`, project `6ac5fccb0004756daef1`, Frankfurt
(`https://fra.cloud.appwrite.io/v1`). Database: `public`.
Source: Supabase project `efhdmatwcmqqqdjdhfly`.

The second wizard run `6ac602a97ac376f52740` reports Failed because the
PostgreSQL index conversion treats UUID/text keys as multi-megabyte strings.
Despite incomplete migration counters, the Console shows 14 app-state rows,
59 daily-progress rows, and 9 custom-food rows, matching source counts.
The wizard reports all 14 Auth users imported.

Repaired on the target only:

- All three `user_id` columns: size 36.
- `user_daily_progress.day_key`: size 10.
- `user_custom_foods.food_id`: size 128 (current source max length 23).
- Unique indexes `user_app_state_pkey` (`user_id`),
  `user_daily_progress_pkey` (`user_id`, `day_key`), and
  `user_custom_foods_pkey` (`user_id`, `food_id`) are Available.

Source `NOT NULL` constraints on payload, revision, water_cups, steps and
workout_completed were restored and verified as `is_nullable = NO`.
The existing app is still connected to Supabase. No cutover or pause occurred.

## Required before cutover

1. COMPLETED: ran `node tool/appwrite_migration_audit.mjs` with a short-lived server key
   in `APPWRITE_API_KEY`, granting only users.read, databases.read, tables.read,
   columns.read, indexes.read and rows.read. The audit is read-only and prints
   aggregate results, never user payloads or credentials.
   Verified 14 Auth users and 14/59/9 rows, unique logical keys, existing Auth
   owners, parseable object payloads, valid revisions and daily field types/ranges.
   All three unique indexes are available. All tables have rowSecurity=false,
   zero table permissions and zero rows with permissions: client access is not
   configured. This does not verify source-value equality or password login.
   Audit key expires 2026-10-08 at 23:59 Asia/Jerusalem; its local temporary
   secret file was removed after the audit. No secret is committed.
2. COMPARISON COMPLETED (read-only): daily progress (59 rows) and custom foods
   (9 rows) match source. All 14 app-state payloads differ because the wizard
   converted empty JSON objects into empty arrays. Owner IDs, revisions and
   updated_at match. A source-derived, path-hashed restoration dry run matches
   all 14 complete app-state records. Subsequently APPLIED with explicit user
   approval: repaired only the payload column of all 14 rows. The full audit
   now matches all 82 rows against the source comparison snapshot; ownership,
   revision, application updated_at and permissions were not changed.
   Comparison includes all application columns, timestamps normalized to
   epoch milliseconds, and JSON numbers normalized to JavaScript double
   precision. It does not compare Auth password hashes or sessions.
   `tool/appwrite_source_fingerprints.sql` and the audit implement reproducible
   comparisons. Local fingerprint/path plans are ignored by Git.
   Eight Node tests pass, including strict source-path-only repair and safeguards
   against changing legitimate empty lists or overwriting non-empty data.
   Used `codex-migration-data-repair`, the six existing read scopes plus
   rows.write; expires 2026-10-08 at 23:59 Asia/Jerusalem. Its local secret
   file was removed after verification; the cloud key remains until expiry
   or explicit revocation. No rows were deleted or created.
   Recovery copy (contains private data, no API key):
   `C:/Users/Helpdesk/AppData/Local/Temp/healthy-appwrite-payload-backup-20261007.json`.
   It contains the 14 pre-repair rows; keep private and remove after cutover QA.
   `tool/appwrite_payload_repair.mjs` requires source-matching preflight,
   exclusive backup creation, a fresh per-row check and post-write verification.
   No production clients currently write to this target; preflight is not a
   substitute for server-side atomic concurrency control during live operation.
3. COMPLETED: app-state payload default is valid JSON `{}` rather than a copied
   SQL expression; revision remains 1. Daily defaults are water_cups=0, steps=0,
   workout_completed=false. Verified directly through the API: Console renders
   falsy defaults as NULL, so its table display is not reliable for 0/false.
   Defaults were saved through Console; existing row data still matches source.
   Appwrite columns with defaults are optional; server adapters must reject
   explicit nulls and preserve the source required-field contracts.
   Application updated_at columns remain required, with no SQL now() default:
   the server adapter must supply its own timestamp, not the device timestamp.
4. COMPLETED: `user_custom_foods_updated_at_idx` (key, not unique),
   user_id ASC and updated_at DESC; verified available in Console and API.
5. COMPLETED with explicit approval: enabled row security and assigned owner-only
   read access to all 82 rows. The wizard did not
   translate Supabase RLS; tables currently have no client permissions.
   Do not grant global read/write permissions to work around this.
   Enabled rowSecurity on all three target tables, retaining empty table
   permissions; assigned each of the
   82 existing rows only `read("user:<user_id>")`. No client create/update/delete
   grants. All sync writes must go through a server adapter that authenticates
   the session and derives owner identity itself; client ownership is untrusted.
   Reused the existing short-lived repair key, without expanding its scopes.
   Table security was changed in Console; row permissions through the API.
   `tool/appwrite_owner_permissions.mjs` preflights all tables/owners/data,
   refuses unexpected grants, backs up pre-update permissions, rechecks each row,
   updates only permissions, and verifies all 82 rows against source afterward.
   Recovery copy: `C:/Users/Helpdesk/AppData/Local/Temp/healthy-appwrite-permissions-backup-20261007.json`.
   Local key file was removed after verification; cloud key expires as above.
   API audit confirms rowSecurity=true, zero table grants and exactly one
   owner read grant for every row, with all data/defaults unchanged.
   Anonymous requests without key/JWT/cookie return 200 with total=0 and rows=[]
   on all three tables. Reproduce with `node tool/appwrite_anonymous_access_check.mjs`.
   Twelve Node tests pass. Live positive owner access and negative cross-account
   authenticated access remain untested until session/platform integration QA.
6. Port server revision increments and atomic daily max/max/OR merging.
   PostgreSQL functions and triggers were not imported.
7. Add a backend adapter, preserving SharedPreferences and existing merge /
   tombstone semantics, and use the stable preview origin for cross-device QA.
8. Verify imported passwords/auth IDs, account isolation, offline restart,
   conflict handling, signup and sync before deployment and source pause.
9. Rotate the previously exposed Supabase migration credentials after use.

Architect production and Baseline are outside this migration's scope.

## Adapter implementation checkpoint — 2026-10-07

Implemented on `codex/appwrite-migration`, not merged or cut over:

- `CloudGateway` selects Supabase by default; only a web build with
  `--dart-define=CLOUD_BACKEND=appwrite` uses same-origin `/api/cloud/*`.
  Existing SharedPreferences and legacy Supabase merge paths remain intact.
- Appwrite identity hints restore offline access without waiting for the network.
  Hints are not credentials: the server independently verifies the HttpOnly,
  Secure, SameSite=Strict host-only session cookie for every cloud operation.
- Server owner filters derive exclusively from the verified account. Expected-user
  headers reject stale in-flight requests after account switching. No API keys,
  session secrets, upstream bodies or private payloads are returned/logged.
- State writes use revision CAS; daily progress uses transactional max/max/OR.
  Existing rows are staged before reading merge inputs; storage conflicts retry.
  This transaction protocol still requires live Appwrite validation, including a
  rollback-only probe and concurrent-client test. Mock tests are not live evidence.
- Appwrite food edits use three-way content baselines plus server timestamp CAS,
  never device clocks. Unknown or concurrent conflicting copies are retained and
  reported as `food_conflict`; a user-facing resolution workflow remains TODO
  before production readiness. Tombstones remain the deletion authority.
- A private rate-limit Worker is prepared under `infra/auth-rate-limit` because
  Pages supports service bindings, not arbitrary Workers-only binding types.
  It has no public route or workers.dev hostname. Counters are approximate and
  per Cloudflare location, NOT a globally exact brute-force limit. Ten attempts
  per minute per hashed IP; no raw IP/email is sent to the limiter service.
  Missing/broken bindings fail auth closed. Deployment is still pending.
- CI tests the Node safeguards, checks Appwrite compilation, then builds Supabase
  for deployment unless this exact migration PR has repository variable
  `APPWRITE_PREVIEW_READY=true`. Main always builds Supabase at this checkpoint.
  This variable is not yet enabled. Do not enable it before server setup.

Verified locally: 212 Flutter tests passed (includes four content-conflict tests);
26 Node tests passed; the Appwrite web release build succeeded. The build reports
existing flutter_tts Wasm dry-run warnings and a Cupertino font warning, but the
normal JavaScript build succeeds. Static analysis has no errors/warnings, only
lint infos (rerun after final edits). No live password/session or cross-device QA
has been performed by this adapter yet.
Wrangler 4.148.0 compiled the Pages functions successfully and validated the
private limiter Worker in `deploy --dry-run` mode; no Worker was uploaded.

### Preview setup still required

1. Create `healthy-preview-cloud-runtime` in the clean Appwrite project with
   sessions.write, rows.read, rows.write only and one-week expiry. The Console
   form is prepared; key creation needs action-time approval. Verify transaction
   API scope requirements with the minimal key; never silently broaden scopes.
2. Deploy the private limiter using its own Wrangler config, then bind it only
   to Pages Preview as `AUTH_RATE_LIMITER`. Do not change the existing AI binding.
3. Add Preview-only encrypted secret `APPWRITE_API_KEY`, and Preview variables
   `APPWRITE_PREVIEW_ENABLED=true` and
   `APPWRITE_ORIGIN=https://preview.healthy-lifestyle-app.pages.dev`.
   No production Appwrite bindings/secrets or enables at this stage.
4. Verify functions bundling, session cookies, imported-password login, owner
   access, cross-account rejection, concurrent state/daily writes, expired session,
   offline restart, signup and local reset confirmation. Use the stable Preview
   URL on two devices; do not use deployment-hash origins.
5. Only then enable the Preview build gate, redeploy and complete manual QA.
   Resolve food conflicts without discarding either copy.
6. Before a later approved production cutover, briefly freeze source writes and
   reconcile all changes since the migration comparison snapshot, including any
   new Auth users. The existing Supabase production continues to receive writes;
   the earlier 82-row comparison does NOT imply perpetual source equality.
   Retain a recovery export, verify final equality and define rollback, then
   cut over. Pause Supabase only after successful production verification.

Supabase migration credentials still need rotation after use; do not paste them
into chat. Temporary repair/audit cloud keys expire as recorded above.

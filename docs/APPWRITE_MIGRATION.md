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

1. COMPLETED with action-time approval: created `healthy-preview-cloud-runtime`
   in the clean Appwrite project with sessions.write, rows.read, rows.write only
   and one-week expiry (created 2026-10-07). The minimal key successfully read a
   migrated row, created a transaction, staged an owner no-op, read the staged
   snapshot and rolled back. Application data and permissions were unchanged.
   Reproduce with `tool/appwrite_transaction_probe.mjs`; it NEVER commits.
   Appwrite returned status `failed` after the acknowledged rollback, not
   `rolled_back`. This probe does not validate commit/concurrent-write behavior.
   The temporary local key file was removed after testing; no key is committed.
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

### Access checkpoint after key creation

PR #61 initial GitHub verification passed (analyze, tests, build, existing
Supabase-preview deploy and smoke checks). No Appwrite Preview gate was enabled.
Cloudflare dashboard requires interactive sign-in, so Preview secret/binding
setup is blocked on the user signing in. Wrangler `whoami --json` also crashes
on this Windows runtime; do not infer an authenticated local CLI session.
Cloudflare login tab was opened for user handoff. No Cloudflare settings,
Appwrite production traffic or Supabase production configuration were changed.

### Preview encrypted secret checkpoint

After explicit approval to transmit the runtime key to Cloudflare, saved
`APPWRITE_API_KEY` as an encrypted Secret at the project's Preview settings.
Confirmed persistence by reloading Preview, then independently loading Production
(no APPWRITE_API_KEY row), then reloading Preview again (encrypted row present).
The dashboard uses misleading `production-server-...` DOM IDs even on Preview;
those IDs alone do not establish the actual environment. No deletion was needed.
The raw key was transferred only in memory between the two authorized consoles;
it was not printed, copied into the clipboard, written to a file or committed.
No Appwrite runtime enable flag, binding or frontend Preview gate has been enabled.

Added a migration-PR-only CI job to deploy the existing private auth-limiter
artifact after verification, using the already configured Cloudflare credential.
This does not run on main or other PRs. Deployment/scopes are not yet verified;
do not assume the existing Pages deploy token can deploy Workers. A failure must
be surfaced, not worked around by silently broadening token permissions.

### Limiter deployment permission blocker

Run 37612002161 verified the app successfully, but the separate Worker deployment
job failed with `No access to the specified resource` at the Workers deployments
API. The existing Pages credential has not been altered or expanded. Changed the
job to require a separate `CLOUDFLARE_WORKERS_API_TOKEN` and an explicit repository
variable `APPWRITE_WORKER_DEPLOY_READY=true`; until provisioned the job is skipped,
not fixed. The frontend Appwrite gate and server enable flag remain off.
Any new Cloudflare credential needs explicit approval; use minimal Workers-script
deployment permissions, account restriction and short expiry, separate from Pages.

Also strengthened food CAS to compare both the last observed payload and server
timestamp inside the transaction. This prevents same-millisecond writes from
silently overwriting an edit. Added a regression test; 27 Node tests pass, and
Flutter static analysis passes with lint infos only. Live commit/concurrency QA
and food-conflict resolution UI are still outstanding.

### Separate Worker deployment credential provisioned

With explicit action-time approval, created account-owned Cloudflare token
`healthy-preview-worker-deploy`, limited to Workers Scripts Write in the existing
Cloudflare account, with the dashboard showing expiry October 15, 2026 (7 days).
This permission is account-wide for Workers, not restricted to one script.
Stored it as encrypted GitHub Actions repository secret
`CLOUDFLARE_WORKERS_API_TOKEN`; verified the secret name/timestamp via GitHub.
The temporary transfer file was removed after successful storage. The existing
Pages credential and Architect remain unchanged. Enabled only the repository
variable `APPWRITE_WORKER_DEPLOY_READY=true` and reran CI run 37612822593.
Run 37612822593 completed successfully: all verification and Preview smoke checks
passed, then the private Worker deployed with LOGIN_LIMIT (10 requests/60s), no
public targets, version `904b14c7-bfca-4dd7-a46f-7093d98a71a5`.
After this successful deployment, set `APPWRITE_WORKER_DEPLOY_READY=false` again
to avoid unnecessary redeployment on every QA run (or failure when its short-lived
deploy credential expires). Runtime service operation does not use this credential.

Added Preview-only enable/origin variables and AUTH_RATE_LIMITER service binding
to Wrangler config, explicitly retaining Preview's AI binding. No root/production
Appwrite variables or services are configured. The encrypted runtime secret was
already provisioned separately in Preview. Added a credentials-free HTTP smoke
probe for disabled/absent production, unauthorized Preview access, origin rejection
and malformed sign-in passing the private limiter before input validation. This
probe does not contact an Appwrite account or write application data; it consumes
one Preview rate-limit attempt. The frontend Appwrite gate remains off until this
new deployment is verified. Password/login, commits and cross-device QA remain
outstanding; a successful configuration probe is not proof of migration completion.

The first configuration smoke (run 37617513024) failed. Subsequent credentials-free
HTTP probes confirmed origin rejection works, but the same-origin malformed
sign-in persistently returned cloud_unavailable. The adapter selected `.limit`
before `.fetch`; a service binding can expose a synthetic RPC method despite the
target implementing only HTTP fetch. Changed dispatch to prefer HTTP `.fetch`
and strengthened the regression test with a throwing synthetic `.limit` method.
27 Node tests pass. Live verification of this fix is still required. Added bounded
503-only smoke retries for transient stable-hostname deployment propagation.

Run 37618280989 still observed 503 during its short post-deploy window, but the
subsequent direct live probe passed all four checks (production disabled/absent,
Preview 401 without cookie, foreign-origin POST 403, same-origin malformed POST
400 after limiter). This confirms the HTTP dispatch fix works in the deployed
runtime. Extended only the 503 propagation wait to the existing smoke convention
of 12 attempts at 5-second intervals. Other unexpected statuses still fail.
With this backend configuration verified, enable `APPWRITE_PREVIEW_READY=true`
for the migration PR's next build. This changes Preview only; production remains
Supabase. Imported-password login and all user-data QA are still pending.

### Manual QA and Preview-only offline boot fix

The user subsequently reported imported-account login and manual sync success,
phone-to-computer and computer-to-phone propagation, and a phone edit saved while
offline then synchronized after reconnecting. These are user-reported functional
checks, not an exhaustive isolation/concurrency audit. Cold offline reopening
FAILED. The public deployed Flutter service worker was verified to be a cleanup
stub that unregisters itself, not an offline cache. The default loader also used
remote CanvasKit/default font resources.

With explicit approval to fix Preview only, added a CI-gated post-build step:

- Only the migration PR with APPWRITE_PREVIEW_READY=true is transformed. No source
  web files or production build behavior change; the worker refuses installation
  on the production hostname.
- Explicit build-time static allowlist, SHA-256 integrity checks, versioned cache,
  complete install before readiness, no skipWaiting or automatic client reload.
  An update waits until the app's open windows close, protecting unsaved edits.
- Local full CanvasKit (Safari and Chromium), existing bundled Rubik (also aliased
  for the engine's default Roboto role); remove external Google Fonts links in
  Preview output. No newly downloaded fonts or SDK-specific font dependency.
- No API paths, POSTs, cross-origin requests, query URLs, source maps or unknown
  dynamic resources intercepted. Static downloads omit credentials. No cached
  password, cloud response or session cookie. No localStorage/IndexedDB changes.
- Cache cleanup touches only this feature's versioned static-cache prefix and
  retains one preceding static build. A failed install preserves the prior build.
- A Hebrew preparation/ready/update-waiting status tells the user when initial
  download is complete. Browser storage eviction can require online preparation
  again; this is not a guarantee against the OS/browser clearing site storage.

33 Node tests passed, including six offline-cache/build safety tests. A local
browser rendered the login UI after full reload with network emulation offline
and HTTP cache disabled; the test tab's network/cache overrides were restored.
This test used an empty local origin, not a user's account, and does not establish
offline authenticated restart on the phone. The default Roboto download warning
found in that first pass motivated a bundled default-font role. Initial CI then
showed modern clean SDK installations lack the legacy Roboto file, so the final
approach aliases the existing Rubik regular face for that role instead.
Deployment and final phone retest are pending at this checkpoint. Production,
Architect and all stored application data remain unchanged by this offline fix.

### Follow-up: deployed canonical redirect broke cached navigation

The user reported ERR_FAILED on Android and then desktop Chrome even online.
The stable Preview server returns 308 from /index.html to /. The initial worker
cached the followed-redirect Response and returned it for navigation. Browsers
reject such responses when the navigation redirect mode is manual; local static
hosting had no canonical redirect and therefore missed this production-host
behavior. An in-app browser navigation also reproduced net::ERR_FAILED.

The Preview-only worker now downloads the canonical root document (still SRI
checked against the built index.html bytes) and strips redirect URL metadata by
constructing a fresh Response with the verified body, status and headers when
needed, including on cache hits. A real local HTTP 308 regression fixture covers
both online and offline navigation and previously cached redirected responses.
The deployment smoke check also requires a non-redirected canonical root and
the updated worker. No skipWaiting, user-data clearing or production changes.
Phone cold reopening and browser recovery must still be rechecked after deploy.

### User-reported offline pass and conflict-resolution QA (2026-10-08)

After redirect fix f3aee02 the user confirmed recovery, Android offline cold
reopening with existing data, and a full offline-water-add/reopen/reconnect/sync/
refresh sequence without loss or duplication. These are manual user reports.
The user cannot currently provide two devices for additional concurrency QA.

Added Preview/Appwrite-only explicit keep-both resolution in Account and Sync:

- Review both food versions (macros, units, category, kosher selection, barcode)
  and confirm in a nested-navigator-safe dialog. Doing nothing preserves both.
- Persist a new randomly identified, uniquely named cloud-version copy locally
  before granting any overwrite consent. Original ID and meal references stay.
- Consent binds owner, exact reviewed local and remote content, and the preserved
  copy. Normal sync re-reads the server; changed versions/owners/copy invalidate
  consent. Existing staged-transaction CAS remains the final write guard.
- Upload preserved cloud copies before original IDs. Failures leave local copies
  durable; consent is in memory only and is re-established after restart.
- Serialize Appwrite food sync/resolution and Preview local snapshot writes to
  prevent an older pending save from overwriting a freshly preserved copy.
  A queued food sync captures its requesting owner and aborts after a switch;
  it must not read or upload that old snapshot under a newly signed-in account.
- Appwrite downloads match foods by ID only, preserving same-name distinct IDs.
  The default Supabase path retains its existing behavior. No source database,
  permissions, credentials or Production settings changed by this step.

Verification: 37 Node tests; standard Flutter suite 216 passing before the final
additional Appwrite-only queued-owner test; dedicated Appwrite mode 10 passing tests (actual sync
service using mocked same-origin HTTP, plus model/persistence/widget cases).
Additional mocked server tests cover expired/stale sessions on every data action,
cross-owner rows on later pagination, and daily transaction retry preserving
concurrent maxima. These tests are NOT a live two-account isolation audit or proof
of Appwrite transaction concurrency under real simultaneous devices.

Deployment CI and post-deploy verification are pending for this checkpoint.
Before cutover: live isolated-account/transaction QA, final source catch-up with
recovery export, expiring credential review, rollback plan and explicit approval.

### Approved production cutover preparation (2026-10-08)

User explicitly approved configuring the existing server key/binding in Healthy
Cloudflare Production and merging/deploying the migration. Supabase stays active
for recovery; Architect/Baseline remain out of scope. User reports Preview-only
use since migration testing began.

Six live API QA groups passed on isolated fake accounts: new-account emptiness,
state revision CAS race, daily max/max/OR race, food content CAS and keep-both
server writes, cross-owner gateway rejection and direct row permissions.
Meaningful direct writes return 401/user_unauthorized on all three tables and
full before/after rows are equal. Earlier no-op write expectations and raw JSON
key-order comparison were harness errors, not evidence of write access. All test
sessions revoked. Eight fake QA accounts remain for inspection; no deletions.
This proves live server paths, not a deployed Flutter conflict-dialog journey.

ACL-restricted application-data export: 14 state / 61 daily / 9 food rows plus
Auth IDs. Separate complete Appwrite row snapshots saved before catch-up.
Source state and food fingerprints still equal the original migration snapshot;
all source daily values are already covered by target maxima. Catch-up verification
required zero remote writes and preserved Preview state/food rows. Exports are
local private artifacts, not Git files and not a full Supabase database backup.

Production is now an explicit CI gate (APPWRITE_PRODUCTION_READY). Without it,
main deployment fails instead of silently publishing a mismatched backend.
Approved production uses its own strict origin and host-only cookie; existing
private limiter service is reused. Offline shell production-host support requires
an explicit --production build flag; Preview assets still refuse production.
Static/API cache isolation and waiting-update safety remain unchanged.

Production secret installation, final CI/merge/deploy and user production login
verification still pending at this source checkpoint. Existing runtime key has
short expiry (console shows five days); renew/rotate before it expires. Do not
pause Supabase until production login/data/sync have been verified.

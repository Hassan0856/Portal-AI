# PortalAI (Flutter)

The family app of the AI door monitor (Build Guide v4.0, Phase 9). It reads
Supabase with the signed-in user's session, gets live events through Supabase
Realtime, sends every change through n8n WF-02 (`/app-action`), and receives
alerts as Firebase Cloud Messaging pushes sent by n8n WF-00.

## Configuration

Four values are compiled in with `--dart-define-from-file=env.json`
(copy `env.json.example`; never commit `env.json`):

| Key | Value |
|---|---|
| `SUPABASE_URL` | `https://YOUR-PROJECT.supabase.co` |
| `SUPABASE_ANON_KEY` | the anon key (never the service_role key) |
| `N8N_BASE` | `https://YOUR-DOMAIN.ngrok-free.app/webhook` |
| `APP_KEY` | the same string as WF-02's "Key ok?" IF node |

Firebase (push only) starts from `android/app/google-services.json`, downloaded
from Firebase console -> Project settings -> Your apps -> `com.portalai.portal_ai`.
It is not committed; Codemagic writes it from the `GOOGLE_SERVICES_B64` variable.

Without `env.json` the app runs in demo mode on sample data.

## Build

Codemagic builds the APK with `codemagic.yaml` (variables in the group
`portal_ai`). Locally:

    flutter pub get
    flutter run --dart-define-from-file=env.json                 # Android phone
    flutter run -d chrome --dart-define-from-file=env.web.json   # browser (no push)

Push notifications, the guardian SOS alarm and the flashlight work only in the
Android app.

## Not used in v4

`functions/`, `firestore.rules`, `firebase.json` and `.firebaserc` belong to an
earlier Firestore SOS design. `supabase/schema.sql` and `supabase/migrations/`
are not the v4 schema: use the SQL in Build Guide v4 sections 3.1 to 3.5.
The Resident Email Management screen uses tables that are not part of v4
(`guardian_resident_links`, `guardian_resident_emails`).

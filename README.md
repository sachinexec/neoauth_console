# NeoAuth Console

Management console for the central auth service: apps, clients and third
parties, sign-in providers, token policies, users, audit log, webhooks and
admins, plus a Billing section for `neobilling-backend` (billing apps, store
credentials, catalog, customers, grants, events, API keys, webhooks, audit
log). Flutter, pinned with fvm.

## Environments

Two flavors:

| Flavor | Config file | Android package | iOS bundle ID | App name |
|---|---|---|---|---|
| `dev` | `.env.dev` | `in.neodiverse.neoauthconsole.dev` | `in.neodiverse.neoauthconsole.dev` | NeoAuth Console Dev |
| `prod` | `.env.prod` | `in.neodiverse.neoauthconsole` | `in.neodiverse.neoauthconsole` | NeoAuth Console |

Dev installs alongside prod. Each build bundles only its own `.env` file.
Dev's launcher icon has an amber "DEV" band across the bottom, so the two
can't be confused on one phone.

```bash
fvm flutter run --flavor dev
fvm flutter run --flavor prod
fvm flutter build apk --flavor prod --release
fvm flutter build ipa --flavor prod
```

The env files are gitignored; start from `.env.example`. They are bundled into
the app, so they hold only public values:
- `NEOAUTH_ISSUER`: the auth service URL. `localhost` is rewritten to `10.0.2.2`
  on the Android emulator.
- `NEOAUTH_CLIENT_ID`: the console's client in that environment, from
  `npm run console -- bootstrap` in `neoauth-backend`.

- `BILLING_URL`: the billing service (`neobilling-backend`), https (http only for
  `localhost` / `10.0.2.2`, rewritten like the issuer). Empty hides the Billing
  section's content ("Billing is not set up"). A non-https URL to a remote host
  is treated as not set up, so admin tokens never travel in clear text.
- `BILLING_RESOURCE` (optional): token audience for the billing admin API, see
  "Billing" below.

A `--dart-define` of the same name overrides the file for a one-off build.

On iOS, `--flavor` selects the `dev`/`prod` scheme and the
`Debug|Release|Profile-<flavor>` build configurations. Each has an xcconfig in
`ios/Flutter/` that sets `APP_DISPLAY_NAME`. Each flavor's configurations use
its own `AppIcon-<flavor>` icon set.

## Billing

The Billing tab talks to `<BILLING_URL>/admin/v1`. It has its own roles: the
billing service keeps an admin list (owner / admin / viewer) separate from the
console's, and the console asks it who you are (`GET /admin/v1/me`) to hide what
you cannot do. The server enforces the roles; the UI is a convenience.

| Role | Can |
|---|---|
| viewer | see apps, catalog, subscriptions, store events |
| admin | + products, entitlements, mappings; customer lookup (audited), manual grant / revoke, replay an event, billing audit log |
| owner | + register apps, store credentials, app settings, API keys, webhooks |

Grants, revokes, replays and every credential, key and webhook change need a
sign-in from the last 15 minutes: the same "Confirm it's you" sheet as
elsewhere appears and the action continues. Grants, revokes and replays also
ask for confirmation first. Store credentials, the NeoAuth webhook secret,
API keys and webhook signing secrets are write-only: the console sends them
and never shows them again (API keys and signing secrets are displayed once,
when created).

**Authentication.** The console sends its own NeoAuth access token. NeoAuth
only issues a client tokens for its own app audience, which for the console is
`<NEOAUTH_ISSUER>/admin`, so set the billing service's `ADMIN_AUDIENCE` to
exactly that, and add each admin to billing with
`PUT /admin/v1/admins/<NeoAuth user id>` (see the billing README). If
NeoAuth later issues a dedicated audience to the console client, put it in
`BILLING_RESOURCE` and the console requests tokens for that resource instead
(and `ADMIN_AUDIENCE` becomes that value). Locally, run the billing service
with `PORT=3100` (NeoAuth uses 3000).

## Layout of the bottom edge

Every vertical scroll view clears the system navigation bar through
`lib/ui/bottom_inset.dart`; `test/bottom_inset_test.dart` fails on one that
does not.

## Logo and icons

The logo is drawn in code (`lib/ui/app_logo.dart`).
`tool/render_brand_assets.dart` renders the launcher icons from it into
`assets/branding/`, and `flutter_launcher_icons-<flavor>.yaml` turns those into
each flavor's Android and iOS icons. After changing the logo:

```bash
fvm flutter test tool/render_brand_assets.dart
```

```bash
fvm dart run flutter_launcher_icons
```

## First sign-in

In `neoauth-backend`, run `npm run console -- bootstrap`, sign in once in the app,
then run `npm run console -- grant <your phone or email> owner`.

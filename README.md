# NeoAuth Console

Management console for the central auth service: apps, clients and third
parties, sign-in providers, token policies, users, audit log, webhooks and
admins. Flutter, pinned with fvm.

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

A `--dart-define` of the same name overrides the file for a one-off build.

On iOS, `--flavor` selects the `dev`/`prod` scheme and the
`Debug|Release|Profile-<flavor>` build configurations. Each has an xcconfig in
`ios/Flutter/` that sets `APP_DISPLAY_NAME`. Each flavor's configurations use
its own `AppIcon-<flavor>` icon set.

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

# مواقيت الصلاة

تطبيق Android أصلي بـFlutter لعرض مواقيت الصلاة والإقامة محليًا للمساجد.

## Run & Operate

- `pnpm --filter @workspace/api-server run dev` — run the API server (port 5000)
- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from the OpenAPI spec
- `pnpm --filter @workspace/db run push` — push DB schema changes (dev only)
- Required env: `DATABASE_URL` — Postgres connection string

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9
- API: Express 5
- DB: PostgreSQL + Drizzle ORM
- Validation: Zod (`zod/v4`), `drizzle-zod`
- API codegen: Orval (from OpenAPI spec)
- Build: esbuild (CJS bundle)

## Where things live

_Populate as you build — short repo map plus pointers to the source-of-truth file for DB schema, API contracts, theme files, etc._

## Architecture decisions

_Populate as you build — non-obvious choices a reader couldn't infer from the code (3-5 bullets)._

## Product

- شاشة أوقات عربية RTL مستوحاة من الصورة التي قدمها المستخدم، تتكيف مع الاتجاهين الأفقي والعمودي.
- يستورد المستخدم جداول المواقيت المحلية لكل منطقة وسنة؛ لا توجد مواقيت افتراضية موهومة ولا اتصال شبكة مطلوب.
- يتضمن التطبيق إعدادات محلية للمنطقة، الإقامة، العرض، التاريخ الهجري، والحماية الاختيارية برمز PIN.

## Flutter Android app

- Source: `mobile/prayer_times/` — Flutter/Dart app, local storage, models, settings UI, JSON template, and unit tests.
- Android platform templates: `mobile/prayer_times/android_template/`.
- `bash scripts/bootstrap-prayer-times-android.sh` generates the Android project when Flutter is installed.
- The GitHub Actions workflow builds APK and AAB, and runs `flutter analyze` and `flutter test`.
- This app has no backend dependency; do not add online prayer-time APIs or a WebView.

## User preferences

_Populate as you build — explicit user instructions worth remembering across sessions._

## Gotchas

_Populate as you build — sharp edges, "always run X before Y" rules._

## Pointers

- See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details

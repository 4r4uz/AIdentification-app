# aidentification_app

A new Flutter project.

## GitHub Actions

El workflow [`flutter-build.yml`](.github/workflows/flutter-build.yml) ejecuta:

- `flutter analyze` y `flutter test`.
- Builds Android en APK separados por arquitectura.
- Build iOS sin firma y lo publica como artefacto `.app.zip`.

Para que la aplicación pueda conectarse a Supabase en el artefacto, configura
los secretos `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` en el repositorio.

La firma de Android requiere agregar un keystore y sus secretos de GitHub.
La firma y distribución de iOS requiere certificados, provisioning profiles y
un equipo de Apple configurados en GitHub Actions; el workflow actual genera
una aplicación iOS sin firma para validación y empaquetado.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

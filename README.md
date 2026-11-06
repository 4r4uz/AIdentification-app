# AnimalPedia

Aplicación móvil para identificar animales a partir de fotografías y
construir una colección personal de especies descubiertas.

## Funcionalidades (WIP)

- Captura de fotografías desde la cámara del dispositivo.
- Detección del animal mediante un modelo local de IA.
- Identificación de especies y clasificación taxonómica.
- Galería de especies con imágenes, información y nivel de rareza.
- Datos curiosos sobre animales en un carrusel dinámico.
- Registro de detecciones, estadísticas y progreso del usuario.
- Trivia sobre el reino animal.
- Perfil de usuario con fotografía y autenticación.

## Tecnología

- Flutter y Dart.
- Supabase para autenticación, datos y almacenamiento.
- Modelos ONNX ejecutados localmente para la identificación.

## Requisitos

- Flutter estable.
- Dart compatible con la versión indicada en [`pubspec.yaml`](pubspec.yaml).
- Android Studio y Android SDK para Android.
- Dispositivo con cámara, memoria suficiente para los modelos de IA y conexión a internet para las funciones de Supabase.

## Configuración

Crea un archivo `.env` en la raíz del proyecto:

```env
SUPABASE_URL=tu_url_de_supabase
SUPABASE_PUBLISHABLE_KEY=tu_clave_publishable
```

Los modelos de IA deben estar disponibles en `assets/models/`:

- `megadetector_v6_fp16.onnx`
- `speciesnet_fp16.onnx`
- `labels.txt`

## Ejecución local

```bash
flutter pub get
flutter run
```

## Compilación

Android:

```bash
flutter build apk --release
```
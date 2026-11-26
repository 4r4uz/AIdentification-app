# Arquitectura de AnimalPedia

## Objetivo

El proyecto contiene dos aplicaciones Flutter dentro del mismo repositorio:

- **Mobile:** aplicación para usuarios finales, orientada a Android e iOS.
- **Web:** panel administrativo, orientado a navegador.

Ambas aplicaciones utilizan Supabase como backend, pero mantienen separadas
su presentación, navegación y lógica específica de plataforma.

## Estructura actual

```text
lib/
├── mobile/
│   ├── main.dart
│   ├── app/
│   ├── core/
│   ├── features/
│   └── widgets/
│
├── web/
│   ├── main.dart
│   ├── app/
│   ├── core/
│   ├── data/
│   └── presentation/
│
├── supabase/
│   ├── bootstrap.dart
│   ├── supabase_service.dart
│   └── supabase_extensions.dart
│
└── ARCHITECTURE.md
```

No se deben crear archivos Dart directamente en `lib/`. Las raíces de código
actuales son `lib/mobile/`, `lib/web/` y `lib/supabase/`. Este archivo es
documentación y es la excepción.

La carpeta `web/` ubicada en la raíz del repositorio contiene la configuración
de Flutter para la plataforma Web. No es el lugar donde se implementa el panel;
el código del panel administrativo está en `lib/web/`.

## Entradas de ejecución

### Aplicación móvil

El entrypoint móvil es:

```text
lib/mobile/main.dart
```

Inicializa Flutter, carga la configuración de Supabase, carga el tema guardado
y ejecuta `AnimalPediaApp`.

```bash
flutter run -t lib/mobile/main.dart
flutter build apk -t lib/mobile/main.dart --release
```

### Panel administrativo Web

El entrypoint Web es:

```text
lib/web/main.dart
```

Inicializa Flutter, carga la configuración común de Supabase y ejecuta
`AdminApp`, cuya primera pantalla es el login administrativo.

```bash
flutter run -t lib/web/main.dart -d chrome
flutter build web -t lib/web/main.dart
```

## Aplicación móvil

### `mobile/app/`

Contiene la composición de la aplicación móvil:

- `lib/mobile/app/app.dart`: `MaterialApp` principal.
- `lib/mobile/app/navigation/bottom_navigation.dart`: navegación inferior y
  acceso a las pantallas móviles.

### `mobile/features/`

Organiza las funcionalidades móviles por dominio:

- `auth/`: login, registro, modelos y servicios de autenticación.
- `camera/`: cámara, detección, modelos ONNX y resultados.
- `gallery/`: catálogo y datos de especies.
- `home/`: pantalla inicial.
- `profile/`: perfil, configuración y estadísticas del usuario.
- `trivia/`: trivias y gamificación.

Cada feature puede contener:

```text
feature/
├── data/
├── domain/
└── presentation/
```

No se deben mover pantallas ni servicios que dependan de cámara, sensores,
modelos ONNX o plugins nativos al código compartido.

### `mobile/core/`

Contiene la infraestructura utilizada por la aplicación móvil:

- `constants/app_constants.dart`: constantes de la aplicación.
- `constants/app_texts.dart`: textos reutilizables.
- `service_locator.dart`: registro de servicios usados por Mobile.
- `theme/app_theme.dart`: tema visual móvil.
- `theme/colors.dart`: paleta visual móvil.
- `theme/theme_controller.dart`: persistencia y cambio del tema móvil.

No se deben importar desde Web `service_locator.dart`, `theme/`, `features/`
ni widgets de Mobile.

### `mobile/widgets/`

Contiene widgets reutilizables únicamente dentro de la aplicación móvil:

- `lib/mobile/widgets/common_widgets.dart`.

## Panel administrativo Web

### `web/app/`

Contiene la composición de la aplicación administrativa:

- `lib/web/app/admin_app.dart`: `MaterialApp` propio del panel.

El panel no utiliza la navegación ni las pantallas de la aplicación móvil.

### `web/core/`

Contiene elementos propios de la interfaz administrativa:

- `lib/web/core/theme/colors.dart`: colores del panel.
- `lib/web/core/theme/app_theme.dart`: tema, tarjetas, espaciados y estilos.

El tema Web es independiente del tema móvil para evitar que un cambio visual
administrativo afecte la experiencia móvil.

### `web/data/`

Contiene acceso y transformación de datos administrativos:

- `lib/web/data/services/admin_service.dart`: estadísticas, usuarios, especies,
  detecciones y gamificación.
- `lib/web/data/models/billing_admin_page.dart`: métricas y resultados
  tipados del módulo administrativo de facturación.
- `lib/web/data/exporters/csv_exporter.dart`: exportación de datos desde el
  navegador.

El exportador CSV es Web-only porque utiliza APIs del navegador.

## Supabase compartido

La infraestructura general de Supabase está centralizada en
`lib/supabase/`:

- `lib/supabase/supabase_service.dart`: cliente singleton, inicialización,
  usuario actual, estado de autenticación y cierre de sesión.
- `lib/supabase/supabase_extensions.dart`: extensiones para transformar
  respuestas de Supabase en modelos y manejar consultas comunes.

`lib/supabase/bootstrap.dart` carga el entorno y utiliza el servicio
centralizado. `lib/mobile/main.dart` y `lib/web/main.dart` utilizan el mismo
bootstrap.

Las consultas específicas no se colocan en `lib/supabase/`. Permanecen en el
módulo que las utiliza:

- `lib/mobile/features/*/data/services/`: operaciones de la aplicación móvil.
- `lib/web/data/services/admin_service.dart`: operaciones administrativas.

La estructura real de tablas, columnas, políticas RLS y funciones de Supabase
pertenece al backend. Los archivos Dart solo contienen el cliente, extensiones
y utilidades generales; no reemplazan las migraciones ni las políticas.

### `web/presentation/`

Contiene la interfaz del panel:

- `lib/web/presentation/screens/admin_login_screen.dart`: autenticación de
  administradores.
- `lib/web/presentation/screens/admin_dashboard_screen.dart`: dashboard y
  módulos administrativos.
- `lib/web/presentation/screens/parts/`: componentes internos del shell y las
  pestañas administrativas. Se mantienen como `part` del dashboard mientras
  conservan dependencias privadas compartidas.
- `lib/web/presentation/screens/parts/billing_tab.part.dart`: interfaz de
  consulta de suscripciones, pagos y eventos de facturación.
- `lib/web/presentation/providers/admin_dashboard_provider.dart`: estado
  reactivo de navegación, cuenta, carga de pestañas y panel lateral.
- `lib/web/presentation/widgets/analytics_charts.dart`: gráficos de actividad y
  rareza.
- `lib/web/presentation/widgets/profile_avatar.dart`: avatar web reutilizable
  con resolución de Storage y fallback de iniciales.
- `lib/web/presentation/widgets/filter_bar.dart`,
  `detection_thumbnail.dart` y `confidence_chip.dart`: componentes comunes
  independientes del panel.

El dashboard administrativo está concentrado actualmente en
`admin_dashboard_screen.dart`. Las nuevas pantallas o widgets administrativos
deben colocarse dentro de `web/presentation/`, no dentro de `mobile/`.

## Dependencias por plataforma

Las dependencias están señalizadas en `pubspec.yaml`:

```yaml
# mobile-only
# web-only
# general
```

### `mobile-only`

Incluye dependencias relacionadas con:

- cámara;
- selección de imágenes;
- modelos ONNX;
- geolocalización;
- permisos;
- almacenamiento o rutas nativas;
- configuración de Android e iOS.

Estas dependencias no deben importarse desde `lib/web/`.

### `web-only`

Incluye dependencias utilizadas actualmente por el panel, como los gráficos
de `fl_chart`.

El código que utiliza APIs del navegador debe permanecer dentro de `lib/web/`.

### `general`

Incluye dependencias compatibles con ambas entradas, como:

- Flutter;
- Supabase;
- HTTP;
- variables de entorno;
- utilidades compartibles.

La etiqueta describe el uso permitido en este repositorio. Una dependencia
marcada como `general` puede estar declarada en el proyecto, pero una
funcionalidad concreta debe respetar las reglas de su carpeta.

## Supabase

Supabase es el backend común:

- la aplicación móvil utiliza operaciones destinadas a usuarios;
- el panel Web utiliza operaciones administrativas;
- ambas aplicaciones usan el mismo proyecto y configuración pública;
- las claves privadas nunca deben incluirse en los clientes.

La autorización administrativa no debe depender únicamente de ocultar botones.
Las políticas RLS y las validaciones del backend deben restringir las
operaciones sensibles.

La información de facturación se consulta desde Web mediante
`supabase/functions/admin-billing`, que valida el rol administrativo antes de
usar la clave de servicio. Las tablas de facturación deben tener RLS habilitado
y no conceder acceso directo a los roles `anon` ni `authenticated`. Las claves
de servicio y de proveedores permanecen exclusivamente en el backend.

## Reglas de dependencia

1. `lib/mobile/main.dart` solo debe iniciar la aplicación móvil.
2. `lib/web/main.dart` solo debe iniciar el panel administrativo.
3. La aplicación móvil no debe importar código de `lib/web/`.
4. El panel Web no debe importar pantallas, widgets, navegación ni features
   móviles.
5. Mobile y Web deben importar la infraestructura común desde `lib/supabase/`.
6. El código que use `dart:html` debe permanecer en `lib/web/`.
7. El código que use cámara, ONNX, sensores, permisos o plugins nativos debe
   permanecer en `lib/mobile/`.
8. Las consultas específicas deben permanecer en el servicio de datos de la
   aplicación que las necesita.
9. Los modelos, servicios y widgets nuevos deben colocarse en la aplicación
   que los consume. Los widgets comunes de Mobile van en `mobile/widgets/`;
   no deben llamarse `shared` porque no se comparten con Web.
10. Los imports deben usar la ruta de la aplicación correspondiente:
    `/mobile/...` para Mobile, `/supabase/...` para infraestructura común y
    rutas relativas dentro de `web/` para Web.
11. Las consultas de facturación del panel deben pasar por la función
    administrativa de Supabase; la aplicación Web no debe leer las tablas de
    pagos directamente ni ejecutar cobros hasta elegir un proveedor.

## Regla para agregar archivos

Antes de crear un archivo, identificar su responsabilidad:

| Si el archivo... | Debe ubicarse en... |
|---|---|
| Inicia o configura la aplicación móvil | `lib/mobile/app/` |
| Es una pantalla o widget móvil | `lib/mobile/features/` |
| Usa cámara, ONNX, sensores o plugins nativos | `lib/mobile/features/` |
| Es infraestructura propia de Mobile | `lib/mobile/core/` |
| Es un widget común de Mobile | `lib/mobile/widgets/` |
| Es cliente, configuración o utilidad general de Supabase | `lib/supabase/` |
| Inicia o configura el panel administrativo | `lib/web/app/` |
| Es una pantalla o widget administrativo | `lib/web/presentation/` |
| Consulta datos para el panel | `lib/web/data/services/` |
| Es un modelo administrativo Web | `lib/web/data/models/` |
| Exporta datos desde el navegador | `lib/web/data/exporters/` |
| Es una función administrativa de Supabase | `supabase/functions/` |
| Es tema o color del panel | `lib/web/core/theme/` |
| Usa APIs exclusivas del navegador | `lib/web/` |

No colocar código administrativo en `mobile/features/` ni código móvil en
`web/presentation/`. Tampoco colocar dependencias de una plataforma dentro de
la otra solo para reutilizar un archivo.

# Plan de suscripciones y pagos — AnimalPedia

## Objetivo

Diseñar un modelo de suscripción sostenible para AnimalPedia y un módulo en el
panel web que permita al equipo consultar y administrar el estado de las
suscripciones y pagos sin gestionar directamente datos de tarjetas.

Este documento es una propuesta de producto y arquitectura. Los precios,
proveedores, impuestos y políticas de las tiendas deben confirmarse para los
países donde se publique el servicio.

## Recomendación ejecutiva

Mantener el registro gratuito y ofrecer una suscripción opcional. No exigir un
pago para crear una cuenta. La identificación se realiza localmente y la
aplicación ofrece una colección personal; cobrar por entrar podría reducir la
adopción y la retención antes de que las personas perciban el valor Premium.

Controlar los costos con límites explícitos de almacenamiento y sincronización,
en vez de restringir la creación de cuentas. En el código actual, guardar una
detección requiere autenticación y sube su imagen a Supabase:

- Registro: `lib/mobile/features/auth/data/services/auth_service.dart`
- Guardado de detecciones: `lib/mobile/features/camera/data/services/detection_service.dart`

El gasto a vigilar es principalmente el almacenamiento y la transferencia de
imágenes, además del uso de base de datos. La cantidad de cuentas por sí sola
no es una razón suficiente para imponer una barrera de pago; los límites y
precios de Supabase deben revisarse cuando se lance el servicio.

## Oferta inicial propuesta

Empezar con dos niveles sencillos y un solo plan de pago:

| Funcionalidad | Gratis | Premium |
| --- | --- | --- |
| Crear cuenta y explorar la aplicación | Sí | Sí |
| Identificación local | Sí | Sí |
| Guardar detecciones en la nube | Hasta 20 | Cuota ampliada y explícita |
| Sincronización y copia de seguridad | Básica, sujeta al límite gratuito | Historial ampliado entre dispositivos |
| Estadísticas del historial | Básicas | Detalladas, con filtros |
| Exportar el historial | No inicialmente | Sí, como posible beneficio Premium |

No prometer almacenamiento ilimitado. Definir una cuota máxima para Premium y
medir el almacenamiento medio antes de ampliarla. Si el producto ofrece una
experiencia de invitado en el futuro, se puede permitir probar la identificación
sin cuenta y solicitar registro al guardar o sincronizar; sería una mejora
posterior, no un requisito para lanzar suscripciones.

### Precio inicial para probar

- **Mensual:** US$3,99.
- **Anual:** US$29,99.

Son precios de partida para validar, no valores definitivos. Probar, por
ejemplo, US$2,99 frente a US$4,99 al mes y localizar moneda y precio según el
mercado. La tarifa de transacción, impuestos, comisiones de las tiendas y
costos de infraestructura deben incluirse en el cálculo de margen. No añadir
un plan semanal o varios niveles hasta contar con datos que justifiquen esa
complejidad.

## Módulo administrativo en el panel web

El panel ya organiza sus secciones mediante una barra lateral y una pestaña
activa compartida:

- Navegación: `lib/web/presentation/screens/parts/admin_shell.part.dart`
- Estado de navegación: `lib/web/presentation/providers/admin_dashboard_provider.dart`
- Consultas administrativas: `lib/web/data/services/admin_service.dart`

Agregar una sección **Suscripciones** con estas capacidades:

### Resumen

- Suscripciones activas y nuevas.
- Ingreso recurrente estimado (MRR), indicando si es bruto o neto.
- Cancelaciones, renovaciones próximas y pagos fallidos.
- Conversión de prueba a pago, si en el futuro se ofrece una prueba.
- Desglose por canal de compra: web, App Store o Google Play.

### Listado y detalle

- Buscar por correo o usuario y filtrar por plan, estado, canal y fechas.
- Mostrar proveedor, moneda, importe, fecha de inicio, próxima renovación o
  vencimiento, y si la cancelación es inmediata o al final del período.
- Consultar historial de eventos de facturación y pagos.
- Distinguir acceso activo de pago pendiente, período de gracia, cancelación,
  vencimiento y reembolso.

### Acciones administrativas

- Conceder acceso promocional por tiempo limitado, con motivo y auditoría.
- Enlazar a las herramientas del proveedor para operaciones de cobro,
  reembolso o cancelación que correspondan.
- No cambiar manualmente el estado de un pago a “pagado” ni activar una
  suscripción sin registrar quién hizo la acción, cuándo y por qué.

La sección administrativa sirve para supervisar el ciclo de vida; no debe
capturar ni almacenar datos de tarjetas.

## Arquitectura recomendada

### Proveedor de pagos

- Usar checkout alojado por un proveedor para los cobros web.
- Stripe puede ser una opción si está disponible para la entidad y el país del
  negocio. Un *Merchant of Record* como Paddle puede simplificar ciertos
  aspectos de impuestos y cumplimiento internacional, a cambio de una tarifa
  por transacción mayor.
- Elegir el proveedor después de confirmar países admitidos, métodos de pago,
  moneda, costos, soporte de suscripciones, reembolsos, impuestos y requisitos
  legales.
- No guardar números de tarjeta ni códigos de seguridad en Supabase.

### Compras desde aplicaciones móviles

Para vender funciones digitales dentro de las aplicaciones, seguir las reglas
vigentes de Apple y Google. Las compras en la tienda y las compras web pueden
tener flujos y comisiones diferentes. Permitir que una persona inicie sesión en
la aplicación con una suscripción comprada en otro canal no significa que se
puedan añadir enlaces de compra externos sin revisar las reglas aplicables.
Confirmar las políticas, excepciones regionales y programas antes de habilitar
esos enlaces.

### Backend y acceso

1. Crear la sesión de checkout desde una función segura del servidor, no desde
   lógica de cliente que permita elegir precios o usuarios arbitrarios.
2. Procesar eventos de pago mediante webhooks con firma verificada.
3. Hacer idempotente el procesamiento para que un evento repetido no duplique
   cargos, registros ni permisos.
4. Actualizar el acceso Premium a partir de eventos confirmados del proveedor,
   no de un valor que el cliente pueda editar.
5. Mantener el proveedor como fuente de verdad para cobros y el backend como
   fuente de verdad para los permisos dentro de la aplicación.
6. Aplicar autorización en base de datos y Storage. Ocultar botones en la app
   no basta para imponer cuotas.
7. Registrar errores y eventos de facturación para permitir soporte y
   conciliación.

### Entidades de datos conceptuales

- **Planes:** identificador interno, nombre, límites y referencias de precio
  del proveedor.
- **Suscripciones:** usuario, proveedor, identificadores externos, estado,
  canal, inicio, fin del período vigente y marca de cancelación.
- **Eventos de facturación:** identificador único del proveedor, tipo de
  evento, estado, importe, moneda y fechas necesarias para auditarlo.
- **Acceso o entitlements:** permiso actual para usar funciones Premium,
  derivado de una suscripción válida o de una concesión promocional vigente.
- **Uso y cuota:** consumo de almacenamiento o capturas asociado a la cuenta,
  aplicado también en el backend.

Usar políticas RLS para proteger los datos. Las claves secretas y las claves
con privilegios administrativos deben residir solo en el servidor.

## Reglas de producto y soporte

- Explicar precio, moneda, intervalo, renovación automática y cómo cancelar
  antes de confirmar la compra.
- La cancelación debe detener renovaciones futuras y mantener el acceso hasta
  el fin del período pagado, salvo que la normativa o el proveedor requieran
  otro tratamiento.
- Definir manejo de pagos fallidos, período de gracia, reembolsos, facturas,
  eliminación de cuenta y tratamiento de datos e imágenes.
- Al cancelar o vencer, decidir con claridad qué pasa con las detecciones:
  conservar el acceso de solo lectura, permitir exportar o aplicar una política
  de retención informada; no borrar datos inesperadamente.
- Añadir auditoría a los accesos promocionales y a cualquier acción manual.

## Etapas de implementación

### Etapa 1 — Definir la oferta

- Confirmar mercados, moneda y proveedor de pagos.
- Acordar límites de almacenamiento, capturas gratuitas y Premium.
- Validar que el valor Premium sea claro y sostenible con los costos reales.
- Redactar políticas de renovación, cancelación, reembolso y retención.

### Etapa 2 — Backend de facturación

- Crear modelo de datos y políticas RLS.
- Implementar checkout, webhooks firmados e idempotentes, y sincronización de
  permisos.
- Implementar cuotas de imágenes y detecciones en el backend.
- Probar renovaciones, cancelaciones, pagos fallidos, reembolsos y eventos
  repetidos en modo de prueba.

### Etapa 3 — Panel administrativo

- Añadir la sección Suscripciones a la navegación.
- Crear resumen, listado, filtros, detalle y auditoría.
- Integrar enlaces al portal y al panel del proveedor para operaciones que no
  deban ejecutarse directamente desde el panel propio.

### Etapa 4 — Lanzamiento y medición

- Lanzar con una sola suscripción Premium.
- Medir conversión, retención, cancelaciones, pagos fallidos, uso de
  almacenamiento y margen neto por canal.
- Ajustar cuotas y precios con datos; revisar trimestralmente el costo por
  usuario activo y por suscriptor.

## Referencias oficiales

- [Supabase — precios y límites](https://supabase.com/pricing)
- [Supabase — webhooks firmados de Stripe](https://supabase.com/docs/guides/functions/examples/stripe-webhooks)
- [Stripe Billing — precios](https://stripe.com/billing/pricing)
- [Paddle — precios](https://www.paddle.com/pricing)
- [Apple — suscripciones](https://developer.apple.com/app-store/subscriptions/)
- [Apple — compras dentro de la aplicación](https://developer.apple.com/design/human-interface-guidelines/apple-in-app-purchase)
- [Google Play — política de pagos](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en)


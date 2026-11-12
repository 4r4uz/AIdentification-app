# AnimalPedia - Mejoras y Documentacion Tecnica 
 
## Resumen de Hallazgos y Mejoras Sugeridas 
Este documento describe todos los problemas encontrados durante el analisis del proyecto, sus impactos, propuestas de solucion y documentacion de las funciones principales para mantener el codigo escalable y mantenible. 
## Problemas Encontrados (en orden de prioridad) 
 
 
### 1. Servicios duplicados por pantalla (ALTA) - RESUELTO
Las pantallas usan `ServiceLocator` para compartir `AuthService`, `ProfileService`,
`SpeciesService`, `DetectionService` y `TriviaService`. Las instancias se crean
una sola vez dentro del localizador.

### 2. Consulta `.single()` en la lectura del perfil (ALTA) - RESUELTO
`AuthService.getCurrentUserProfile()` usa `.maybeSingle()` y devuelve `null` si
el perfil no existe. Las consultas de insercion que esperan exactamente una fila
conservan `.single()`.

### 3. Timeout sin manejo especifico de excepciones (MEDIA) - RESUELTO
`SpeciesService.getAllSpeciesFacts()` captura `TimeoutException`, registra el
detalle y lanza un mensaje especifico de tiempo de espera agotado.

### 4. Consultas secuenciales en la galeria (MEDIA) - RESUELTO
`GalleryScreen` ejecuta en paralelo la consulta de especies y, cuando hay un
usuario autenticado, la de especies descubiertas. Comprueba que la sesion no haya
cambiado antes de publicar los resultados.

### 5. Limpieza de archivos temporales de camara (MEDIA) - RESUELTO
`CameraWidget` elimina el archivo comprimido al terminar el callback, incluso si
el procesamiento falla, y tambien intenta limpiarlo si falla la escritura. Los
errores de limpieza se registran; la imagen original de respaldo no se elimina.

### 6. Dominio IP estatico en `app_constants` (BAJA) - RESUELTO
La URL local sin uso esta comentada y no forma parte del flujo de la aplicacion.

### 7. Multiples instancias de servicios compartidos (MEDIA) - RESUELTO
Las pantallas que usan estos servicios acceden a las mismas instancias mediante
`ServiceLocator`; no construyen instancias propias.
 
## Documentacion de Funciones Principales 
 
### AuthService (Auth Service) 
#### signUp({required String email, required String password, String? username}) 
Prop�sito: Registra un nuevo usuario en la aplicacion. 
- email: Correo electronico del usuario. 
Retorno: UserModel? - Devuelve el modelo de usuario si el registro fue exitoso. 

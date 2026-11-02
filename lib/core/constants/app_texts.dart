// Textos y mensajes reutilizables en la app
class AppTexts {
  // App
  static const String appName = 'AnimalPedia';
  static const String appTagline = 'Explora la vida silvestre';

  // Login
  static const String loginTitle = appName;
  static const String loginSubtitle = appTagline;
  static const String emailLabel = 'Email';
  static const String passwordLabel = 'Contraseña';
  static const String forgotPassword = '¿Olvidaste tu contraseña?';
  static const String loginButton = 'Iniciar Sesión';
  static const String noAccount = '¿No tienes cuenta?';
  static const String registerLink = 'Regístrate';

  // Register
  static const String registerTitle = 'Crear Cuenta';
  static const String usernameLabel = 'Nombre de usuario (opcional)';
  static const String confirmPasswordLabel = 'Confirmar contraseña';
  static const String registerButton = 'Registrarse';
  static const String registerSuccess =
      'Registro exitoso. Ahora inicia sesión.';

  // Errores
  static const String errorEmailRequired = 'Ingresa tu email';
  static const String errorEmailInvalid = 'Email inválido';
  static const String errorPasswordRequired = 'Ingresa tu contraseña';
  static const String errorPasswordMinLength = 'Mínimo 6 caracteres';
  static const String errorPasswordMismatch = 'Las contraseñas no coinciden';

  // Mensajes de éxito
  static const String successLogin = 'Inicio de sesión exitoso';
  static const String successPasswordReset =
      'Se envió un email de recuperación';
  static const String successProfileUpdate = 'Foto de perfil actualizada';

  // Diálogos
  static const String logoutTitle = 'Cerrar Sesión';
  static const String logoutMessage =
      '¿Estás seguro de que deseas cerrar sesión?';
  static const String cancelButton = 'Cancelar';
  static const String confirmButton = 'Cerrar Sesión';

  // Profile
  static const String profileTitle = 'Perfil';
  static const String changePhotoButton = 'Cambiar Foto de Perfil';
  static const String uploadingPhoto = 'Subiendo...';
  static const String statisticsTitle = 'Estadísticas';

  // Species
  static const String speciesGalleryTitle = 'Galería de Especies';
  static const String noSpeciesFound = 'No se encontraron especies';

  // Trivia
  static const String triviaTitle = 'Trivia';
  static const String triviaCompleted = '¡Trivia Completada!';
  static const String playAgainButton = 'Jugar de nuevo';
  static const String loadingTrivia = 'Cargando trivia...';
  static const String noTriviaAvailable = 'No hay trivias disponibles';
  static const String retryButton = 'Reintentar';

  // Camera
  static const String cameraTitle = 'Cámara';
}

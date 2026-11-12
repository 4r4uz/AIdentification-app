import '/features/auth/data/services/auth_service.dart';
import '/features/profile/data/services/profile_service.dart';
import '/features/gallery/data/services/species_service.dart';
import '/features/camera/data/services/detection_service.dart';
import '/features/trivia/data/services/trivia_service.dart';

/// ServiceLocator para compartir servicios singleton en toda la aplicación.
///
/// Evita que cada pantalla instancie sus propios servicios, garantizando
/// un estado global consistente y reduciendo el uso de memoria.
///
/// Uso:
///   final authService = ServiceLocator.auth;
///   final speciesService = ServiceLocator.species;
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final SpeciesService _speciesService = SpeciesService();
  final DetectionService _detectionService = DetectionService();
  final TriviaService _triviaService = TriviaService();

  static AuthService get auth => _instance._authService;
  static ProfileService get profile => _instance._profileService;
  static SpeciesService get species => _instance._speciesService;
  static DetectionService get detection => _instance._detectionService;
  static TriviaService get trivia => _instance._triviaService;
}
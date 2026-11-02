import 'package:flutter/foundation.dart';

class ProfileRefreshNotifier {
  ProfileRefreshNotifier._();

  static final ValueNotifier<int> detectionSaved = ValueNotifier<int>(0);

  static void notifyDetectionSaved() {
    detectionSaved.value++;
  }
}

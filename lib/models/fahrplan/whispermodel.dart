import 'package:whisper_ggml/whisper_ggml.dart';

class FahrplanWhisperModel {
  String name;

  static List<String> models = [
    'tiny',
    'base',
    'small',
    'medium',
    'large',
  ];

  FahrplanWhisperModel(this.name);

  get model {
    switch (name) {
      case 'tiny':
        return WhisperModel.tiny;
      case 'base':
        return WhisperModel.base;
      case 'small':
        return WhisperModel.small;
      case 'medium':
        return WhisperModel.medium;
      case 'large':
        return WhisperModel.large;
      default:
        return WhisperModel.base;
    }
  }
}

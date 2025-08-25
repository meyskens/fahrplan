import 'package:whisper_ggml/whisper_ggml.dart';

class FahrplanWhisperModel {
  String name;

  static List<String> models = [
    'tiny',
    'tiny.en',
    'base',
    'base.en',
    'small',
    'small.en',
    'medium',
    'large',
  ];

  FahrplanWhisperModel(this.name);

  get model {
    switch (name) {
      case 'tiny':
        return WhisperModel.tiny;
      case 'tiny.en':
        return WhisperModel.tinyEn;
      case 'base':
        return WhisperModel.base;
      case 'base.en':
        return WhisperModel.baseEn;
      case 'small':
        return WhisperModel.small;
      case 'small.en':
        return WhisperModel.smallEn;
      case 'medium':
        return WhisperModel.medium;
      case 'large':
        return WhisperModel.large;
      default:
        return WhisperModel.base;
    }
  }
}

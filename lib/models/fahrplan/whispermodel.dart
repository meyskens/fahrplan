import 'package:whisper_flutter_new/whisper_flutter_new.dart';

class FahrplanWhisperModel {
  String name;

  static List<String> models = [
    'tiny',
    'base',
    'small',
    'medium',
    'large-v1',
    'large-v2'
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
      case 'large-v1':
        return WhisperModel.largeV1;
      case 'large-v2':
        return WhisperModel.largeV2;
      default:
        return WhisperModel.base;
    }
  }
}

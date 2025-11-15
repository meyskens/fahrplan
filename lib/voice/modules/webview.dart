import 'package:fahrplan/models/fahrplan/webview.dart';
import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:fahrplan/voice/module.dart';

String _removeTriggers(String transcription, List<String> triggers) {
  for (var trigger in triggers) {
    transcription = transcription
        .toLowerCase()
        .replaceFirst(trigger, "")
        .replaceAll(".", "")
        .trim();
  }
  return transcription;
}

class WebView extends VoiceModule {
  @override
  String get name => "WebView";

  @override
  List<VoiceCommand> get commands {
    return [
      OpenWebView(),
      CloseWebView(),
    ];
  }
}

class OpenWebView extends VoiceCommand {
  @override
  String get command => "Open web view";

  @override
  List<String> get triggerPhrases => [
        "open web view",
        "open webview",
        "show web view",
        "show webview",
      ];

  @override
  Future<void> execute(String inputText) async {
    final webViewName = _removeTriggers(inputText, triggerPhrases);
    final webView = FahrplanWebView.displayWebViewFor(webViewName);

    final bt = BluetoothManager();
    if (webView != null) {
      bt.sync();
    } else {
      bt.sendText('No web view found for "$webViewName"');
    }

    await super.endCommand();
  }
}

class CloseWebView extends VoiceCommand {
  @override
  String get command => "Close web view";

  @override
  List<String> get triggerPhrases => [
        "close web view",
        "close webview",
        "closed web view",
        "closed webview",
        "hide web view",
        "hide webview",
      ];

  @override
  Future<void> execute(String inputText) async {
    final webViewName = _removeTriggers(inputText, triggerPhrases);
    final webView = FahrplanWebView.hideWebViewFor(webViewName);

    final bt = BluetoothManager();
    if (webView != null) {
      bt.sync();
    } else {
      bt.sendText('No web view found for "$webViewName"');
    }

    await super.endCommand();
  }
}

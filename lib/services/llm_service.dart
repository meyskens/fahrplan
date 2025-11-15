import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LLMService {
  static Future<Map<String, String>?> _getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final apiUrl = prefs.getString('llm_api_url');
    final apiKey = prefs.getString('llm_api_key');
    final model = prefs.getString('llm_model');

    if (apiUrl == null || apiUrl.isEmpty) {
      debugPrint('LLM API URL not configured');
      return null;
    }

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('LLM API key not configured');
      return null;
    }

    if (model == null || model.isEmpty) {
      debugPrint('LLM model not configured');
      return null;
    }

    return {'apiUrl': apiUrl, 'apiKey': apiKey, 'model': model};
  }

  static String? _parseResponse(
      Map<String, dynamic> jsonResponse, String responseBody) {
    try {
      if (jsonResponse['choices'] != null &&
          jsonResponse['choices'].isNotEmpty) {
        final message = jsonResponse['choices'][0]['message'];
        if (message != null) {
          final messageContent = message['content'];
          if (messageContent is String) {
            return messageContent.trim();
          } else if (messageContent is List && messageContent.isNotEmpty) {
            return messageContent[0]['text']?.toString().trim();
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing LLM response: $e');
      debugPrint('Response body: $responseBody');
    }
    return null;
  }

  static Future<String?> _callLLM({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.1,
    int maxTokens = 400,
  }) async {
    final config = await _getConfig();
    if (config == null) return null;

    try {
      final endpoint = config['apiUrl']!.endsWith('/chat/completions')
          ? config['apiUrl']!
          : '${config['apiUrl']}/chat/completions';

      debugPrint('Sending LLM request to $endpoint');

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${config['apiKey']}',
            },
            body: jsonEncode({
              'model': config['model'],
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': userPrompt},
              ],
              'temperature': temperature,
              'max_tokens': maxTokens,
            }),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('LLM API error: ${response.statusCode} - ${response.body}');
        return null;
      }

      return _parseResponse(jsonDecode(response.body), response.body);
    } catch (e) {
      debugPrint('Error calling LLM service: $e');
      return null;
    }
  }

  static Future<String?> matchCommand(
      String transcription, List<String> availableCommands) async {
    String commandList = "";
    for (var i = 0; i < availableCommands.length; i++) {
      commandList += "$i: ${availableCommands[i]}\n";
    }

    final prompt = '''The user said: "$transcription"

Available commands:
$commandList
''';

    const systemPrompt =
        'You are a voice assistant only returning the number of the best matching query. Only respond with exact command number or NO_MATCH.';

    final content = await _callLLM(
      systemPrompt: systemPrompt,
      userPrompt: prompt,
      temperature: 0.1,
      maxTokens: 400,
    );

    if (content != null && content.isNotEmpty && content != 'NO_MATCH') {
      debugPrint('LLM matched command: $content');
      final commandNumber = content.replaceAll(RegExp(r'\D'), '');
      final index = int.tryParse(commandNumber);
      if (index != null && index >= 0 && index < availableCommands.length) {
        return availableCommands[index];
      } else {
        debugPrint('LLM returned invalid command index: $commandNumber');
        return null;
      }
    } else {
      debugPrint('LLM found no match');
      return null;
    }
  }

  static Future<String?> summaryGen(String transcription) async {
    final prompt = 'The user said: "$transcription"';

    const systemPrompt =
        'You are a summary generator for a waypoint generator. Summarize the user input concisely, limit your output to maximum 20 characters, never more than the input length. Leave out (relative) time and remove the "add waypoint" command trigger. No punctuation. Never use waypoint.';

    final content = await _callLLM(
      systemPrompt: systemPrompt,
      userPrompt: prompt,
      temperature: 0.1,
      maxTokens: 1000,
    );
Other
    if (content != null && content.isNotEmpty) {
      debugPrint('LLM summary: $content');
      return content;
    } else {
      debugPrint('LLM returned empty summary');
      return null;
    }
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LLMService {
  static Future<String?> matchCommand(
      String transcription, List<String> availableCommands) async {
    final prefs = await SharedPreferences.getInstance();
    final apiUrl = prefs.getString('llm_api_url');
    final apiKey = prefs.getString('llm_api_key');
    final model = prefs.getString('llm_model');

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('LLM API key not configured');
      return null;
    }

    if (model == null || model.isEmpty) {
      debugPrint('LLM model not configured');
      return null;
    }

    try {
      String commandList = "";
      for (var i = 0; i < availableCommands.length; i++) {
        commandList += "$i: ${availableCommands[i]}\n";
      }
      final prompt = '''The user said: "$transcription"

Available commands:
$commandList
''';

      // Use OpenAI API endpoint by default
      final baseUrl =
          apiUrl?.isNotEmpty == true ? apiUrl! : 'https://api.openai.com/v1';
      final endpoint = baseUrl.endsWith('/chat/completions')
          ? baseUrl
          : '$baseUrl/chat/completions';

      debugPrint('Sending LLM request to $endpoint');

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a voice assistant only returning the number of the best matching query. Only respond with exact command number or NO_MATCH.',
                },
                {
                  'role': 'user',
                  'content': prompt,
                },
              ],
              'temperature': 0.1,
              'max_tokens': 50,
            }),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('LLM API error: ${response.statusCode} - ${response.body}');
        return null;
      }

      final jsonResponse = jsonDecode(response.body);
      String? content;

      // Parse the response - handle different API formats
      try {
        if (jsonResponse['choices'] != null &&
            jsonResponse['choices'].isNotEmpty) {
          final message = jsonResponse['choices'][0]['message'];
          if (message != null) {
            // Handle both string and structured content
            final messageContent = message['content'];
            if (messageContent is String) {
              content = messageContent.trim();
            } else if (messageContent is List && messageContent.isNotEmpty) {
              // Handle structured content format
              content = messageContent[0]['text']?.toString().trim();
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing LLM response: $e');
        debugPrint('Response body: ${response.body}');
        return null;
      }

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
    } catch (e) {
      debugPrint('Error calling LLM service: $e');
      return null;
    }
  }
}

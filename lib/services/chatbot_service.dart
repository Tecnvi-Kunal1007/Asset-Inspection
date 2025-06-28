import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatbotService {
  final String _apiKey;
  final String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  ChatbotService() : _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  // Add a general chat method
  Future<String> getChatResponse(String message, String systemPrompt) async {
    if (_apiKey.isEmpty) {
      throw Exception('OpenAI API key not found. Please check your .env file.');
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': message},
          ],
          'temperature': 0.7,
          'max_tokens': 300,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        print('Error from OpenAI API: ${response.body}');
        return 'I encountered an error processing your request. Please try again.';
      }
    } catch (e) {
      print('Error calling OpenAI API: $e');
      return 'I encountered an error processing your request. Please try again.';
    }
  }

  // Add a streaming chat response method
  Stream<String> streamChatResponse(String message, String systemPrompt) async* {
    if (_apiKey.isEmpty) {
      yield 'Error: OpenAI API key not found. Please check your .env file.';
      return;
    }

    try {
      final request = http.Request('POST', Uri.parse(_baseUrl));

      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      });

      request.body = jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': message},
        ],
        'stream': true,
      });

      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        yield 'Error: Failed to connect to OpenAI (${response.statusCode})';
        return;
      }

      await for (final chunk in response.stream) {
        final decodedChunk = utf8.decode(chunk);
        for (final line in decodedChunk.split('\n')) {
          if (line.startsWith('data: ') && line != 'data: [DONE]') {
            try {
              final data = line.substring(6);
              if (data.trim().isNotEmpty) {
                final jsonData = jsonDecode(data);
                final content = jsonData['choices'][0]['delta']['content'];
                if (content != null) {
                  yield content;
                }
              }
            } catch (e) {
              // Skip malformed lines
            }
          }
        }
      }
    } catch (e) {
      yield 'Error communicating with OpenAI: $e';
    }
  }
}

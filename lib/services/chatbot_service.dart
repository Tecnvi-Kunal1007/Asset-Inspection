import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/pump.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math' as num;

class ChatbotService {
  final String _apiKey;
  final String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  final List<String> _fieldsToUpdate = [
    'status',
    'mode',
    'start_pressure',
    'stop_pressure',
    'suction_valve',
    'delivery_valve',
    'pressure_gauge',
  ];

  ChatbotService() : _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  Future<Map<String, dynamic>> processUserMessage(
    String message,
    Pump pump,
  ) async {
    if (_apiKey.isEmpty) {
      throw Exception('OpenAI API key not found. Please check your .env file.');
    }

    // Create a map of current values and their update status
    final fieldStatus = {
      'status': {'value': pump.status, 'updated': false},
      'mode': {'value': pump.mode, 'updated': false},
      'start_pressure': {'value': pump.startPressure, 'updated': false},
      'stop_pressure': {'value': pump.stopPressure, 'updated': false},
      'suction_valve': {'value': pump.suctionValve, 'updated': false},
      'delivery_valve': {'value': pump.deliveryValve, 'updated': false},
      'pressure_gauge': {'value': pump.pressureGauge, 'updated': false},
      'capacity': {'value': pump.capacity, 'updated': false},
      'head': {'value': pump.head, 'updated': false},
      'rated_power': {'value': pump.ratedPower, 'updated': false},
    };

    final prompt = '''
You are a pump management assistant. Your role is to help update pump information through natural conversation.
Current pump details:
- Name: ${pump.name}
- Status: ${pump.status}
- Mode: ${pump.mode}
- Capacity: ${pump.capacity} LPM
- Head: ${pump.head} meters
- Rated Power: ${pump.ratedPower} kW
- Start Pressure: ${pump.startPressure} kg/cm²
- Stop Pressure: ${pump.stopPressure} kg/cm²
- Suction Valve: ${pump.suctionValve}
- Delivery Valve: ${pump.deliveryValve}
- Pressure Gauge: ${pump.pressureGauge}

The user has sent the following message: "$message"

Please analyze the message and determine if it contains any updates to the pump's settings.
You can update multiple fields at once.

Format your response as a JSON object with the following structure:
{
  "updates": {
    "field_name": "new_value",
    ...
  },
  "message": "Confirmation message of what was updated",
  "follow_up": "Ask about a specific field that hasn't been updated yet, mentioning its current value"
}

Valid options for fields:
- status: "Working" or "Not Working"
- mode: "Auto" or "Manual"
- capacity: numeric value (in LPM, must be a whole number)
- head: numeric value (in meters, must be a whole number)
- rated_power: numeric value (in kW, must be a whole number)
- start_pressure: numeric value (in kg/cm², can be decimal)
- stop_pressure: text value (e.g. "2.5 kg/cm²")
- suction_valve: "Open" or "Closed"
- delivery_valve: "Open" or "Closed"
- pressure_gauge: "Working" or "Not Working"

If no updates are detected, ask for clarification and suggest what can be updated.
''';

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
            {'role': 'system', 'content': prompt},
            {'role': 'user', 'content': message},
          ],
          'temperature': 0.7,
          'max_tokens': 300,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result =
            jsonDecode(data['choices'][0]['message']['content'])
                as Map<String, dynamic>;

        // Mark which fields were updated
        if (result['updates'] != null) {
          final updates = result['updates'] as Map<String, dynamic>;
          for (final entry in updates.entries) {
            if (fieldStatus.containsKey(entry.key)) {
              fieldStatus[entry.key]!['updated'] = true;
            }
          }
        }

        // Generate follow-up question for the first non-updated field
        if (result['updates'] != null) {
          final nonUpdatedFields =
              fieldStatus.entries
                  .where((entry) => !(entry.value['updated'] as bool))
                  .toList();

          if (nonUpdatedFields.isNotEmpty) {
            final nextField = nonUpdatedFields.first;
            String fieldName = nextField.key;
            dynamic fieldValue =
                (nextField.value as Map<String, dynamic>)['value'];
            String currentValue = fieldValue.toString();

            String followUp = 'Would you like to update the $fieldName? ';
            followUp += 'It is currently set to $currentValue';
            if (fieldName.contains('pressure')) {
              followUp += ' kg/cm²';
            }
            followUp += '.';

            result['follow_up'] = followUp;
          }
        }

        return result;
      } else {
        print('Error from OpenAI API: ${response.body}');
        return {
          'updates': null,
          'message':
              'I encountered an error processing your request. Please try again.',
          'follow_up':
              'You can try updating any of these fields: ${_fieldsToUpdate.join(", ")}',
        };
      }
    } catch (e) {
      print('Error calling OpenAI API: $e');
      return {
        'updates': null,
        'message':
            'I encountered an error processing your request. Please try again.',
        'follow_up':
            'You can try updating any of these fields: ${_fieldsToUpdate.join(", ")}',
      };
    }
  }

  Future<Pump> updatePumpFromMessage(String message, Pump pump) async {
    try {
      final result = await processUserMessage(message, pump);
      print('Processed message result: $result');

      if (result['updates'] != null) {
        final updates = result['updates'] as Map<String, dynamic>;
        Map<String, dynamic> validUpdates = {};

        // Validate and convert numeric values
        if (updates.containsKey('capacity')) {
          final value = int.tryParse(updates['capacity'].toString());
          if (value != null && value >= 0) {
            validUpdates['capacity'] = value;
          }
        }

        if (updates.containsKey('head')) {
          final value = int.tryParse(updates['head'].toString());
          if (value != null && value >= 0) {
            validUpdates['head'] = value;
          }
        }

        if (updates.containsKey('rated_power')) {
          final value = int.tryParse(updates['rated_power'].toString());
          if (value != null && value >= 0) {
            validUpdates['rated_power'] = value;
          }
        }

        if (updates.containsKey('start_pressure')) {
          try {
            final rawValue = updates['start_pressure']!;
            final pressure = double.tryParse(rawValue.toString());
            if (pressure != null && pressure >= 0) {
              validUpdates['start_pressure'] = pressure;
            } else {
              print('Invalid start pressure value: $rawValue');
            }
          } catch (e) {
            print('Error parsing start pressure: $e');
          }
        }

        if (updates.containsKey('stop_pressure')) {
          validUpdates['stop_pressure'] = updates['stop_pressure'];
        }

        // Add non-numeric fields
        for (final key in [
          'status',
          'mode',
          'suction_valve',
          'delivery_valve',
          'pressure_gauge',
        ]) {
          if (updates.containsKey(key)) {
            validUpdates[key] = updates[key];
          }
        }

        // Create a new pump with updated values
        final updatedPump = pump.copyWith(
          status: validUpdates['status'] as String?,
          mode: validUpdates['mode'] as String?,
          capacity: validUpdates['capacity'] as int?,
          head: validUpdates['head'] as int?,
          ratedPower: validUpdates['rated_power'] as int?,
          startPressure: validUpdates['start_pressure'] as double?,
          stopPressure: validUpdates['stop_pressure'] as String?,
          suctionValve: validUpdates['suction_valve'] as String?,
          deliveryValve: validUpdates['delivery_valve'] as String?,
          pressureGauge: validUpdates['pressure_gauge'] as String?,
        );

        print('Updated pump: ${updatedPump.toJson()}');
        return updatedPump;
      }

      return pump;
    } catch (e) {
      print('Error updating pump from message: $e');
      return pump;
    }
  }

  // Add a new method to handle streaming responses if needed in the future
  Stream<String> streamChatResponse(String message, Pump pump) async* {
    if (_apiKey.isEmpty) {
      yield 'Error: OpenAI API key not found. Please check your .env file.';
      return;
    }

    final prompt = '''
You are a helpful assistant for managing pumps. The current pump is ${pump.name}.
Current settings:
- Status: ${pump.status}
- Mode: ${pump.mode}
- Start Pressure: ${pump.startPressure} kg/cm²
- Stop Pressure: ${pump.stopPressure} kg/cm²
- Suction Valve: ${pump.suctionValve}
- Delivery Valve: ${pump.deliveryValve}
- Pressure Gauge: ${pump.pressureGauge}

Please respond naturally to the user's message: "$message"
''';

    try {
      final request = http.Request('POST', Uri.parse(_baseUrl));

      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      });

      request.body = jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'system', 'content': prompt},
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

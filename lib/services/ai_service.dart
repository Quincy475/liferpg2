import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:household_rpg/data/models/enums.dart';
import 'package:household_rpg/data/models/task_mvp.dart';
import 'package:household_rpg/data/models/task_suggestion.dart';

// 🔑 Voeg hier je Anthropic API key in zodra je er een hebt.
//    Je kunt deze aanvragen op: https://console.anthropic.com
const String _kAnthropicApiKey = '';

const String _kSystemPrompt = '''
Je bent een slimme taak-planner voor een persoonlijke RPG-app. De gebruiker vertelt je in gewone taal welke taken ze willen doen en wanneer. Jij vertaalt dit naar een gestructureerde JSON-lijst.

BESCHIKBARE SKILL TYPES (kies altijd de best passende):
- cooking: koken, boodschappen, maaltijden, recepten
- cleaning: schoonmaken, opruimen, stofzuigen, dweilen, badkamer, keuken schoonmaken
- fixing: repareren, klussen, onderhoud, schilderen, technische problemen
- laundry: was doen, kleding wassen, strijken, drogen
- admin: administratie, rekeningen, e-mails, papierwerk, belastingen, agenda

SCHEDULE TYPES:
- daily: elke dag herhalen
- weekly: elke week herhalen (zelfde weekdag als scheduledDate)
- monthly: elke maand herhalen
- everyXDays: elke X dagen herhalen, geef intervalValue op
- custom: eenmalig op een specifieke datum, ALTIJD scheduledDate invullen

DATUMREGELS (gebruik de "vandaag" datum die je meekrijgt):
- "morgen" = vandaag + 1 dag
- "overmorgen" = vandaag + 2 dagen
- "aankomende [weekdag]" = eerstvolgende die weekdag
- "volgende week" = maandag van volgende week
- Geef scheduledDate ALTIJD in formaat: "YYYY-MM-DDTHH:MM:SS"

OUTPUT: Geef ALLEEN geldige JSON terug, geen markdown, geen uitleg, alleen JSON.
{
  "tasks": [
    {
      "title": "Kort, duidelijk taaknaam",
      "description": "Optionele extra info",
      "skill": "cooking",
      "scheduleType": "custom",
      "scheduledDate": "2024-01-15T20:00:00",
      "dueHour": 20,
      "coinsBase": 5,
      "intervalValue": 1
    }
  ],
  "message": "Vriendelijk berichtje aan de gebruiker (zelfde taal als gebruiker)"
}
''';

class AiService {
  final http.Client _client;

  AiService({http.Client? client}) : _client = client ?? http.Client();

  Future<AiResponse> parseTasks({
    required String userMessage,
    required DateTime today,
  }) async {
    if (_kAnthropicApiKey.isEmpty) {
      return AiResponse(
        suggestions: [],
        message:
            'Geen API key gevonden. Open lib/services/ai_service.dart en vul je Anthropic API key in bij _kAnthropicApiKey.',
      );
    }

    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    try {
      final response = await _client.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _kAnthropicApiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 1024,
          'system': _kSystemPrompt,
          'messages': [
            {
              'role': 'user',
              'content': 'Vandaag is $dateStr.\n\n$userMessage',
            }
          ],
        }),
      );

      if (response.statusCode != 200) {
        final err = jsonDecode(response.body);
        final msg = (err['error']?['message'] as String?) ?? 'Onbekende fout';
        return AiResponse(suggestions: [], message: 'API fout: $msg');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final contentList = body['content'] as List;
      final text = (contentList.first as Map<String, dynamic>)['text'] as String;

      final parsed = jsonDecode(text) as Map<String, dynamic>;
      final tasksRaw = (parsed['tasks'] as List?) ?? [];
      final message = (parsed['message'] as String?) ?? 'Hier zijn de taken die ik heb gevonden:';

      final suggestions = tasksRaw
          .map((t) => _parseSuggestion(t as Map<String, dynamic>))
          .whereType<TaskSuggestion>()
          .toList();

      return AiResponse(suggestions: suggestions, message: message);
    } on FormatException {
      return AiResponse(
        suggestions: [],
        message: 'De AI gaf een onverwacht antwoord. Probeer het opnieuw.',
      );
    } catch (e) {
      return AiResponse(
        suggestions: [],
        message: 'Verbindingsfout: $e',
      );
    }
  }

  TaskSuggestion? _parseSuggestion(Map<String, dynamic> m) {
    try {
      final skillStr = m['skill']?.toString() ?? 'cleaning';
      final skill = SkillType.values.firstWhere(
        (s) => s.name == skillStr,
        orElse: () => SkillType.cleaning,
      );

      final scheduleStr = m['scheduleType']?.toString() ?? 'custom';
      final scheduleType = TaskScheduleType.values.firstWhere(
        (s) => s.name == scheduleStr,
        orElse: () => TaskScheduleType.custom,
      );

      DateTime? scheduledDate;
      final rawDate = m['scheduledDate'];
      if (rawDate != null && rawDate.toString().isNotEmpty) {
        scheduledDate = DateTime.tryParse(rawDate.toString());
      }

      return TaskSuggestion(
        title: m['title']?.toString() ?? 'Taak',
        description: m['description']?.toString() ?? '',
        skill: skill,
        scheduleType: scheduleType,
        intervalValue: (m['intervalValue'] as num?)?.toInt() ?? 1,
        scheduledDate: scheduledDate,
        dueHour: (m['dueHour'] as num?)?.toInt() ?? 20,
        coinsBase: (m['coinsBase'] as num?)?.toInt() ?? 5,
      );
    } catch (_) {
      return null;
    }
  }
}

class AiResponse {
  final List<TaskSuggestion> suggestions;
  final String message;

  const AiResponse({required this.suggestions, required this.message});
}

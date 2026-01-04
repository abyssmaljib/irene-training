import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Model for quiz suggestion from AI
class QuizSuggestion {
  final String question;
  final String choiceA;
  final String choiceB;
  final String choiceC;
  final String answer;

  const QuizSuggestion({
    required this.question,
    required this.choiceA,
    required this.choiceB,
    required this.choiceC,
    required this.answer,
  });

  factory QuizSuggestion.fromJson(Map<String, dynamic> json) {
    // Handle two possible formats:
    // Format 1: {question, choiceA, choiceB, choiceC, answer}
    // Format 2: {question, options: {A, B, C}, correct_answer}

    String choiceA = '';
    String choiceB = '';
    String choiceC = '';
    String answer = 'A';

    // Check for options object format
    if (json['options'] != null && json['options'] is Map) {
      final options = json['options'] as Map<String, dynamic>;
      choiceA = options['A'] as String? ?? '';
      choiceB = options['B'] as String? ?? '';
      choiceC = options['C'] as String? ?? '';
    } else {
      // Direct format
      choiceA = json['choiceA'] as String? ?? '';
      choiceB = json['choiceB'] as String? ?? '';
      choiceC = json['choiceC'] as String? ?? '';
    }

    // Check for correct_answer or answer
    answer = json['correct_answer'] as String? ??
        json['answer'] as String? ??
        'A';

    return QuizSuggestion(
      question: json['question'] as String? ?? '',
      choiceA: choiceA,
      choiceB: choiceB,
      choiceC: choiceC,
      answer: answer,
    );
  }
}

/// Service for AI helper features using n8n webhooks
class AiHelperService {
  static const _baseUrl = 'https://n8nocr.ireneplus.app';
  static const _summarizeEndpoint =
      '/webhook/e6295ee1-aba2-447f-9ff7-472ba349facf';
  static const _quizEndpoint = '/webhook/0bd9b238-507a-4819-9b4c-88a8819e7737';

  final http.Client _client;

  AiHelperService({http.Client? client}) : _client = client ?? http.Client();

  /// Summarize text to bullet points
  /// Returns the summarized text or null if failed
  Future<String?> summarizeText(String text) async {
    if (text.trim().isEmpty) return null;

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl$_summarizeEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        // Response format: $[:].message.content
        if (jsonResponse is List && jsonResponse.isNotEmpty) {
          final firstItem = jsonResponse[0];
          if (firstItem is Map && firstItem['message'] != null) {
            return firstItem['message']['content'] as String?;
          }
        }
        // Try direct content field
        if (jsonResponse is Map && jsonResponse['content'] != null) {
          return jsonResponse['content'] as String?;
        }
        // Return raw body if parsing fails but request succeeded
        return response.body;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Generate quiz from text
  /// Returns QuizSuggestion or null if failed
  Future<QuizSuggestion?> generateQuiz(String text) async {
    if (text.trim().isEmpty) return null;

    try {
      // Add timestamp to bypass potential caching
      final requestBody = jsonEncode({
        'text': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final response = await _client
          .post(
            Uri.parse('$_baseUrl$_quizEndpoint'),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // Handle array response format (like summarize endpoint)
        if (jsonResponse is List && jsonResponse.isNotEmpty) {
          final firstItem = jsonResponse[0];
          if (firstItem is Map<String, dynamic>) {
            // Check if it has message.content (like summarize)
            if (firstItem['message'] != null &&
                firstItem['message']['content'] != null) {
              // Try to parse content as JSON
              final content = firstItem['message']['content'] as String;
              try {
                final parsed = jsonDecode(content);
                if (parsed is Map<String, dynamic>) {
                  return QuizSuggestion.fromJson(parsed);
                }
              } catch (_) {
                // Content is not JSON, try to parse quiz fields directly
              }
            }
            // Try direct quiz fields
            return QuizSuggestion.fromJson(firstItem);
          }
        }

        // Handle direct object response
        if (jsonResponse is Map<String, dynamic>) {
          return QuizSuggestion.fromJson(jsonResponse);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Quiz API error: $e');
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}

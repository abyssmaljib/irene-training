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

/// Service for AI helper features
/// ใช้ Supabase Edge Functions ทั้งหมด (เสถียรกว่า n8n)
class AiHelperService {
  // Supabase Edge Functions
  static const _supabaseBaseUrl =
      'https://amthgthvrxhlxpttioxu.supabase.co/functions/v1';
  static const _summarizeEndpoint = '/summarize-text';
  static const _quizEndpoint = '/generate-quiz';

  final http.Client _client;

  AiHelperService({http.Client? client}) : _client = client ?? http.Client();

  /// Summarize text to bullet points
  /// Returns the summarized text or null if failed
  Future<String?> summarizeText(String text) async {
    if (text.trim().isEmpty) return null;

    try {
      // เรียก Supabase Edge Function (เสถียรกว่า n8n)
      final response = await _client.post(
        Uri.parse('$_supabaseBaseUrl$_summarizeEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // Edge Function return JSON object โดยตรง: { content: "..." }
        if (jsonResponse is Map<String, dynamic>) {
          // ตรวจสอบว่ามี error หรือไม่
          if (jsonResponse['error'] != null &&
              jsonResponse['content']?.isEmpty == true) {
            debugPrint('Summarize API error: ${jsonResponse['error']}');
            return null;
          }
          return jsonResponse['content'] as String?;
        }
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

      // เรียก Supabase Edge Function (เสถียรกว่า n8n)
      final response = await _client
          .post(
            Uri.parse('$_supabaseBaseUrl$_quizEndpoint'),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // Edge Function return JSON object โดยตรง (ไม่มี array wrapper เหมือน n8n)
        // Format: { question, options: { A, B, C }, correct_answer }
        if (jsonResponse is Map<String, dynamic>) {
          // ตรวจสอบว่ามี error หรือไม่
          if (jsonResponse['error'] != null &&
              jsonResponse['question']?.isEmpty == true) {
            debugPrint('Quiz API error: ${jsonResponse['error']}');
            return null;
          }
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

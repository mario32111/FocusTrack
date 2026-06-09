import 'package:flutter/foundation.dart';
import 'api_service.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final ApiService _api = ApiService.instance;
  final String _chatUrl = 'http://192.168.1.72:8003';

  Future<Map<String, dynamic>> chat(String question) async {
    try {
      final response = await _api.postExternal(
        '$_chatUrl/agent/chat',
        {'question': question},
      );
      return response;
    } catch (e) {
      debugPrint('Error ChatService.chat: $e');
      rethrow;
    }
  }
}

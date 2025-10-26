import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../models/chat_models.dart';

/// Ejemplo de uso de la arquitectura de chat implementada
class ChatExample {
  /// Ejemplo de creación de conversación y mensajes
  static Future<void> exampleCreateConversationAndMessages() async {
    try {
      // 1. Crear una nueva conversación
      final ConversationLocal conversation =
          await ChatService.createConversation(
            title: 'Ejemplo de conversación',
            model: 'gpt-4o-mini',
          );

      debugPrint('Conversación creada: ${conversation.id}');

      // 2. Agregar mensaje del usuario
      final MessageLocal userMessage = await ChatService.createUserMessage(
        conversationId: conversation.id,
        text: 'Hola, ¿cómo estás?',
      );

      debugPrint('Mensaje de usuario creado: ${userMessage.id}');

      // 3. Agregar mensaje del asistente
      final MessageLocal
      assistantMessage = await ChatService.createAssistantMessage(
        conversationId: conversation.id,
        text:
            '¡Hola! Estoy muy bien, gracias por preguntar. ¿En qué puedo ayudarte hoy?',
      );

      debugPrint('Mensaje del asistente creado: ${assistantMessage.id}');

      // 4. Obtener todos los mensajes de la conversación
      final List<MessageLocal> messages = await ChatService.getMessages(
        conversation.id,
      );
      debugPrint('Total de mensajes en la conversación: ${messages.length}');

      // 5. Actualizar el título de la conversación
      await ChatService.updateConversationTitle(
        conversation.id,
        'Conversación actualizada',
      );

      // 6. Obtener estadísticas locales
      final Map<String, int> stats = await ChatService.getLocalStats();
      debugPrint('Estadísticas locales: $stats');
    } catch (e) {
      debugPrint('Error en el ejemplo: $e');
    }
  }

  /// Ejemplo de flujo completo con login/logout
  static Future<void> exampleLoginLogoutFlow() async {
    try {
      // 1. Crear conversación sin login (modo anónimo)
      final ConversationLocal anonConversation =
          await ChatService.createConversation(title: 'Conversación anónima');

      await ChatService.createUserMessage(
        conversationId: anonConversation.id,
        text: 'Este mensaje se creó sin login',
      );

      debugPrint('Conversación anónima creada: ${anonConversation.id}');

      // 2. Simular login (en la app real esto vendría del AuthService)
      // Nota: En la implementación real, esto se maneja automáticamente
      // cuando el usuario hace login a través de AuthService.signIn()

      // 3. Crear conversación con login
      final ConversationLocal loggedConversation =
          await ChatService.createConversation(title: 'Conversación con login');

      await ChatService.createUserMessage(
        conversationId: loggedConversation.id,
        text: 'Este mensaje se creó con login',
      );

      debugPrint('Conversación con login creada: ${loggedConversation.id}');

      // 4. Obtener todas las conversaciones
      final List<ConversationLocal> conversations =
          await ChatService.getConversations();
      debugPrint('Total de conversaciones: ${conversations.length}');

      // 5. Simular logout (en la app real esto se maneja automáticamente)
      // Nota: En la implementación real, esto se maneja automáticamente
      // cuando el usuario hace logout a través de AuthService.signOut()
    } catch (e) {
      debugPrint('Error en el ejemplo de login/logout: $e');
    }
  }

  /// Ejemplo de contexto para IA
  static Future<void> exampleContextForAI() async {
    try {
      // Crear una conversación con varios mensajes
      final ConversationLocal conversation =
          await ChatService.createConversation(
            title: 'Conversación para contexto IA',
          );

      // Agregar varios mensajes
      await ChatService.createUserMessage(
        conversationId: conversation.id,
        text: '¿Cuál es la capital de Francia?',
      );

      await ChatService.createAssistantMessage(
        conversationId: conversation.id,
        text: 'La capital de Francia es París.',
      );

      await ChatService.createUserMessage(
        conversationId: conversation.id,
        text: '¿Y cuál es la población de París?',
      );

      await ChatService.createAssistantMessage(
        conversationId: conversation.id,
        text:
            'La población de París es aproximadamente 2.1 millones de habitantes.',
      );

      // Obtener contexto para IA
      final Map<String, dynamic> context = await ChatService.getContextForAI(
        conversationId: conversation.id,
        maxMessages: 10,
      );

      debugPrint('Contexto para IA:');
      debugPrint('Conversación: ${context['conversation']}');
      debugPrint('Mensajes: ${context['messages']}');
      debugPrint('Total de mensajes: ${context['total_messages']}');
    } catch (e) {
      debugPrint('Error en el ejemplo de contexto IA: $e');
    }
  }

  /// Ejemplo de sincronización
  static Future<void> exampleSync() async {
    try {
      // Crear algunos datos locales
      final ConversationLocal conversation =
          await ChatService.createConversation(
            title: 'Conversación para sincronizar',
          );

      await ChatService.createUserMessage(
        conversationId: conversation.id,
        text: 'Mensaje para sincronizar',
      );

      // Sincronizar datos pendientes
      await ChatService.syncPendingData();

      debugPrint('Datos sincronizados exitosamente');
    } catch (e) {
      debugPrint('Error en la sincronización: $e');
    }
  }

  /// Ejecutar todos los ejemplos
  static Future<void> runAllExamples() async {
    debugPrint('=== Iniciando ejemplos de ChatService ===');

    await exampleCreateConversationAndMessages();
    await exampleLoginLogoutFlow();
    await exampleContextForAI();
    await exampleSync();

    debugPrint('=== Ejemplos completados ===');
  }
}

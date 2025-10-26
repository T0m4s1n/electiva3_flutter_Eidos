# Arquitectura de Chat Offline-First con Flutter y Supabase

Esta implementación proporciona una arquitectura robusta para aplicaciones de chat que funciona tanto online como offline, con sincronización automática cuando el usuario está conectado.

## Características Principales

- **Offline-First**: Funciona completamente sin conexión
- **Sincronización Automática**: Los datos se sincronizan automáticamente cuando el usuario hace login
- **Privacidad Estricta**: Al hacer logout se eliminan todos los datos locales
- **IDs Determinísticos**: Los IDs se generan en el cliente para evitar duplicados
- **Mensajes Inmutables**: Los mensajes se tratan como eventos inmutables
- **Contexto Inteligente**: Sistema de resúmenes para mantener contexto de IA

## Estructura del Proyecto

```
lib/
├── services/
│   ├── chat_database.dart      # Base de datos local SQLite
│   ├── sync_service.dart        # Servicio de sincronización con Supabase
│   ├── chat_service.dart        # Servicio principal de chat
│   └── auth_service.dart        # Servicio de autenticación (actualizado)
├── models/
│   └── chat_models.dart         # Modelos de datos (ConversationLocal, MessageLocal)
├── examples/
│   └── chat_example.dart        # Ejemplos de uso
└── database_schema.sql          # Esquema de Supabase
```

## Configuración

### 1. Dependencias

Las dependencias necesarias ya están configuradas en `pubspec.yaml`:

```yaml
dependencies:
  sqflite: ^2.3.0
  path_provider: ^2.1.1
  path: ^1.8.3
  uuid: ^4.2.1
  supabase_flutter: ^2.8.0
```

### 2. Base de Datos Supabase

Ejecuta el script SQL en `database_schema.sql` en tu proyecto de Supabase para crear las tablas y políticas RLS.

### 3. Variables de Entorno

Asegúrate de tener configuradas las variables de Supabase en tu archivo `.env`:

```
SUPABASE_URL=tu_url_de_supabase
SUPABASE_ANON_KEY=tu_clave_anonima
```

## Uso Básico

### Crear una Conversación

```dart
// Crear conversación sin login (modo anónimo)
final conversation = await ChatService.createConversation(
  title: 'Mi primera conversación',
  model: 'gpt-4o-mini',
);

// Crear conversación con login (se sincroniza automáticamente)
final conversation = await ChatService.createConversation(
  title: 'Conversación sincronizada',
  model: 'gpt-4o-mini',
);
```

### Agregar Mensajes

```dart
// Mensaje del usuario
await ChatService.createUserMessage(
  conversationId: conversation.id,
  text: 'Hola, ¿cómo estás?',
);

// Mensaje del asistente
await ChatService.createAssistantMessage(
  conversationId: conversation.id,
  text: '¡Hola! Estoy muy bien, gracias.',
);

// Mensaje del sistema
await ChatService.createSystemMessage(
  conversationId: conversation.id,
  text: 'Conversación iniciada',
);
```

### Obtener Datos

```dart
// Obtener todas las conversaciones
final conversations = await ChatService.getConversations();

// Obtener mensajes de una conversación
final messages = await ChatService.getMessages(conversationId);

// Obtener contexto para IA
final context = await ChatService.getContextForAI(
  conversationId: conversationId,
  maxMessages: 30,
);
```

## Flujos de Autenticación

### Login

```dart
// El login automáticamente:
// 1. Promueve conversaciones anónimas a la cuenta del usuario
// 2. Sincroniza datos locales con la nube
// 3. Descarga datos remotos
final response = await AuthService.signIn(
  email: 'usuario@ejemplo.com',
  password: 'contraseña',
);
```

### Logout

```dart
// El logout automáticamente:
// 1. Sincroniza datos pendientes
// 2. Elimina todos los datos locales
// 3. Cierra la sesión en Supabase
await AuthService.signOut();
```

## Sincronización

### Automática

La sincronización ocurre automáticamente en estos casos:
- Al hacer login
- Al hacer logout
- Al crear/modificar conversaciones y mensajes (si está logueado)

### Manual

```dart
// Sincronizar datos pendientes manualmente
await ChatService.syncPendingData();
```

## Gestión de Contexto para IA

### Obtener Contexto

```dart
final context = await ChatService.getContextForAI(
  conversationId: conversationId,
  maxMessages: 30, // Últimos 30 mensajes
);

// El contexto incluye:
// - Información de la conversación
// - Resumen acumulativo (si existe)
// - Últimos N mensajes
// - Total de mensajes
```

### Actualizar Resumen

```dart
await ChatService.updateConversationSummary(
  conversationId: conversationId,
  summary: 'Resumen de la conversación...',
);
```

## Estadísticas y Debugging

```dart
// Obtener estadísticas locales
final stats = await ChatService.getLocalStats();
print('Conversaciones: ${stats['conversations']}');
print('Mensajes: ${stats['messages']}');
print('Mensajes pendientes: ${stats['pending_messages']}');

// Limpiar datos locales (útil para testing)
await ChatService.clearLocalData();
```

## Ejemplos Completos

Ver `lib/examples/chat_example.dart` para ejemplos detallados de uso.

## Características Avanzadas

### Mensajes de Herramientas

```dart
await ChatService.createToolMessage(
  conversationId: conversationId,
  toolName: 'weather_api',
  toolInput: {'city': 'Madrid'},
  toolOutput: {'temperature': '22°C', 'condition': 'sunny'},
);
```

### Gestión de Conversaciones

```dart
// Actualizar título
await ChatService.updateConversationTitle(conversationId, 'Nuevo título');

// Archivar/desarchivar
await ChatService.toggleConversationArchive(conversationId, true);

// Eliminar conversación
await ChatService.deleteConversation(conversationId);
```

### Soft Delete de Mensajes

```dart
// Marcar mensaje como eliminado (no se elimina físicamente)
await ChatService.deleteMessage(messageId);
```

## Consideraciones de Rendimiento

- Los mensajes se sincronizan en lotes de 500 para evitar payloads grandes
- La base de datos local usa índices optimizados para consultas rápidas
- Los resúmenes se mantienen para reducir el contexto enviado a la IA

## Seguridad

- RLS (Row Level Security) en Supabase asegura que los usuarios solo accedan a sus datos
- Los datos locales se eliminan completamente al hacer logout
- Los IDs se generan en el cliente para evitar duplicados en sincronización

## Troubleshooting

### Problemas de Sincronización

```dart
// Verificar estado de sincronización
final stats = await ChatService.getLocalStats();
if (stats['pending_messages'] > 0) {
  await ChatService.syncPendingData();
}
```

### Limpiar Datos Corruptos

```dart
// En caso de problemas, limpiar y empezar de nuevo
await ChatService.clearLocalData();
```

Esta arquitectura proporciona una base sólida para aplicaciones de chat robustas que funcionan tanto online como offline, con sincronización automática y privacidad garantizada.

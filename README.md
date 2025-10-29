# Eidos - Chat App with Flutter and Supabase

An intelligent chat application built with Flutter, Supabase, and OpenAI that works online and offline with automatic sync.

## 🚀 Features

- **Smooth login**: In-place verification on the login screen; the button shows a spinner and inline error messages
- **Configurable models**: Functional selector in Preferences with `gpt-4o-mini (current)`, `gpt-4o`, and `gpt-5`
- **Intelligent chat**: OpenAI integration; uses the selected model at runtime
- **Automatic sync**: Data syncs when online (Supabase)
- **Strict privacy**: Complete local cleanup on logout
- **Modern UI**: Clean design, Lottie animations, and animated backgrounds
- **Conversation management**: Create, load, and persist conversations and messages

## 📋 Prerequisites

- Flutter SDK (stable) compatible with Dart ^3.9.2
- Supabase account (URL and Anon Key)
- OpenAI API Key

## ⚙️ Setup

### 1. Clone the repository

```bash
git clone <your-repository>
cd electiva3_flutter_Eidos
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure environment variables

Create a `.env` file at the project root with:

```env
# Supabase Configuration
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key

# OpenAI Configuration
OPENAI_KEY=your_openai_api_key
```

### 4. Configure Supabase (if applicable in your project)

1. Go to your Supabase project
2. Run the SQL script in `database_schema.sql` in the SQL Editor
3. This will create the required tables and security policies

### 5. Configure OpenAI

1. Go to [OpenAI API](https://platform.openai.com/api-keys)
2. Create a new API key
3. Add the key to the `.env` file

## 🏗️ Architecture

### Core Services

- `ChatService`: Primary API for chat operations
- `SyncService`: Handles syncing with Supabase
- `ChatDatabase`: Local SQLite database
- `AuthService`: Authentication and user management
- `HiveStorageService`: Preferences (model, personality, rules)

### Controllers

- `ChatController`: Chat and messages logic
- `AuthController`: Authentication handling
- `NavigationController`: View navigation and visibility

### Models

- `ConversationLocal`: Conversation model
- `MessageLocal`: Message model

### Chat view
- Bubble-style message list
- AI typing indicator
- Text input field
- Quick action buttons

### Empty states
- Lottie animations
- Welcome messages
- Suggested actions

## 🛠️ Development

### Project structure

```
lib/
├── controllers/          # GetX controllers
├── services/            # Business services
├── models/              # Data models
├── widgets/             # Reusable widgets
├── pages/               # App pages
├── routes/              # Route configuration
└── bindings/            # Dependency injection
```

### Useful commands

```bash
# Run the app
flutter run

# Analyze code
flutter analyze

# Format code
dart format .

# Clean project
flutter clean
```

## 📦 Packages and versions

From `pubspec.yaml`:

- lottie: ^3.1.2
- supabase_flutter: ^2.8.0
- flutter_dotenv: ^5.1.0
- image_picker: ^1.0.4
- sqflite: ^2.3.0
- path_provider: ^2.1.1
- path: ^1.8.3
- shared_preferences: ^2.2.2
- hive: ^2.2.3
- hive_flutter: ^1.1.0
- uuid: ^4.2.1
- get: ^4.6.6
- flutter_markdown: ^0.6.18
- intl: ^0.19.0

Dev:

- flutter_lints: ^5.0.0
- hive_generator: ^2.0.1
- build_runner: ^2.4.7

## ▶️ How to run

1) Create and complete the `.env` file (see Setup).
2) Make sure a device/emulator is running.
3) Run:

```bash
flutter clean
flutter pub get
flutter run
```

If you see asset (Lottie) errors, ensure `assets/fonts/svgs/` contains the JSON files in use (e.g., `alert.json`, `check.json`) and they are listed in `pubspec.yaml`.

## 🐛 Troubleshooting

### Common issues

1. **API Key error**: Verify keys in `.env`
2. **Sync issues**: Check your internet connection
3. **Database errors**: Run the SQL script in Supabase

### Debug logs

```dart
// Enable detailed logs
debugPrint('Error: $e');
```

## 📄 License

This project is licensed under the MIT License. See `LICENSE` for details.

## 🤝 Contributions

Contributions are welcome. Please:

1. Fork the project
2. Create a feature branch
3. Commit your changes
4. Push to your branch
5. Open a Pull Request

## 📞 Support

If you have questions or issues:

1. Review the documentation
2. Search existing issues
3. Open a new issue if needed

---

**Enjoy using Eidos!** 🚀

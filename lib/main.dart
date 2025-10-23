import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'widgets/animated_header.dart';
import 'widgets/chat_button.dart';
import 'widgets/loading_screen.dart';
import 'widgets/chat_view.dart';
import 'widgets/auth_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Set Poppins as the default font family for the entire app
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        textTheme: const TextTheme(
          // Use Poppins for all text
          headlineLarge: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
          headlineSmall: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
          titleSmall: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(fontFamily: 'Poppins'),
          bodyMedium: TextStyle(fontFamily: 'Poppins'),
          bodySmall: TextStyle(fontFamily: 'Poppins'),
        ),
      ),
      home: const MyHomePage(title: 'Eidos - Font Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _showChatView = false;
  bool _showAuthView = false;
  bool _isLoginView = true;

  @override
  void initState() {
    super.initState();
    _showInitialLoading();
  }

  void _showInitialLoading() async {
    // Show loading screen for 2 seconds on app startup
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoadingScreen(
                message: 'Welcome to Eidos',
                duration: Duration(seconds: 2),
              ),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
    await Future.delayed(const Duration(seconds: 2));
  }

  void _showLoadingOverlay(String message) {
    LoadingOverlay.show(
      context,
      message: message,
      duration: const Duration(seconds: 2),
    );

    // Hide loading after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        LoadingOverlay.hide();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom animated header - only show when not in auth view
            if (!_showAuthView)
              AnimatedHeader(
                onLogin: () {
                  setState(() {
                    _showAuthView = true;
                    _isLoginView = true;
                  });
                },
                onCreateChat: () {
                  setState(() {
                    _showChatView = true;
                  });
                },
                onChatSelected: (chatId) {
                  _showLoadingOverlay('Opening chat...');
                },
                recentChats: [], // Empty list to show empty state
                // Uncomment below to show sample chats:
                // recentChats: [
                //   {
                //     'id': 'chat_1',
                //     'title': 'AI Assistant Chat',
                //     'lastMessage': 'How can I help you today?',
                //     'time': '2m',
                //   },
                //   {
                //     'id': 'chat_2',
                //     'title': 'Code Review Discussion',
                //     'lastMessage': 'The implementation looks good',
                //     'time': '1h',
                //   },
                // ],
              ),

            // Main content
            Expanded(
              child: _showAuthView
                  ? AuthView(
                      onBack: () {
                        setState(() {
                          _showAuthView = false;
                        });
                      },
                      onToggleMode: () {
                        setState(() {
                          _isLoginView = !_isLoginView;
                        });
                      },
                      isLogin: _isLoginView,
                    )
                  : _showChatView
                  ? ChatView(
                      onBack: () {
                        setState(() {
                          _showChatView = false;
                        });
                      },
                    )
                  : Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const SizedBox(height: 20),
                            // Lottie animation
                            SizedBox(
                              width: 200,
                              height: 200,
                              child: Lottie.asset(
                                'assets/fonts/svgs/svgsquare.json',
                                fit: BoxFit.contain,
                                repeat: true,
                              ),
                            ),
                            const SizedBox(height: 30),
                            const Text(
                              'Start a chat to start working on new projects and documents',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 30),
                            // Chat button
                            ChatButton(
                              text: 'Start New Chat',
                              icon: Icons.chat_bubble_outline,
                              isPrimary: true,
                              onTap: () {
                                setState(() {
                                  _showChatView = true;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'widgets/animated_header.dart';
import 'widgets/chat_button.dart';
import 'widgets/loading_screen.dart';
import 'widgets/chat_view.dart';
import 'widgets/auth_view.dart';
import 'widgets/edit_profile_view.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Error loading .env file: $e');
    // If .env fails, we cannot proceed without credentials
    throw Exception(
      'Failed to load environment variables. Please check your .env file.',
    );
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

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
  bool _showEditProfile = false;
  bool _isLoginView = true;
  bool _isLoggedIn = false;
  String _userName = '';
  String _userEmail = '';
  String? _userAvatarUrl;

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
            // Custom animated header - only show when not in auth view or edit profile
            if (!_showAuthView && !_showEditProfile)
              AnimatedHeader(
                isLoggedIn: _isLoggedIn,
                userName: _userName,
                userEmail: _userEmail,
                userAvatarUrl: _userAvatarUrl,
                onLogin: () {
                  setState(() {
                    _showAuthView = true;
                    _isLoginView = true;
                  });
                },
                onLogout: () async {
                  try {
                    await AuthService.signOut();
                    setState(() {
                      _isLoggedIn = false;
                      _userName = '';
                      _userEmail = '';
                      _userAvatarUrl = null;
                    });
                  } catch (e) {
                    // Handle logout error if needed
                    debugPrint('Logout error: $e');
                  }
                },
                onEditProfile: () {
                  setState(() {
                    _showEditProfile = true;
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
                      onLoginSuccess: (name, email) async {
                        setState(() {
                          _isLoggedIn = true;
                          _userName = name;
                          _userEmail = email;
                          _showAuthView = false;
                        });

                        // Load user profile to get avatar URL
                        try {
                          final profile = await AuthService.getUserProfile();
                          if (profile != null && mounted) {
                            setState(() {
                              _userAvatarUrl = profile['avatar_url'];
                            });
                          }
                        } catch (e) {
                          debugPrint('Error loading user profile: $e');
                        }
                      },
                      isLogin: _isLoginView,
                    )
                  : _showEditProfile
                  ? EditProfileView(
                      currentName: _userName,
                      currentEmail: _userEmail,
                      onBack: () {
                        setState(() {
                          _showEditProfile = false;
                        });
                      },
                      onSaveProfile: (name, email, bio) async {
                        setState(() {
                          _userName = name;
                          _userEmail = email;
                          _showEditProfile = false;
                        });

                        // Refresh user profile to get updated avatar
                        try {
                          final profile = await AuthService.getUserProfile();
                          if (profile != null && mounted) {
                            setState(() {
                              _userAvatarUrl = profile['avatar_url'];
                            });
                          }
                        } catch (e) {
                          debugPrint('Error refreshing user profile: $e');
                        }
                      },
                      onDeleteAccount: () {
                        setState(() {
                          _isLoggedIn = false;
                          _userName = '';
                          _userEmail = '';
                          _userAvatarUrl = null;
                          _showEditProfile = false;
                        });
                      },
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

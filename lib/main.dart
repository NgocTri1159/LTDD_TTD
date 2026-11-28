import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'views/subject/subject_manage_screen.dart';
import 'views/exam/exam_list_view.dart';
import 'views/admin/admin_main_screen.dart';
import 'views/splash/loading_screen.dart';
import 'views/auth/login_screen.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: 'https://hjtqxdnrnpudvjqaqiru.supabase.co',
    publishableKey: 'sb_publishable_adxCVKISmOYbN1aLR21gcg_AA8HAgi4',
  );

  runApp(const QuizMasterApp());
}

class QuizMasterApp extends StatelessWidget {
  const QuizMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuizMaster',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    await Future.wait([
      _checkSessionAndRole(),
      Future.delayed(const Duration(milliseconds: 1900)),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkSessionAndRole() async {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;

      if (session == null) {
        _isLoggedIn = false;
        _isAdmin = false;
        return;
      }

      _isLoggedIn = true;
      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle();

      final role = (profile?['role'] ?? 'User').toString().toLowerCase();
      _isAdmin = role == 'admin';
    } catch (_) {
      _isLoggedIn = false;
      _isAdmin = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingScreen();
    }
    if (!_isLoggedIn) {
      return const LoginScreen();
    }
    return _isAdmin ? const AdminMainScreen() : const MainNavigationScreen();
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ExamListView(),
    SubjectManageScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.base,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_rounded),
            label: 'Bộ đề',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: 'Môn học',
          ),
        ],
      ),
    );
  }
}
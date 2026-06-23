import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/parent_attendance_screen.dart';
import 'screens/teacher_class_students_screen.dart';
import 'screens/classes_screen.dart';
import 'screens/teacher_stats_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/teacher_telegram_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notifications_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/onboarding_screen.dart';
import 'screens/events_screen.dart';
import 'firebase_options.dart';

class RestartWidget extends StatefulWidget {
  final Widget child;

  const RestartWidget({super.key, required this.child});

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restartApp();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: widget.child,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Android: dark icons
    statusBarBrightness: Brightness.light, // iOS: dark text
  ));
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint("Firebase init failed: $e");
  }
  runApp(
    const RestartWidget(
      child: ProviderScope(
        child: MyApp(),
      ),
    ),
  );
}

class AppleScrollBehavior extends ScrollBehavior {
  const AppleScrollBehavior();
  
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HVT EduSuite Mobile',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'),
      ],
      scrollBehavior: const AppleScrollBehavior(), // Apply Apple bounce globally
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: const Color(0xFF6C63FF),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7FC), // Soft cream/light-blue
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark, // Android: dark icons
            statusBarBrightness: Brightness.light, // iOS: dark text
          ),
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: const Color(0xFF2D3142), // Deep grey/blue for high readability
          displayColor: const Color(0xFF1F2232),
        ),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF00D2FF),
          surface: Colors.white,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool? _onboardingCompleted;

  @override
  void initState() {
    super.initState();
    _loadOnboardingStatus();
  }

  Future<void> _loadOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
      
      // DEBUG OVERRIDE: Always show onboarding in debug mode
      if (kDebugMode) {
        _onboardingCompleted = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingCompleted == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F7FC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
      );
    }

    final authState = ref.watch(authProvider);
    Widget mainScreen;

    switch (authState.status) {
      case AuthStatus.authenticated:
        if (authState.role == 'parent') {
          mainScreen = ParentDashboard(student: authState.student!);
        } else {
          mainScreen = TeacherDashboard(user: authState.user!);
        }
        break;
      case AuthStatus.loading:
      case AuthStatus.unknown:
        mainScreen = const Scaffold(
          backgroundColor: Color(0xFFF4F7FC),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'logo',
                  child: Icon(Icons.school_rounded, size: 80, color: Color(0xFF6C63FF)),
                ),
                SizedBox(height: 24),
                CircularProgressIndicator(color: Color(0xFF6C63FF)),
              ],
            ),
          ),
        );
        break;
      case AuthStatus.unauthenticated:
        mainScreen = const LoginScreen();
        break;
    }

    if (!_onboardingCompleted!) {
      return Stack(
        children: [
          mainScreen,
          Positioned.fill(
            child: OnboardingScreen(
              onFinish: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboarding_completed', true);
                setState(() {
                  _onboardingCompleted = true;
                });
              },
            ),
          ),
        ],
      );
    }

    return mainScreen;
  }
}

// ── Parent Dashboard ────────────────────────────────────────────────────────
class ParentDashboard extends ConsumerStatefulWidget {
  final dynamic student;

  const ParentDashboard({super.key, required this.student});

  @override
  ConsumerState<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends ConsumerState<ParentDashboard> {
  int _currentIndex = 0;
  String? _currentParentName;

  @override
  void initState() {
    super.initState();
    _currentParentName = widget.student.tenPhuHuynh;
    // One-time prompt for parents who registered before the name field existed
    if (_currentParentName == null || _currentParentName!.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFirstTimeNamePrompt();
      });
    }
  }

  Future<void> _showFirstTimeNamePrompt() async {
    final controller = TextEditingController();
    bool loading = false;
    String? error;

    final newName = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'Cập nhật tên phụ huynh',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2232)),
              ),
              content: Padding(
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Vui lòng cập nhật họ tên đầy đủ của phụ huynh để tiếp tục sử dụng ứng dụng.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (error != null) ...[
                      Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      const SizedBox(height: 8),
                    ],
                    TextFormField(
                      controller: controller,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'Họ và tên Phụ huynh',
                        prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF6C63FF)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Vui lòng nhập họ tên';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: loading ? null : () async {
                    if (controller.text.trim().isEmpty) {
                      setDialogState(() { error = 'Vui lòng nhập họ tên'; });
                      return;
                    }
                    setDialogState(() { loading = true; error = null; });

                    try {
                      final response = await apiService.updateParentName(controller.text.trim());
                      if (response.statusCode == 200 || response.statusCode == 201) {
                        if (dialogContext.mounted) Navigator.pop(dialogContext, controller.text.trim());
                      } else {
                        setDialogState(() { error = 'Lỗi lưu tên. Vui lòng thử lại.'; loading = false; });
                      }
                    } catch (e) {
                      setDialogState(() { error = 'Lỗi kết nối. Vui lòng thử lại.'; loading = false; });
                    }
                  },
                  child: loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Lưu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            );
          },
        );
      },
    );
    // Defer disposal to ensure the dialog's exit animation completes
    // without the TextFormField trying to read a disposed controller when the keyboard hides.
    Future.delayed(const Duration(milliseconds: 500), () {
      controller.dispose();
    });

    if (newName != null && mounted) {
      setState(() {
        _currentParentName = newName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeView(),
      const AiChatScreen(role: 'parent'),
      const NotificationsScreen(),
      SettingsScreen(
        role: 'parent',
        data: widget.student,
        onLogout: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(authProvider.notifier).logout();
            }
          });
        },
        onReload: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(authProvider.notifier).reloadSessionSilently();
            }
          });
        },
        onParentNameChanged: (name) {
          setState(() {
            _currentParentName = name;
          });
        },
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        title: Image.asset('assets/logo.png', height: 38),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: NavigationBar(
          height: 68,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          indicatorColor: const Color(0xFF6C63FF).withValues(alpha: 0.12),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Colors.grey),
              selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF6C63FF)),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.psychology_outlined, color: Colors.grey),
              selectedIcon: Icon(Icons.psychology_rounded, color: Color(0xFF6C63FF)),
              label: 'Trợ lý AI',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined, color: Colors.grey),
              selectedIcon: Icon(Icons.notifications_rounded, color: Color(0xFF6C63FF)),
              label: 'Thông báo',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: Colors.grey),
              selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFF6C63FF)),
              label: 'Cài đặt',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeView() {
    final String greetingName = _currentParentName != null && _currentParentName!.isNotEmpty
        ? _currentParentName!
        : 'Phụ huynh em ${widget.student.ten}';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xin chào,',
            style: TextStyle(fontSize: 16, color: const Color(0xFF2D3142).withValues(alpha: 0.6), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            greetingName,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1F2232)),
          ),
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFEEECFF),
                  Color(0xFFF6F8FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                )
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'THÔNG TIN HỌC SINH',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: Color(0xFF6C63FF)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.student.ten,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1F2232),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Lớp', style: TextStyle(fontSize: 11, color: const Color(0xFF2D3142).withValues(alpha: 0.5))),
                              const SizedBox(height: 2),
                              Text(widget.student.lop, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF2D3142))),
                            ],
                          ),
                          const SizedBox(width: 28),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Giới tính', style: TextStyle(fontSize: 11, color: const Color(0xFF2D3142).withValues(alpha: 0.5))),
                              const SizedBox(height: 2),
                              Text(widget.student.gioiTinh, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF2D3142))),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ngày sinh', style: TextStyle(fontSize: 11, color: const Color(0xFF2D3142).withValues(alpha: 0.5))),
                              const SizedBox(height: 2),
                              Text(
                                widget.student.ngaySinh is DateTime
                                    ? "${widget.student.ngaySinh.day.toString().padLeft(2, '0')}/${widget.student.ngaySinh.month.toString().padLeft(2, '0')}/${widget.student.ngaySinh.year}"
                                    : widget.student.ngaySinh.toString(),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF2D3142)),
                              ),
                            ],
                          ),
                          const SizedBox(width: 28),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mã thẻ', style: TextStyle(fontSize: 11, color: const Color(0xFF2D3142).withValues(alpha: 0.5))),
                              const SizedBox(height: 2),
                              Text(
                                widget.student.uidThe,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF2D3142),
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 90,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                    image: widget.student.anhThe != null && widget.student.anhThe!.isNotEmpty
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(widget.student.anhThe!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: widget.student.anhThe == null || widget.student.anhThe!.isEmpty
                      ? const Icon(Icons.face_rounded, color: Color(0xFF6C63FF), size: 48)
                      : null,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 36),
          const Text(
            'Lối tắt nhanh',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1F2232)),
          ),
          const SizedBox(height: 16),
          _buildQuickActionTile(
            Icons.history_rounded,
            'Lịch sử điểm danh',
            'Xem chi tiết lịch sử quẹt thẻ ra vào lớp',
            const Color(0xFF6C63FF),
            const Color(0xFFF0EFFF),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ParentAttendanceScreen(student: widget.student),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile(IconData icon, String label, String description, Color iconColor, Color bgColor, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 16, offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, size: 28, color: iconColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }


}

// ── Teacher Dashboard ───────────────────────────────────────────────────────
class TeacherDashboard extends ConsumerStatefulWidget {
  final dynamic user;

  const TeacherDashboard({super.key, required this.user});

  @override
  ConsumerState<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends ConsumerState<TeacherDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeView(),
      widget.user.role == 'admin' ? ClassesScreen(user: widget.user) : TeacherClassStudentsScreen(user: widget.user),
      const NotificationsScreen(),
      const AiChatScreen(role: 'teacher'),
      SettingsScreen(
        role: 'teacher',
        data: widget.user,
        onLogout: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(authProvider.notifier).logout();
            }
          });
        },
        onReload: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(authProvider.notifier).reloadSessionSilently();
            }
          });
        },
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        title: Image.asset('assets/logo.png', height: 38),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: NavigationBar(
          height: 68,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          indicatorColor: const Color(0xFF6C63FF).withValues(alpha: 0.12),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Colors.grey),
              selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF6C63FF)),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined, color: Colors.grey),
              selectedIcon: Icon(Icons.groups_rounded, color: Color(0xFF6C63FF)),
              label: 'Lớp học',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined, color: Colors.grey),
              selectedIcon: Icon(Icons.notifications_rounded, color: Color(0xFF6C63FF)),
              label: 'Thông báo',
            ),
            NavigationDestination(
              icon: Icon(Icons.psychology_outlined, color: Colors.grey),
              selectedIcon: Icon(Icons.psychology_rounded, color: Color(0xFF6C63FF)),
              label: 'Trợ lý AI',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: Colors.grey),
              selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFF6C63FF)),
              label: 'Cài đặt',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xin chào,',
            style: TextStyle(fontSize: 16, color: const Color(0xFF2D3142).withValues(alpha: 0.6), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            widget.user.accountname,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1F2232)),
          ),
          const SizedBox(height: 24),
          
          // Teacher Info Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF20C997).withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF20C997).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_rounded, color: Color(0xFF20C997), size: 32),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lớp chủ nhiệm',
                      style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.user.lopQuyen ?? "Không có",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1F2232)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 36),
          const Text(
            'Công cụ nhanh',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1F2232)),
          ),
          const SizedBox(height: 16),
          _buildQuickActionTile(
            Icons.insert_chart_rounded,
            'Thống kê & Đánh giá',
            'Xem biểu đồ chuyên cần và phân tích',
            const Color(0xFFFF9F43),
            const Color(0xFFFFF5EC),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherStatsScreen(user: widget.user),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActionTile(
            Icons.send_rounded,
            'Liên kết Telegram',
            'Quản lý bot Telegram nhận thông báo',
            const Color(0xFF0088CC),
            const Color(0xFFE5F6FD),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherTelegramScreen(user: widget.user),
              ),
            ),
          ),

          const SizedBox(height: 16),
          _buildQuickActionTile(
            Icons.event_available_rounded,
            'Quản lý Sự kiện',
            'Lên lịch và điểm danh sự kiện trường lớp',
            const Color(0xFF6C63FF),
            const Color(0xFFEEECFF),
            () {
              final lop = widget.user.lopQuyen;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventsScreen(lop: lop?.isEmpty == true ? null : lop),
                ),
              );
            },
          ),
          const SizedBox(height: 32), // Padding at the bottom for scrolling
        ],
      ),
    );
  }

  Widget _buildQuickActionTile(IconData icon, String label, String description, Color iconColor, Color bgColor, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 16, offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, size: 28, color: iconColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }


}

// Make from Kiên and Dương with love

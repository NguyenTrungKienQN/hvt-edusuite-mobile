import 'dart:math' as math;
import 'package:flutter/material.dart';

// --- Physics & Animations ---

class AppleSpringCurve extends Curve {
  final double damping;
  final double stiffness;

  const AppleSpringCurve({this.damping = 7.0, this.stiffness = 12.0});

  @override
  double transformInternal(double t) {
    if (t == 0.0) return 0.0;
    if (t == 1.0) return 1.0;
    return 1.0 - math.exp(-damping * t) * math.cos(stiffness * t);
  }
}

// --- Data Models ---

class OrbitIconData {
  final IconData icon;
  final Color color;
  final Offset offset;
  final double scale;
  final double phaseOffset;

  OrbitIconData({
    required this.icon,
    required this.color,
    required this.offset,
    required this.scale,
    required this.phaseOffset,
  });
}

class OnboardingPageData {
  final String title;
  final String description;
  final IconData centerIcon;
  final Color centerColor;
  final List<OrbitIconData> orbitIcons;
  final bool isFinalPage;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.centerIcon,
    required this.centerColor,
    required this.orbitIcons,
    this.isFinalPage = false,
  });
}

// --- Main Screen ---

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _idleController;
  late PageController _pageController;
  late AnimationController _dismissAnimController;

  int _currentPage = 0;
  double _dragOffset = 0.0;

  late List<OnboardingPageData> _pages;

  @override
  void initState() {
    super.initState();
    _initPages();

    _pageController = PageController();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    _dismissAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _entranceController.forward().then((_) {
      _idleController.repeat();
    });
  }

  void _initPages() {
    _pages = [
      // Page 1: Ecosystem
      OnboardingPageData(
        title: "Tất cả tiện ích học đường, trong một ứng dụng",
        description:
            "Theo dõi điểm danh, bài tập, điểm số, thời khóa biểu, thông báo, tài liệu, nhắn tin và trợ lý AI từ một ứng dụng duy nhất.",
        centerIcon: Icons.school_rounded,
        centerColor: const Color(0xFF6C63FF),
        orbitIcons: [
          OrbitIconData(
              icon: Icons.fact_check,
              color: Colors.green,
              offset: const Offset(-80, -90),
              scale: 1.1,
              phaseOffset: 0.0),
          OrbitIconData(
              icon: Icons.assignment,
              color: Colors.blue,
              offset: const Offset(80, -70),
              scale: 1.0,
              phaseOffset: 1.2),
          OrbitIconData(
              icon: Icons.grade,
              color: Colors.orange,
              offset: const Offset(-100, 20),
              scale: 0.9,
              phaseOffset: 2.5),
          OrbitIconData(
              icon: Icons.calendar_month,
              color: Colors.redAccent,
              offset: const Offset(110, 10),
              scale: 1.2,
              phaseOffset: 3.8),
          OrbitIconData(
              icon: Icons.campaign,
              color: Colors.purple,
              offset: const Offset(-70, 100),
              scale: 1.0,
              phaseOffset: 5.1),
          OrbitIconData(
              icon: Icons.folder,
              color: Colors.teal,
              offset: const Offset(60, 110),
              scale: 0.8,
              phaseOffset: 6.4),
          OrbitIconData(
              icon: Icons.chat_bubble,
              color: Colors.indigo,
              offset: const Offset(0, -110),
              scale: 0.9,
              phaseOffset: 7.7),
          OrbitIconData(
              icon: Icons.auto_awesome,
              color: Colors.amber,
              offset: const Offset(0, 130),
              scale: 1.1,
              phaseOffset: 9.0),
        ],
      ),
      // Page 2: Organized
      OnboardingPageData(
        title: "Theo dõi quá trình học tập",
        description:
            "Dễ dàng theo dõi điểm danh hàng ngày, lịch học và kết quả học tập theo thời gian thực.",
        centerIcon: Icons.calendar_month_rounded,
        centerColor: Colors.deepOrange,
        isFinalPage: true,
        orbitIcons: [
          OrbitIconData(
              icon: Icons.task_alt,
              color: Colors.green,
              offset: const Offset(-90, -50),
              scale: 1.2,
              phaseOffset: 0.5),
          OrbitIconData(
              icon: Icons.schedule,
              color: Colors.blue,
              offset: const Offset(80, -90),
              scale: 1.0,
              phaseOffset: 1.5),
          OrbitIconData(
              icon: Icons.push_pin,
              color: Colors.red,
              offset: const Offset(-80, 80),
              scale: 0.9,
              phaseOffset: 3.0),
          OrbitIconData(
              icon: Icons.event_note,
              color: Colors.purple,
              offset: const Offset(90, 70),
              scale: 1.1,
              phaseOffset: 4.5),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _idleController.dispose();
    _pageController.dispose();
    _dismissAnimController.dispose();
    super.dispose();
  }

  void _completeOnboarding() {
    if (_dismissAnimController.isAnimating) return;
    
    final screenHeight = MediaQuery.of(context).size.height;
    final tween = Tween<double>(begin: _dragOffset, end: screenHeight)
        .animate(CurvedAnimation(parent: _dismissAnimController, curve: Curves.easeInCubic));
        
    tween.addListener(() {
      setState(() {
        _dragOffset = tween.value;
      });
    });
    
    _dismissAnimController.forward(from: 0).then((_) {
      widget.onFinish();
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_currentPage == _pages.length - 1) {
      if (details.delta.dy > 0 || _dragOffset > 0) {
        setState(() {
          _dragOffset += details.delta.dy;
          if (_dragOffset < 0) _dragOffset = 0;
        });
      }
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dragOffset == 0) return;
    
    if (_dragOffset > 150 || details.primaryVelocity! > 300) {
      _completeOnboarding();
    } else {
      final tween = Tween<double>(begin: _dragOffset, end: 0)
          .animate(CurvedAnimation(parent: _dismissAnimController, curve: Curves.easeOutCubic));
      tween.addListener(() {
        setState(() {
          _dragOffset = tween.value;
        });
      });
      _dismissAnimController.forward(from: 0);
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  // --- Builders ---

  Widget _buildPage(int index) {
    final page = _pages[index];

    // Typography fade-in (only runs on first page load via entrance controller)
    // On subsequent pages, the transition handles the fade.
    final typographyOpacity = (index == 0)
        ? CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
          )
        : const AlwaysStoppedAnimation(1.0);

    return Container(
      color: Colors.transparent, // Transparent so background gradient shows through
      child: Column(
        children: [
          // Hero Area
          Expanded(
            flex: 55,
            child: Center(
              child: _buildHeroSystem(page, index == 0),
            ),
          ),

          // Content Area
          Expanded(
            flex: 45,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: AnimatedBuilder(
                animation: typographyOpacity,
                builder: (context, child) {
                  return Opacity(
                    opacity: typographyOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1.0 - typographyOpacity.value)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      page.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2232),
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      page.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF707482),
                        height: 1.5,
                      ),
                    ),
                    const Spacer(),

                    // CTA Area
                    if (!page.isFinalPage)
                      _buildCTAButton(
                        text: "Tiếp tục",
                        onPressed: _nextPage,
                        isPrimary: true,
                      )
                    else
                      _buildCTAButton(
                        text: "Bắt đầu",
                        onPressed: _completeOnboarding,
                        isPrimary: true,
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTAButton(
      {required String text,
      required VoidCallback? onPressed,
      required bool isPrimary}) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPrimary ? const Color(0xFF0A84FF) : Colors.transparent,
          foregroundColor: isPrimary ? Colors.white : const Color(0xFF0A84FF),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
            side: isPrimary
                ? BorderSide.none
                : const BorderSide(color: Colors.transparent),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 17,
            fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSystem(OnboardingPageData page, bool isFirstPage) {
    // Center Hero Animation
    final heroScale = isFirstPage
        ? CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.1, 0.6, curve: AppleSpringCurve()),
          )
        : const AlwaysStoppedAnimation(1.0);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Orbiting elements
        ...page.orbitIcons.asMap().entries.map((entry) {
          int idx = entry.key;
          OrbitIconData data = entry.value;

          // Staggered entrance (40ms per icon)
          double start = 0.3 + (idx * 0.04);
          double end = start + 0.3;
          if (end > 1.0) end = 1.0;

          final entranceAnim = isFirstPage
              ? CurvedAnimation(
                  parent: _entranceController,
                  curve: Interval(start, end, curve: Curves.easeOutBack),
                )
              : const AlwaysStoppedAnimation(1.0);

          return AnimatedBuilder(
            animation: Listenable.merge([_entranceController, _idleController]),
            builder: (context, child) {
              final val = entranceAnim.value;

              // Idle float (only active after entrance completes)
              double floatOffset = 0.0;
              if (val >= 1.0) {
                floatOffset = math.sin((_idleController.value * 2 * math.pi) +
                        data.phaseOffset) *
                    3.0;
              }

              return Transform.translate(
                offset: Offset(
                  data.offset.dx * val,
                  data.offset.dy * val + (10.0 * (1.0 - val)) + floatOffset,
                ),
                child: Transform.scale(
                  scale: (0.6 + (0.4 * val)) * data.scale,
                  child: Opacity(
                    opacity: val.clamp(0.0, 1.0),
                    child: _buildOrbitIcon(data),
                  ),
                ),
              );
            },
          );
        }),

        // Center Hero
        AnimatedBuilder(
          animation: heroScale,
          builder: (context, child) {
            return Transform.scale(
              scale: heroScale.value,
              child: child,
            );
          },
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000), // 0.04 opacity black
                  blurRadius: 20,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Center(
              child: Icon(
                page.centerIcon,
                size: 52,
                color: page.centerColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrbitIcon(OrbitIconData data) {
    return Icon(
      data.icon,
      size: 32, // Slightly larger since box is gone
      color: data.color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardScale = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.5, curve: AppleSpringCurve()),
    );

    return Transform.translate(
      offset: Offset(0, _dragOffset),
      child: GestureDetector(
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 300,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFF0E6),
                        Color(0x00FFFFFF),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: AnimatedBuilder(
                  animation: cardScale,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: cardScale.value,
                      child: child,
                    );
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const AlwaysScrollableScrollPhysics(), // Automatically uses Android stretch/clamp or iOS bounce based on platform
                    itemCount: _pages.length,
                    onPageChanged: (idx) {
                      setState(() {
                        _currentPage = idx;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildPage(index);
                    },
                  ),
                ),
              ),
              if (_currentPage > 0)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0A84FF)),
                    onPressed: _prevPage,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Make from Kiên and Dương with love

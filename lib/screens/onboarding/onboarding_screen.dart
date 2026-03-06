import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../services/storage_service.dart';
import '../../services/background_service.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final TextEditingController _nameController = TextEditingController();

  // Permission states
  bool _micGranted = false;
  bool _locationGranted = false;
  bool _smsGranted = false;

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: List.generate(
                    4,
                    (i) => Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i <= _currentPage
                              ? AppColors.primary
                              : AppColors.surfaceLight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                    _fadeController.reset();
                    _fadeController.forward();
                  },
                  children: [
                    _buildWelcomePage(),
                    _buildNamePage(),
                    _buildPermissionsPage(),
                    _buildReadyPage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Shield icon with glow
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_rounded,
                size: 70,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 48),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              AppConstants.appTagline,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w400,
                  ),
            ),
            const SizedBox(height: 32),
            Text(
              'AI-powered safety that listens and protects you automatically, 24/7.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                  ),
            ),
            const Spacer(),
            _buildNextButton('Get Started', () => _goToPage(1)),
          ],
        ),
      ),
    );
  }

  Widget _buildNamePage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceLight,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 48,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: 36),
            Text(
              'What should we call you?',
              style: Theme.of(context).textTheme.displayMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'This name will be used in emergency SMS alerts to your contacts.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
              ),
              decoration: InputDecoration(
                hintText: 'Enter your name',
                prefixIcon: const Icon(Icons.edit_rounded, color: AppColors.primaryLight),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const Spacer(),
            _buildNextButton('Continue', () async {
              if (_nameController.text.trim().isNotEmpty) {
                await StorageService.setSetting(
                  AppConstants.keyUserName,
                  _nameController.text.trim(),
                );
                _goToPage(2);
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              'Permissions Required',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'We need these to keep you safe. Your data stays on your device.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 36),

            // Microphone
            _buildPermissionTile(
              icon: Icons.mic_rounded,
              title: 'Microphone',
              subtitle: 'Listen for distress sounds to detect danger automatically',
              granted: _micGranted,
              onTap: () async {
                final status = await Permission.microphone.request();
                setState(() => _micGranted = status.isGranted);
              },
            ),
            const SizedBox(height: 16),

            // Location
            _buildPermissionTile(
              icon: Icons.location_on_rounded,
              title: 'Location',
              subtitle: 'Share your GPS coordinates in emergency alerts',
              granted: _locationGranted,
              onTap: () async {
                final status = await Permission.locationWhenInUse.request();
                if (status.isGranted) {
                  final alwaysStatus = await Permission.locationAlways.request();
                  setState(() => _locationGranted = status.isGranted || alwaysStatus.isGranted);
                }
              },
            ),
            const SizedBox(height: 16),

            // SMS
            _buildPermissionTile(
              icon: Icons.sms_rounded,
              title: 'SMS',
              subtitle: 'Send emergency messages to your trusted contacts',
              granted: _smsGranted,
              onTap: () async {
                final status = await Permission.sms.request();
                setState(() => _smsGranted = status.isGranted);
              },
            ),

            const Spacer(),
            _buildNextButton(
              'Continue',
              _micGranted && _locationGranted
                  ? () => _goToPage(3)
                  : null,
            ),
            if (!_micGranted || !_locationGranted)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Microphone and Location are required',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.warning,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: granted ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: granted
              ? AppColors.success.withValues(alpha: 0.1)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: granted
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.textMuted.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: granted
                    ? AppColors.success.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.2),
              ),
              child: Icon(
                icon,
                color: granted ? AppColors.success : AppColors.primaryLight,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              granted ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
              color: granted ? AppColors.success : AppColors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyPage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.success, Color(0xFF34D399)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.4),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 70,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              "You're All Set!",
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'SafeGuardHer is ready to protect you. Add emergency contacts from the app to get started.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.privacy_tip_rounded, color: AppColors.primaryLight, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'All data stays locally on your device',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.primaryLight,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _buildNextButton('Start Protection', () async {
              // Request notification permission (required for foreground service on Android 13+)
              await Permission.notification.request();
              await StorageService.setSetting(AppConstants.keyOnboardingComplete, true);
              // Auto-enable protection so monitoring starts immediately
              await StorageService.setSetting(AppConstants.keyProtectionEnabled, true);
              await BackgroundServiceManager.startService();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton(String text, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed != null ? AppColors.primary : AppColors.surfaceLight,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: onPressed != null ? 8 : 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: onPressed != null ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }
}

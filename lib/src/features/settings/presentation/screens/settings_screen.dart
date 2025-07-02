import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:solvix/src/app_bloc.dart';
import 'package:solvix/src/app_event.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/core/theme/app_theme.dart';
import 'package:solvix/src/core/theme/theme_cubit.dart';

class SettingsScreen extends StatefulWidget {
  final UserModel? currentUser;

  const SettingsScreen({super.key, required this.currentUser});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    if (widget.currentUser == null) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0B1426)
            : const Color(0xFFF7F8FC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isDesktop ? 80 : 64,
                height: isDesktop ? 80 : 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53E3E),
                  borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE53E3E).withOpacity(0.25),
                      blurRadius: isDesktop ? 20 : 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.person_off_rounded,
                  color: Colors.white,
                  size: isDesktop ? 40 : 32,
                ),
              ),
              SizedBox(height: isDesktop ? 24 : 20),
              Text(
                "اطلاعات کاربر در دسترس نیست",
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B1426)
          : const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 24,
                vertical: isDesktop ? 48 : 40,
              ),
              child: Column(
                children: [
                  SizedBox(height: isDesktop ? 24 : 20),

                  // Header با آیکون بازگشت
                  _buildModernHeader(
                    context,
                    isDark,
                    primaryColor,
                    isDesktop,
                  ).animate().slideY(begin: -0.3, curve: Curves.easeOutCubic),

                  SizedBox(height: isDesktop ? 40 : 32),

                  // پروفایل کاربر
                  _buildModernUserProfile(
                    context,
                    isDark,
                    primaryColor,
                    isDesktop,
                  ).animate().slideY(
                    begin: 0.3,
                    delay: const Duration(milliseconds: 100),
                    curve: Curves.easeOutCubic,
                  ),

                  SizedBox(height: isDesktop ? 32 : 24),

                  // تنظیمات ظاهر
                  _buildModernSettingsSection(
                    context,
                    title: "تنظیمات ظاهر",
                    icon: Icons.palette_rounded,
                    iconColor: Colors.purple,
                    isDark: isDark,
                    primaryColor: primaryColor,
                    isDesktop: isDesktop,
                    items: [
                      _buildModernSettingsTile(
                        context,
                        icon: Icons.dark_mode_rounded,
                        iconColor: Colors.indigo,
                        title: "انتخاب تم",
                        subtitle: "تغییر ظاهر برنامه",
                        onTap: () => _showEnhancedThemeDialog(context),
                        isDark: isDark,
                        primaryColor: primaryColor,
                        isDesktop: isDesktop,
                      ),
                    ],
                  ).animate().slideX(
                    begin: -0.2,
                    delay: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                  ),

                  SizedBox(height: isDesktop ? 24 : 20),

                  // تنظیمات عمومی
                  _buildModernSettingsSection(
                    context,
                    title: "تنظیمات عمومی",
                    icon: Icons.settings_rounded,
                    iconColor: Colors.blue,
                    isDark: isDark,
                    primaryColor: primaryColor,
                    isDesktop: isDesktop,
                    items: [
                      _buildModernSettingsTile(
                        context,
                        icon: Icons.notifications_active_rounded,
                        iconColor: Colors.orange,
                        title: "اعلانات و صداها",
                        subtitle: "مدیریت اعلانات",
                        onTap: () => _showModernComingSoonDialog(
                          context,
                          "اعلانات و صداها",
                        ),
                        isDark: isDark,
                        primaryColor: primaryColor,
                        isDesktop: isDesktop,
                      ),
                      _buildModernSettingsTile(
                        context,
                        icon: Icons.security_rounded,
                        iconColor: Colors.green,
                        title: "حریم خصوصی و امنیت",
                        subtitle: "تنظیمات امنیتی",
                        onTap: () => _showModernComingSoonDialog(
                          context,
                          "حریم خصوصی و امنیت",
                        ),
                        isDark: isDark,
                        primaryColor: primaryColor,
                        isDesktop: isDesktop,
                      ),
                      _buildModernSettingsTile(
                        context,
                        icon: Icons.language_rounded,
                        iconColor: Colors.teal,
                        title: "زبان برنامه",
                        subtitle: "فارسی",
                        onTap: () =>
                            _showModernComingSoonDialog(context, "زبان برنامه"),
                        isDark: isDark,
                        primaryColor: primaryColor,
                        isDesktop: isDesktop,
                      ),
                    ],
                  ).animate().slideX(
                    begin: 0.2,
                    delay: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  ),

                  SizedBox(height: isDesktop ? 40 : 32),

                  // دکمه خروج
                  _buildModernLogoutButton(
                    context,
                    isDark,
                    primaryColor,
                    isDesktop,
                  ).animate().scale(
                    delay: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                  ),

                  SizedBox(height: isDesktop ? 32 : 24),

                  // اطلاعات نسخه
                  _buildModernVersionInfo(
                    context,
                    isDark,
                    primaryColor,
                    isDesktop,
                  ).animate().fadeIn(delay: const Duration(milliseconds: 500)),

                  if (isDesktop) SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    bool isDesktop,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تنظیمات',
          style: TextStyle(
            fontSize: isDesktop ? 28 : 24,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        SizedBox(height: isDesktop ? 4 : 2),
        Text(
          'مدیریت حساب کاربری و تنظیمات',
          style: TextStyle(
            fontSize: isDesktop ? 16 : 14,
            color: isDark ? Colors.white60 : Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildModernUserProfile(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    bool isDesktop,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDesktop ? 0.08 : 0.06),
            blurRadius: isDesktop ? 20 : 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // آواتار
          Container(
            width: isDesktop ? 100 : 80,
            height: isDesktop ? 100 : 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: isDesktop ? 20 : 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _getAvatarInitials(),
                style: TextStyle(
                  fontSize: isDesktop ? 36 : 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          SizedBox(height: isDesktop ? 20 : 16),

          // نام کاربر
          Text(
            _getUserFullName(),
            style: TextStyle(
              fontSize: isDesktop ? 24 : 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: isDesktop ? 8 : 6),

          // شماره تلفن
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 16,
              vertical: isDesktop ? 12 : 8,
            ),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
              border: Border.all(
                color: primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.phone_rounded,
                  size: isDesktop ? 16 : 14,
                  color: primaryColor,
                ),
                SizedBox(width: isDesktop ? 8 : 6),
                Text(
                  widget.currentUser!.phoneNumber ?? "شماره تلفن در دسترس نیست",
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : 13,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: isDesktop ? 24 : 20),

          // دکمه ویرایش پروفایل
          SizedBox(
            width: double.infinity,
            height: isDesktop ? 52 : 48,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _showModernComingSoonDialog(context, "ویرایش پروفایل");
              },
              icon: Icon(Icons.edit_rounded, size: isDesktop ? 20 : 18),
              label: Text(
                "ویرایش پروفایل",
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSettingsSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> items,
    required bool isDark,
    required Color primaryColor,
    required bool isDesktop,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // عنوان بخش
        Padding(
          padding: EdgeInsets.only(bottom: isDesktop ? 16 : 12),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 12 : 10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                  border: Border.all(
                    color: iconColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: iconColor, size: isDesktop ? 24 : 20),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: isDesktop ? 20 : 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),

        // محتوای بخش
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDesktop ? 0.08 : 0.06),
                blurRadius: isDesktop ? 16 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
            child: Column(children: items),
          ),
        ),
      ],
    );
  }

  Widget _buildModernSettingsTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    required Color primaryColor,
    required bool isDesktop,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 0.5,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 20,
              vertical: isDesktop ? 20 : 16,
            ),
            child: Row(
              children: [
                // آیکون
                Container(
                  width: isDesktop ? 52 : 48,
                  height: isDesktop ? 52 : 48,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                    border: Border.all(
                      color: iconColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: isDesktop ? 28 : 24,
                  ),
                ),

                SizedBox(width: isDesktop ? 20 : 16),

                // متن
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: isDesktop ? 17 : 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(height: isDesktop ? 4 : 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // فلش
                Container(
                  width: isDesktop ? 36 : 32,
                  height: isDesktop ? 36 : 32,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: isDesktop ? 18 : 16,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernLogoutButton(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    bool isDesktop,
  ) {
    return SizedBox(
      width: double.infinity,
      height: isDesktop ? 60 : 56,
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          _showEnhancedLogoutDialog(context);
        },
        icon: Icon(Icons.logout_rounded, size: isDesktop ? 24 : 22),
        label: Text(
          "خروج از حساب کاربری",
          style: TextStyle(
            fontSize: isDesktop ? 18 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE53E3E),
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
          ),
        ),
      ),
    );
  }

  Widget _buildModernVersionInfo(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    bool isDesktop,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 20,
        vertical: isDesktop ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: primaryColor,
            size: isDesktop ? 20 : 18,
          ),
          SizedBox(width: isDesktop ? 12 : 10),
          Text(
            "Solvix Messenger v1.0.0",
            style: TextStyle(
              fontSize: isDesktop ? 15 : 13,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showEnhancedThemeDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final isDesktop = MediaQuery.of(context).size.width > 600;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isDesktop ? 28 : 24),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 12 : 10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                  border: Border.all(
                    color: Colors.purple.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.palette_rounded,
                  color: Colors.purple,
                  size: isDesktop ? 24 : 22,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Text(
                "انتخاب تم",
                style: TextStyle(
                  fontSize: isDesktop ? 22 : 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEnhancedThemeOption(
                context: dialogContext,
                title: "تم روشن",
                icon: Icons.wb_sunny_rounded,
                theme: AppTheme.light,
                color: Colors.orange,
                isDark: isDark,
                isDesktop: isDesktop,
              ),
              SizedBox(height: isDesktop ? 16 : 12),
              _buildEnhancedThemeOption(
                context: dialogContext,
                title: "تم تاریک",
                icon: Icons.dark_mode_rounded,
                theme: AppTheme.dark,
                color: Colors.indigo,
                isDark: isDark,
                isDesktop: isDesktop,
              ),
              SizedBox(height: isDesktop ? 16 : 12),
              _buildEnhancedThemeOption(
                context: dialogContext,
                title: "تم سالویکس",
                icon: Icons.auto_awesome_rounded,
                theme: AppTheme.solvixAurora,
                color: Colors.purple,
                isDark: isDark,
                isDesktop: isDesktop,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnhancedThemeOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required AppTheme theme,
    required Color color,
    required bool isDark,
    required bool isDesktop,
  }) {
    final isSelected = _getCurrentThemeEnum(context) == theme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        border: Border.all(
          color: isSelected
              ? color
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.read<ThemeCubit>().changeTheme(theme);
            Navigator.of(context).pop();
          },
          borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 16,
              vertical: isDesktop ? 16 : 12,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isDesktop ? 12 : 10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                    border: Border.all(color: color.withOpacity(0.3), width: 1),
                  ),
                  child: Icon(icon, color: color, size: isDesktop ? 24 : 20),
                ),
                SizedBox(width: isDesktop ? 16 : 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isDesktop ? 17 : 16,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isSelected
                          ? color
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: isDesktop ? 28 : 24,
                    height: isDesktop ? 28 : 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: isDesktop ? 18 : 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEnhancedLogoutDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 600;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isDesktop ? 28 : 24),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 12 : 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53E3E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                  border: Border.all(
                    color: const Color(0xFFE53E3E).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: const Color(0xFFE53E3E),
                  size: isDesktop ? 24 : 22,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Text(
                "خروج از حساب",
                style: TextStyle(
                  fontSize: isDesktop ? 22 : 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            "آیا مطمئن هستید که می‌خواهید از حساب کاربری خود خارج شوید؟",
            style: TextStyle(
              fontSize: isDesktop ? 17 : 16,
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 20,
                  vertical: isDesktop ? 16 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                ),
              ),
              child: Text(
                "انصراف",
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(dialogContext).pop();
                context.read<AppBloc>().add(AppLoggedOut());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53E3E),
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 20,
                  vertical: isDesktop ? 16 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                ),
              ),
              child: Text(
                "خروج",
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showModernComingSoonDialog(BuildContext context, String feature) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final isDesktop = MediaQuery.of(context).size.width > 600;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isDesktop ? 28 : 24),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 12 : 10),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.construction_rounded,
                  color: primaryColor,
                  size: isDesktop ? 24 : 22,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Text(
                "به زودی...",
                style: TextStyle(
                  fontSize: isDesktop ? 22 : 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            "قابلیت \"$feature\" به زودی اضافه خواهد شد.",
            style: TextStyle(
              fontSize: isDesktop ? 17 : 16,
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 20,
                  vertical: isDesktop ? 16 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                ),
              ),
              child: Text(
                "متوجه شدم",
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getAvatarInitials() {
    if (widget.currentUser == null) return "S";
    final user = widget.currentUser!;
    String firstName = user.firstName ?? "";
    String lastName = user.lastName ?? "";

    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return (firstName[0] + lastName[0]).toUpperCase();
    } else if (firstName.isNotEmpty) {
      return firstName[0].toUpperCase();
    } else if (lastName.isNotEmpty) {
      return lastName[0].toUpperCase();
    } else if (user.username.isNotEmpty) {
      return user.username[0].toUpperCase();
    }
    return "S";
  }

  String _getUserFullName() {
    if (widget.currentUser == null) return "کاربر مهمان";
    final user = widget.currentUser!;
    return "${user.firstName ?? ''} ${user.lastName ?? ''}".trim().isEmpty
        ? user.username
        : "${user.firstName ?? ''} ${user.lastName ?? ''}".trim();
  }

  AppTheme _getCurrentThemeEnum(BuildContext context) {
    try {
      final themeCubit = context.read<ThemeCubit>();
      final currentThemeData = themeCubit.state;

      if (currentThemeData == AppThemes.getThemeData(AppTheme.light)) {
        return AppTheme.light;
      }
      if (currentThemeData == AppThemes.getThemeData(AppTheme.solvixAurora)) {
        return AppTheme.solvixAurora;
      }
      return AppTheme.dark;
    } catch (e) {
      print('Error getting current theme: $e');
      return AppTheme.light;
    }
  }
}

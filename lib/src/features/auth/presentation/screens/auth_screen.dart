import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pinput/pinput.dart';
import 'package:solvix/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:solvix/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:solvix/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark
          ? const Color(0xFF0B1426)
          : const Color(0xFFF7F8FC),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure &&
              !(BlocProvider.of<AuthBloc>(context).state is AuthOtpRequired)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.error,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFFE53E3E),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
                elevation: 0,
              ),
            );
          }
        },
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0.0, 0.1),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    ),
                  );
                },
                child: BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthLoading || state is AuthSuccess) {
                      return _buildLoadingState(context);
                    }
                    if (state is AuthOtpRequired) {
                      return OtpVerificationForm(
                        key: ValueKey(
                          'OtpForm_${state.userExists}_${state.otpRequestTimestamp}',
                        ),
                        phoneNumber: state.phoneNumber,
                        userExists: state.userExists,
                        otpRequestTimestamp: state.otpRequestTimestamp,
                      );
                    }
                    return PhoneNumberForm(
                      key: const ValueKey('PhoneForm'),
                      initialError: state is AuthFailure ? state.error : null,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      key: const ValueKey('AuthLoadingOrSuccess'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'در حال ورود...',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class PhoneNumberForm extends StatefulWidget {
  final String? initialError;

  const PhoneNumberForm({super.key, this.initialError});

  @override
  State<PhoneNumberForm> createState() => _PhoneNumberFormState();
}

class _PhoneNumberFormState extends State<PhoneNumberForm> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 24,
        vertical: isDesktop ? 48 : 40,
      ),
      child: Column(
        children: [
          SizedBox(height: isDesktop ? 40 : 60),

          // App Icon - Simple & Clean
          Container(
            width: isDesktop ? 96 : 80,
            height: isDesktop ? 96 : 80,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.25),
                  blurRadius: isDesktop ? 24 : 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.chat_bubble_rounded,
              color: Colors.white,
              size: isDesktop ? 48 : 40,
            ),
          ).animate().scale(
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
          ),

          SizedBox(height: isDesktop ? 40 : 32),

          // Title
          Text(
            'خوش آمدید به سالویکس',
            style: TextStyle(
              fontSize: isDesktop ? 28 : 24,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.2,
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 200)),

          SizedBox(height: isDesktop ? 16 : 12),

          // Subtitle
          Text(
            'شماره موبایل خود را وارد کنید تا بتوانید\nوارد حساب کاربری‌تان شوید',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              height: 1.5,
              color: isDark ? Colors.white60 : Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 300)),

          SizedBox(height: isDesktop ? 56 : 48),

          // Phone Input
          Form(
            key: _formKey,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDesktop ? 0.06 : 0.04),
                    blurRadius: isDesktop ? 12 : 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 17,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: 1,
                ),
                decoration: InputDecoration(
                  hintText: '09XX XXX XXXX',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontWeight: FontWeight.w400,
                  ),
                  counterText: "",
                  prefixIcon: Container(
                    margin: EdgeInsets.all(isDesktop ? 16 : 12),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
                    ),
                    child: Icon(
                      Icons.phone_rounded,
                      color: primaryColor,
                      size: isDesktop ? 22 : 20,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 20 : 16,
                    vertical: isDesktop ? 22 : 18,
                  ),
                  errorText: widget.initialError,
                  errorStyle: TextStyle(
                    fontSize: isDesktop ? 14 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'شماره تلفن نمی‌تواند خالی باشد';
                  if (!RegExp(r'^09[0-9]{9}$').hasMatch(value))
                    return 'فرمت شماره تلفن نامعتبر است';
                  return null;
                },
              ),
            ),
          ).animate().slideY(
            begin: 0.3,
            delay: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          ),

          SizedBox(height: isDesktop ? 32 : 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: isDesktop ? 56 : 52,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                if (_formKey.currentState!.validate()) {
                  context.read<AuthBloc>().add(
                    PhoneNumberSubmitted(_phoneController.text),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                ),
              ),
              child: Text(
                'ادامه',
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ).animate().scale(
            delay: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
          ),

          SizedBox(height: isDesktop ? 40 : 32),

          // Divider
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 16),
                child: Text(
                  'یا',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: isDesktop ? 16 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ],
          ).animate().fadeIn(delay: const Duration(milliseconds: 600)),

          SizedBox(height: isDesktop ? 32 : 24),

          // Google Button
          SizedBox(
            width: double.infinity,
            height: isDesktop ? 56 : 52,
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'این قابلیت به زودی اضافه خواهد شد.',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    backgroundColor: primaryColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(16),
                    elevation: 0,
                  ),
                );
              },
              icon: Container(
                padding: const EdgeInsets.all(2),
                child: const FaIcon(
                  FontAwesomeIcons.google,
                  color: Color(0xFFEA4335),
                  size: 18,
                ),
              ),
              label: Text(
                'ورود با Google',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                ),
                elevation: 0,
              ),
            ),
          ).animate().slideY(
            begin: 0.3,
            delay: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
          ),

          if (isDesktop) const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class OtpVerificationForm extends StatefulWidget {
  final String phoneNumber;
  final bool userExists;
  final int otpRequestTimestamp;

  const OtpVerificationForm({
    super.key,
    required this.phoneNumber,
    required this.userExists,
    required this.otpRequestTimestamp,
  });

  @override
  State<OtpVerificationForm> createState() => _OtpVerificationFormState();
}

class _OtpVerificationFormState extends State<OtpVerificationForm> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _otpErrorTextFromBloc;

  Timer? _timer;
  int _countdownSeconds = 120;
  bool _isOtpExpired = false;
  bool _canResendOtp = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    final DateTime otpSentTime = DateTime.fromMillisecondsSinceEpoch(
      widget.otpRequestTimestamp,
    );
    const Duration otpValidityDuration = Duration(minutes: 2);
    final DateTime otpExpiryTime = otpSentTime.add(otpValidityDuration);
    Duration initialTimeRemaining = otpExpiryTime.difference(DateTime.now());

    if (initialTimeRemaining.isNegative ||
        initialTimeRemaining.inSeconds <= 0) {
      if (mounted) {
        setState(() {
          _countdownSeconds = 0;
          _isOtpExpired = true;
          _canResendOtp = true;
        });
      }
      _otpController.clear();
      return;
    }

    if (mounted) {
      setState(() {
        _countdownSeconds = initialTimeRemaining.inSeconds;
        _isOtpExpired = false;
        _canResendOtp =
            (const Duration(minutes: 2) - initialTimeRemaining).inSeconds >= 30;
      });
    }
    _otpController.clear();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final Duration currentRuntimeRemaining = otpExpiryTime.difference(
        DateTime.now(),
      );
      setState(() {
        if (currentRuntimeRemaining.isNegative ||
            currentRuntimeRemaining.inSeconds <= 0) {
          _countdownSeconds = 0;
          _timer?.cancel();
          _isOtpExpired = true;
          _canResendOtp = true;
        } else {
          _countdownSeconds = currentRuntimeRemaining.inSeconds;
          _canResendOtp =
              (const Duration(minutes: 2) - currentRuntimeRemaining)
                  .inSeconds >=
              30;
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant OtpVerificationForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.otpRequestTimestamp != oldWidget.otpRequestTimestamp) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_isOtpExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.access_time_rounded, color: Colors.white, size: 16),
              SizedBox(width: 12),
              Text(
                'کد تایید منقضی شده است. لطفاً درخواست کد جدید کنید.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFED8936),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 0,
        ),
      );
      return;
    }
    if (!widget.userExists &&
        (_firstNameController.text.trim().isEmpty ||
            _lastNameController.text.trim().isEmpty)) {
      return;
    }
    setState(() {
      _otpErrorTextFromBloc = null;
    });
    if (_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      String? firstName = widget.userExists
          ? null
          : _firstNameController.text.trim();
      String? lastName = widget.userExists
          ? null
          : _lastNameController.text.trim();
      context.read<AuthBloc>().add(
        OtpVerified(
          phoneNumber: widget.phoneNumber,
          otpCode: _otpController.text,
          firstName: firstName,
          lastName: lastName,
        ),
      );
    }
  }

  void _handleResendOtp() {
    if (_canResendOtp) {
      HapticFeedback.lightImpact();
      context.read<AuthBloc>().add(OtpResendRequested(widget.phoneNumber));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.timer_rounded, color: Colors.white, size: 16),
              SizedBox(width: 12),
              Text(
                'پس از ۳۰ ثانیه می‌توانید مجدداً درخواست کد دهید.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final authState = context.watch<AuthBloc>().state;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    if (authState is AuthFailure &&
        mounted &&
        BlocProvider.of<AuthBloc>(context).state is AuthOtpRequired) {
      _otpErrorTextFromBloc = authState.error;
    } else if (authState is! AuthFailure && authState is! AuthLoading) {
      _otpErrorTextFromBloc = null;
    }

    String timerText;
    if (_isOtpExpired) {
      timerText = 'کد منقضی شده';
    } else {
      final minutes = _countdownSeconds ~/ 60;
      final seconds = (_countdownSeconds % 60).toString().padLeft(2, '0');
      timerText = '$minutes:$seconds';
    }

    final defaultPinTheme = PinTheme(
      width: isDesktop ? 56 : 48,
      height: isDesktop ? 64 : 56,
      textStyle: TextStyle(
        fontSize: isDesktop ? 22 : 20,
        color: isDark ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDesktop ? 0.04 : 0.03),
            blurRadius: isDesktop ? 6 : 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 24,
        vertical: isDesktop ? 48 : 40,
      ),
      child: Column(
        children: [
          SizedBox(height: isDesktop ? 24 : 40),

          // Back Button & Title
          Row(
            children: [
              Container(
                width: isDesktop ? 48 : 40,
                height: isDesktop ? 48 : 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.read<AuthBloc>().add(AuthReset());
                  },
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: isDark ? Colors.white70 : Colors.black54,
                    size: isDesktop ? 24 : 20,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
              SizedBox(width: isDesktop ? 20 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تایید شماره تلفن',
                      style: TextStyle(
                        fontSize: isDesktop ? 26 : 22,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: isDesktop ? 4 : 2),
                    Text(
                      widget.phoneNumber,
                      style: TextStyle(
                        fontSize: isDesktop ? 17 : 15,
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ).animate().slideX(begin: -0.2, curve: Curves.easeOutCubic),

          SizedBox(height: isDesktop ? 40 : 32),

          // Description
          Text(
            'کد ۶ رقمی که به شماره شما ارسال شده را وارد کنید',
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.4,
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 100)),

          SizedBox(height: isDesktop ? 40 : 32),

          // Timer
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 16 : 12,
              vertical: isDesktop ? 12 : 8,
            ),
            decoration: BoxDecoration(
              color: _isOtpExpired
                  ? const Color(0xFFED8936).withOpacity(0.1)
                  : primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
              border: Border.all(
                color: _isOtpExpired
                    ? const Color(0xFFED8936).withOpacity(0.3)
                    : primaryColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isOtpExpired ? Icons.timer_off_rounded : Icons.timer_rounded,
                  size: isDesktop ? 18 : 16,
                  color: _isOtpExpired ? const Color(0xFFED8936) : primaryColor,
                ),
                SizedBox(width: isDesktop ? 8 : 6),
                Text(
                  timerText,
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : 13,
                    fontWeight: FontWeight.w600,
                    color: _isOtpExpired
                        ? const Color(0xFFED8936)
                        : primaryColor,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 200)),

          SizedBox(height: isDesktop ? 40 : 32),

          // OTP Input
          Directionality(
            textDirection: TextDirection.ltr,
            child: Form(
              key: _formKey,
              child: Pinput(
                length: 6,
                controller: _otpController,
                autofocus: true,
                enabled: !_isOtpExpired,
                pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                hapticFeedbackType: HapticFeedbackType.lightImpact,
                validator: (pin) {
                  if (pin == null || pin.isEmpty)
                    return 'کد تایید نمی‌تواند خالی باشد';
                  if (pin.length < 6) return 'کد تایید باید ۶ رقم باشد';
                  if (_otpErrorTextFromBloc != null)
                    return _otpErrorTextFromBloc;
                  return null;
                },
                onCompleted: (pin) => _submitForm(),
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(color: primaryColor, width: 2),
                  ),
                ),
                errorPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(
                      color: const Color(0xFFE53E3E),
                      width: 2,
                    ),
                  ),
                ),
                submittedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(
                      color: const Color(0xFF38A169),
                      width: 2,
                    ),
                    color: const Color(0xFF38A169).withOpacity(0.1),
                  ),
                ),
                disabledPinTheme: defaultPinTheme.copyWith(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),
            ),
          ).animate().slideY(
            begin: 0.2,
            delay: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          ),

          if (!widget.userExists) ...[
            SizedBox(height: isDesktop ? 40 : 32),
            _buildTextField(
              controller: _firstNameController,
              label: 'نام',
              icon: Icons.person_outline_rounded,
              enabled: !_isOtpExpired,
              textInputAction: TextInputAction.next,
              isDesktop: isDesktop,
              isDark: isDark,
              primaryColor: primaryColor,
            ).animate().slideX(
              begin: -0.2,
              delay: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
            ),
            SizedBox(height: isDesktop ? 20 : 16),
            _buildTextField(
              controller: _lastNameController,
              label: 'نام خانوادگی',
              icon: Icons.badge_outlined,
              enabled: !_isOtpExpired,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitForm(),
              isDesktop: isDesktop,
              isDark: isDark,
              primaryColor: primaryColor,
            ).animate().slideX(
              begin: 0.2,
              delay: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
            ),
          ],

          SizedBox(height: isDesktop ? 40 : 32),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: isDesktop ? 56 : 52,
            child: ElevatedButton(
              onPressed: _isOtpExpired ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isOtpExpired
                    ? (isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFE2E8F0))
                    : primaryColor,
                foregroundColor: _isOtpExpired
                    ? (isDark ? Colors.white38 : Colors.black38)
                    : Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                ),
              ),
              child: Text(
                'تایید و ادامه',
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ).animate().scale(
            delay: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
          ),

          SizedBox(height: isDesktop ? 32 : 24),

          // Resend Button
          TextButton(
            onPressed: _canResendOtp ? _handleResendOtp : null,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 20 : 16,
                vertical: isDesktop ? 16 : 12,
              ),
            ),
            child: Text(
              'ارسال مجدد کد',
              style: TextStyle(
                color: _canResendOtp
                    ? primaryColor
                    : (isDark ? Colors.white38 : Colors.black38),
                fontSize: isDesktop ? 17 : 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 700)),

          if (isDesktop) SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    required bool isDesktop,
    required bool isDark,
    required Color primaryColor,
    TextInputAction? textInputAction,
    Function(String)? onFieldSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDesktop ? 0.06 : 0.04),
            blurRadius: isDesktop ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        style: TextStyle(
          fontSize: isDesktop ? 18 : 16,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.white54 : Colors.black54,
            fontWeight: FontWeight.w500,
            fontSize: isDesktop ? 16 : 14,
          ),
          prefixIcon: Container(
            margin: EdgeInsets.all(isDesktop ? 16 : 12),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
            ),
            child: Icon(icon, color: primaryColor, size: isDesktop ? 22 : 20),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20 : 16,
            vertical: isDesktop ? 22 : 18,
          ),
          errorStyle: TextStyle(
            fontSize: isDesktop ? 14 : 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        validator: (v) => (v == null || v.trim().isEmpty)
            ? '$label نمی‌تواند خالی باشد'
            : null,
      ),
    );
  }
}

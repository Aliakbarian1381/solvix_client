// lib/src/features/auth/presentation/bloc/auth_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solvix/src/core/api/auth_service.dart';
import 'package:solvix/src/core/models/otp_register_model.dart';
import 'package:solvix/src/core/models/otp_request_model.dart';
import 'package:solvix/src/core/models/otp_verify_model.dart';
import 'package:solvix/src/core/services/storage_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final StorageService _storageService;

  AuthBloc(this._authService, this._storageService) : super(AuthInitial()) {
    on<PhoneNumberSubmitted>(_onPhoneNumberSubmitted);
    on<OtpVerified>(_onOtpVerified);
    on<AuthReset>(_onAuthReset);
    on<FetchCurrentUser>(_onFetchCurrentUser);
    on<OtpResendRequested>(_onOtpResendRequested); // <-- ثبت رویداد جدید
  }

  Future<void> _onPhoneNumberSubmitted(PhoneNumberSubmitted event,
      Emitter<AuthState> emit,) async {
    emit(AuthLoading());
    try {
      final userExists = await _authService.checkPhoneExists(event.phoneNumber);
      await _authService.requestOtp(
        OtpRequestModel(phoneNumber: event.phoneNumber),
      );
      emit(
        AuthOtpRequired(
          phoneNumber: event.phoneNumber,
          userExists: userExists,
          otpRequestTimestamp:
          DateTime
              .now()
              .millisecondsSinceEpoch, // اضافه شد
        ),
      );
    } catch (e) {
      emit(AuthFailure(e.toString().replaceFirst("Exception: ", "")));
    }
  }

  Future<void> _onOtpVerified(OtpVerified event,
      Emitter<AuthState> emit,) async {
    // نگهداری وضعیت فعلی برای بازگشت در صورت خطا
    final previousState = state;
    emit(AuthLoading());
    try {
      final bool isNewUser =
      (event.firstName != null && event.firstName!.isNotEmpty);

      late final user;

      if (isNewUser) {
        user = await _authService.registerWithOtp(
          OtpRegisterModel(
            phoneNumber: event.phoneNumber,
            otpCode: event.otpCode,
            firstName: event.firstName,
            lastName: event.lastName,
          ),
        );
      } else {
        user = await _authService.verifyOtp(
          OtpVerifyModel(
            phoneNumber: event.phoneNumber,
            otpCode: event.otpCode,
          ),
        );
      }

      if (user.token != null) {
        await _storageService.saveToken(user.token!);
      }
      emit(AuthSuccess(user));
    } catch (e) {
      emit(AuthFailure(e.toString().replaceFirst("Exception: ", "")));
      await Future.delayed(const Duration(milliseconds: 100));
      // بازگشت به وضعیت AuthOtpRequired قبلی در صورت خطا
      if (previousState is AuthOtpRequired) {
        emit(previousState);
      } else {
        // اگر state قبلی AuthOtpRequired نبود، یک state جدید بساز
        // این حالت معمولا نباید اتفاق بیفتد اگر کاربر از فرم OTP آمده باشد
        bool userExistsCurrentValue = false;
        if (event.firstName == null || event.firstName!.isEmpty) {
          userExistsCurrentValue = true; // فرض بر اینکه کاربر قدیمی بوده
        }
        emit(
          AuthOtpRequired(
            phoneNumber: event.phoneNumber,
            userExists: userExistsCurrentValue,
            // استفاده از timestamp قبلی یا یک timestamp جدید
            otpRequestTimestamp: (previousState is AuthOtpRequired)
                ? previousState.otpRequestTimestamp
                : DateTime
                .now()
                .millisecondsSinceEpoch,
          ),
        );
      }
    }
  }

  void _onAuthReset(AuthReset event, Emitter<AuthState> emit) {
    emit(AuthInitial());
  }

  Future<void> _onFetchCurrentUser(FetchCurrentUser event,
      Emitter<AuthState> emit,) async {
    emit(AuthLoading());
    try {
      final user = await _authService.getCurrentUser();
      emit(AuthSuccess(user));
    } catch (e) {
      await _storageService.deleteToken();
      emit(AuthFailure(e.toString().replaceFirst("Exception: ", "")));
    }
  }

  // -- هندلر برای ارسال مجدد کد --
  Future<void> _onOtpResendRequested(OtpResendRequested event,
      Emitter<AuthState> emit,) async {
    // نگهداری اطلاعات userExists از state فعلی اگر AuthOtpRequired باشد
    bool currentUserExists = false;
    if (state is AuthOtpRequired) {
      currentUserExists = (state as AuthOtpRequired).userExists;
    }

    emit(AuthLoading()); // نمایش حالت لودینگ موقت
    try {
      await _authService.requestOtp(
        OtpRequestModel(phoneNumber: event.phoneNumber),
      );
      // بازگشت به AuthOtpRequired با timestamp جدید برای ریست تایمر در UI
      emit(
        AuthOtpRequired(
          phoneNumber: event.phoneNumber,
          userExists: currentUserExists, // استفاده از مقدار قبلی
          otpRequestTimestamp: DateTime
              .now()
              .millisecondsSinceEpoch,
        ),
      );
    } catch (e) {
      emit(AuthFailure(e.toString().replaceFirst("Exception: ", "")));
      // در صورت خطا، به state قبلی AuthOtpRequired برگرد (با timestamp قبلی)
      // تا کاربر همچنان بتواند کد قبلی را وارد کند اگر هنوز معتبر است یا دوباره تلاش کند
      await Future.delayed(const Duration(milliseconds: 100));
      emit(
        AuthOtpRequired(
          phoneNumber: event.phoneNumber,
          userExists: currentUserExists,
          otpRequestTimestamp: (state is AuthOtpRequired)
              ? (state as AuthOtpRequired)
              .otpRequestTimestamp // اگر خطا داد ولی state عوض شده بود
              : DateTime
              .now()
              .millisecondsSinceEpoch -
              120000, // یک timestamp قدیمی‌تر
        ),
      );
    }
  }

// ----------------------------
}

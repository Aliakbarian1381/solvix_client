import 'package:equatable/equatable.dart';
import 'package:solvix/src/core/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthOtpRequired extends AuthState {
  final String phoneNumber;
  final bool userExists;

  // پارامتر جدید برای کمک به ریست تایمر در UI
  // این می‌تواند یک DateTime باشد یا صرفاً یک int که با هر بار ارسال مجدد تغییر کند.
  // استفاده از DateTime.now().millisecondsSinceEpoch برای سادگی مناسب است.
  final int otpRequestTimestamp;

  const AuthOtpRequired({
    required this.phoneNumber,
    required this.userExists,
    required this.otpRequestTimestamp, // اضافه شده
  });

  @override
  List<Object> get props => [phoneNumber, userExists, otpRequestTimestamp];

  // یک copyWith برای راحتی
  AuthOtpRequired copyWith({
    String? phoneNumber,
    bool? userExists,
    int? otpRequestTimestamp,
  }) {
    return AuthOtpRequired(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      userExists: userExists ?? this.userExists,
      otpRequestTimestamp: otpRequestTimestamp ?? this.otpRequestTimestamp,
    );
  }
}

class AuthSuccess extends AuthState {
  final UserModel user;

  const AuthSuccess(this.user);

  @override
  List<Object> get props => [user];
}

class AuthFailure extends AuthState {
  final String error;

  const AuthFailure(this.error);

  @override
  List<Object> get props => [error];
}

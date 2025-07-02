import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class PhoneNumberSubmitted extends AuthEvent {
  final String phoneNumber;

  const PhoneNumberSubmitted(this.phoneNumber);

  @override
  List<Object> get props => [phoneNumber];
}

class OtpVerified extends AuthEvent {
  final String phoneNumber;
  final String otpCode;
  final String? firstName;
  final String? lastName;

  const OtpVerified({
    required this.phoneNumber,
    required this.otpCode,
    this.firstName,
    this.lastName,
  });

  @override
  List<Object?> get props => [phoneNumber, otpCode, firstName, lastName];
}

class AuthReset extends AuthEvent {}

class FetchCurrentUser extends AuthEvent {}

// -- رویداد جدید برای درخواست ارسال مجدد کد --
class OtpResendRequested extends AuthEvent {
  final String phoneNumber;

  const OtpResendRequested(this.phoneNumber);

  @override
  List<Object> get props => [phoneNumber];
}

// -----------------------------------------

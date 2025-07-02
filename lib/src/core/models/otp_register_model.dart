class OtpRegisterModel {
  final String phoneNumber;
  final String otpCode;
  final String? firstName;
  final String? lastName;

  OtpRegisterModel({
    required this.phoneNumber,
    required this.otpCode,
    this.firstName,
    this.lastName,
  });

  Map<String, dynamic> toJson() {
    return {
      'phoneNumber': phoneNumber,
      'otpCode': otpCode,
      'firstName': firstName,
      'lastName': lastName,
    };
  }
}

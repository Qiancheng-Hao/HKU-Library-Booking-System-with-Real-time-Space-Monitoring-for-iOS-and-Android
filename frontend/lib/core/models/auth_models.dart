import 'json_helpers.dart';

class LoginResponse {
  final String accessToken;

  const LoginResponse({required this.accessToken});

  factory LoginResponse.fromJson(JsonMap json) {
    return LoginResponse(
      accessToken: readFirstString(json, const ['access_token', 'accessToken']),
    );
  }
}

class UserProfile {
  final String? fullName;
  final String? email;

  const UserProfile({this.fullName, this.email});

  factory UserProfile.fromJson(JsonMap json) {
    return UserProfile(
      fullName: json['full_name']?.toString() ?? json['fullName']?.toString(),
      email: json['email']?.toString(),
    );
  }
}

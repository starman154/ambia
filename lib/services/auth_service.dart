import 'dart:convert';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Cognito configuration
  static const String _userPoolId = 'us-east-2_pHrIr0dLE';
  static const String _clientId = '72niboepljn3n7rbdjspl2vp2f';
  static const String _region = 'us-east-2';

  late CognitoUserPool _userPool;
  CognitoUser? _cognitoUser;
  final _storage = const FlutterSecureStorage();

  // Storage keys
  static const String _keyAccessToken = 'access_token';
  static const String _keyIdToken = 'id_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyEmail = 'user_email';
  static const String _keyLastActivity = 'last_activity';

  // 14 days inactivity timeout
  static const int _inactivityDays = 14;

  void initialize() {
    _userPool = CognitoUserPool(_userPoolId, _clientId);
  }

  /// Sign up a new user with email and password
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final userAttributes = [
        AttributeArg(name: 'email', value: email),
      ];

      final result = await _userPool.signUp(
        email,
        password,
        userAttributes: userAttributes,
      );

      return {
        'success': true,
        'userConfirmed': result.userConfirmed,
        'userSub': result.userSub,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Confirm sign up with verification code
  Future<Map<String, dynamic>> confirmSignUp({
    required String email,
    required String code,
  }) async {
    try {
      final cognitoUser = CognitoUser(email, _userPool);
      final result = await cognitoUser.confirmRegistration(code);

      return {
        'success': result,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Resend verification code
  Future<Map<String, dynamic>> resendVerificationCode(String email) async {
    try {
      final cognitoUser = CognitoUser(email, _userPool);
      await cognitoUser.resendConfirmationCode();

      return {
        'success': true,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Sign in with email and password
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _cognitoUser = CognitoUser(email, _userPool);
      final authDetails = AuthenticationDetails(
        username: email,
        password: password,
      );

      final session = await _cognitoUser!.authenticateUser(authDetails);

      if (session != null && session.isValid()) {
        // Store tokens securely
        await _storage.write(key: _keyAccessToken, value: session.getAccessToken().getJwtToken());
        await _storage.write(key: _keyIdToken, value: session.getIdToken().getJwtToken());
        await _storage.write(key: _keyRefreshToken, value: session.getRefreshToken()?.getToken());
        await _storage.write(key: _keyEmail, value: email);

        // Set initial last activity timestamp
        await updateLastActivity();

        return {
          'success': true,
          'userId': session.getIdToken().decodePayload()['sub'],
        };
      }

      return {
        'success': false,
        'error': 'Invalid session',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Update last activity timestamp
  Future<void> updateLastActivity() async {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    await _storage.write(key: _keyLastActivity, value: now);
  }

  /// Check if user has been inactive for more than 14 days
  Future<bool> _isInactive() async {
    try {
      final lastActivityStr = await _storage.read(key: _keyLastActivity);
      if (lastActivityStr == null) {
        // No activity recorded yet - set it now and treat as active
        await updateLastActivity();
        return false;
      }

      final lastActivity = DateTime.fromMillisecondsSinceEpoch(
        int.parse(lastActivityStr),
      );
      final now = DateTime.now();
      final daysSinceLastActivity = now.difference(lastActivity).inDays;

      return daysSinceLastActivity >= _inactivityDays;
    } catch (e) {
      // On error, set activity timestamp and treat as active
      await updateLastActivity();
      return false;
    }
  }

  /// Check if user is currently signed in
  Future<bool> isSignedIn() async {
    try {
      // Check for inactivity timeout
      if (await _isInactive()) {
        await signOut(); // Auto sign out if inactive for 14 days
        return false;
      }

      final email = await _storage.read(key: _keyEmail);
      if (email == null) return false;

      final accessToken = await _storage.read(key: _keyAccessToken);
      final idToken = await _storage.read(key: _keyIdToken);
      final refreshToken = await _storage.read(key: _keyRefreshToken);

      if (accessToken == null || idToken == null || refreshToken == null) {
        return false;
      }

      // Create user and restore session from stored tokens
      _cognitoUser = CognitoUser(email, _userPool);

      // Create session from stored tokens
      final cognitoSession = CognitoUserSession(
        CognitoIdToken(idToken),
        CognitoAccessToken(accessToken),
        refreshToken: CognitoRefreshToken(refreshToken),
      );

      // Use refresh token to get a fresh session if tokens are expired
      CognitoUserSession? session;
      try {
        // Try refreshing the session with the stored refresh token
        session = await _cognitoUser!.refreshSession(CognitoRefreshToken(refreshToken));
      } catch (e) {
        // If refresh fails, try using the existing session
        session = cognitoSession.isValid() ? cognitoSession : null;
      }

      if (session != null && session.isValid()) {
        // Update stored tokens if they were refreshed
        await _storage.write(
          key: _keyAccessToken,
          value: session.getAccessToken().getJwtToken(),
        );
        await _storage.write(
          key: _keyIdToken,
          value: session.getIdToken().getJwtToken(),
        );

        // Update activity timestamp on successful validation
        await updateLastActivity();
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get current user's email
  Future<String?> getUserEmail() async {
    return await _storage.read(key: _keyEmail);
  }

  /// Get current user's ID token (JWT)
  Future<String?> getIdToken() async {
    try {
      final idToken = await _storage.read(key: _keyIdToken);
      if (idToken != null) {
        return idToken;
      }

      // Try to refresh the session
      final email = await _storage.read(key: _keyEmail);
      if (email != null) {
        _cognitoUser = CognitoUser(email, _userPool);
        final session = await _cognitoUser!.getSession();

        if (session != null && session.isValid()) {
          final newIdToken = session.getIdToken().getJwtToken();
          await _storage.write(key: _keyIdToken, value: newIdToken);
          return newIdToken;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get current user's ID (sub claim from JWT)
  Future<String?> getUserId() async {
    try {
      final idToken = await getIdToken();
      if (idToken == null) return null;

      // Decode JWT to get user ID from 'sub' claim
      final parts = idToken.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = json.decode(decoded) as Map<String, dynamic>;

      return map['sub'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      if (_cognitoUser != null) {
        await _cognitoUser!.signOut();
      }
    } catch (e) {
      // Continue with local sign out even if Cognito sign out fails
    }

    // Clear stored tokens and activity
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyIdToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyLastActivity);

    _cognitoUser = null;
  }

  /// Forgot password - initiate password reset
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final cognitoUser = CognitoUser(email, _userPool);
      await cognitoUser.forgotPassword();

      return {
        'success': true,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Confirm forgot password with verification code and new password
  Future<Map<String, dynamic>> confirmForgotPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final cognitoUser = CognitoUser(email, _userPool);
      await cognitoUser.confirmPassword(code, newPassword);

      return {
        'success': true,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

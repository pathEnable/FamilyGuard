import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? token;

  AuthState({
    this.isLoading = true,
    this.isAuthenticated = false,
    this.token,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? token,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    checkStatus();
    return AuthState();
  }

  Future<void> checkStatus() async {
    final token = await ApiService.getToken();
    state = state.copyWith(
      isLoading: false,
      isAuthenticated: token != null,
      token: token,
    );
  }

  Future<void> setToken(String token) async {
    await ApiService.setToken(token);
    state = state.copyWith(
      isAuthenticated: true,
      token: token,
    );
  }

  Future<void> logout() async {
    await ApiService.logout();
    state = state.copyWith(
      isAuthenticated: false,
      token: null,
    );
  }
}

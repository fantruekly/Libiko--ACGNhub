import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/database.dart';
import 'account_api.dart';
import 'account_models.dart';

const kDefaultBaseUrl = 'http://127.0.0.1:8080';
const _kBaseUrl = 'account_base_url';
const _kToken = 'account_token';
const _kRefreshToken = 'account_refresh_token';
const _kUser = 'account_user';

class AccountState {
  final String baseUrl;
  final AccountUser? user;
  final bool loading;
  final String? error;

  const AccountState({
    required this.baseUrl,
    this.user,
    this.loading = false,
    this.error,
  });

  bool get isLoggedIn => user != null;

  AccountState copyWith({
    String? baseUrl,
    AccountUser? user,
    bool? loading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AccountState(
      baseUrl: baseUrl ?? this.baseUrl,
      user: clearUser ? null : (user ?? this.user),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AccountNotifier extends Notifier<AccountState> {
  AccountNotifier({AccountApi Function(String baseUrl)? apiFactory})
      : _apiFactory = apiFactory ?? ((baseUrl) => AccountApi(baseUrl));

  final AccountApi Function(String baseUrl) _apiFactory;

  @override
  AccountState build() {
    final db = AppDatabase();
    AccountUser? user;
    final userJson = db.getString(_kUser);
    if (userJson != null) {
      try {
        user = AccountUser.fromJson(
            json.decode(userJson) as Map<String, dynamic>);
      } catch (_) {
        user = null;
      }
    }
    return AccountState(
      baseUrl: db.getString(_kBaseUrl) ?? kDefaultBaseUrl,
      user: user,
    );
  }

  String? get token => AppDatabase().getString(_kToken);

  Future<void> setBaseUrl(String url) async {
    final normalized = url.trim().replaceAll(RegExp(r'/+$'), '');
    await AppDatabase().setString(_kBaseUrl, normalized);
    state = state.copyWith(baseUrl: normalized);
  }

  Future<void> register(String username, String password) =>
      _authenticate((api) => api.register(username, password));

  Future<void> login(String username, String password) =>
      _authenticate((api) => api.login(username, password));

  Future<void> _authenticate(
      Future<AuthSession> Function(AccountApi api) call) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final session = await call(_apiFactory(state.baseUrl));
      final db = AppDatabase();
      await db.setString(_kToken, session.token);
      await db.setString(_kRefreshToken, session.refreshToken);
      await db.setString(_kUser, json.encode(session.user.toJson()));
      state = state.copyWith(
          loading: false, user: session.user, clearError: true);
    } on AccountException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(loading: false, error: '登录失败，请重试');
    }
  }

  Future<void> logout() async {
    final db = AppDatabase();
    await db.remove(_kToken);
    await db.remove(_kRefreshToken);
    await db.remove(_kUser);
    state = state.copyWith(clearUser: true, clearError: true);
  }

  Future<bool> refreshSession() async {
    final db = AppDatabase();
    final refreshToken = db.getString(_kRefreshToken);
    if (refreshToken == null) {
      await logout();
      return false;
    }
    try {
      final newToken = await _apiFactory(state.baseUrl).refresh(refreshToken);
      await db.setString(_kToken, newToken);
      return true;
    } on AccountException catch (e) {
      if (e.statusCode == 401) await logout();
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> load() async {
    final db = AppDatabase();
    final storedToken = db.getString(_kToken);
    if (storedToken == null) return;

    state = state.copyWith(loading: true, clearError: true);
    final user = await _validateSession(db, storedToken);
    state = state.copyWith(
        loading: false, user: user, clearUser: user == null);
  }

  /// Validates [storedToken], refreshing once on a 401. Returns the user, or
  /// `null` when the session cannot be validated. A transient failure clears
  /// the in-memory user but leaves the stored session intact so a later
  /// [load] can retry.
  Future<AccountUser?> _validateSession(
      AppDatabase db, String storedToken) async {
    try {
      final user = await _apiFactory(state.baseUrl).me(storedToken);
      await db.setString(_kUser, json.encode(user.toJson()));
      return user;
    } on AccountException catch (e) {
      if (e.statusCode != 401) return null;
    } catch (_) {
      return null;
    }

    if (!await refreshSession()) return null;
    final refreshed = token;
    if (refreshed == null) return null;
    try {
      final user = await _apiFactory(state.baseUrl).me(refreshed);
      await db.setString(_kUser, json.encode(user.toJson()));
      return user;
    } catch (_) {
      return null;
    }
  }
}

final accountProvider =
    NotifierProvider<AccountNotifier, AccountState>(() => AccountNotifier());

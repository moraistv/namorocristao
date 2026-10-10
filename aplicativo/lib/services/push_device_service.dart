import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/token_storage.dart';

class PushCleanupResult {
  final bool remoteRemovalPending;
  final bool localTokenInvalidated;
  final Object? remoteError;
  final Object? localError;

  const PushCleanupResult({
    required this.remoteRemovalPending,
    required this.localTokenInvalidated,
    this.remoteError,
    this.localError,
  });

  bool get fullyCleaned =>
      !remoteRemovalPending && localTokenInvalidated && localError == null;
}

class PushRegistrationResult {
  final bool registered;
  final bool skipped;
  final bool cleanupPending;

  const PushRegistrationResult({
    required this.registered,
    required this.skipped,
    required this.cleanupPending,
  });
}

class _RemoteCleanupResult {
  final List<PendingFcmRemoval> confirmed;
  final Object? error;

  const _RemoteCleanupResult(this.confirmed, this.error);
}

class _LocalCleanupResult {
  final bool invalidated;
  final List<PendingFcmRemoval> targets;
  final Object? preparationError;
  final Object? error;

  const _LocalCleanupResult({
    required this.invalidated,
    required this.targets,
    this.preparationError,
    this.error,
  });
}

/// Coordena registro e remoção do device push sem perder limpezas remotas.
class PushDeviceService {
  PushDeviceService._();

  static const _interactiveWait = Duration(seconds: 6);
  static const _logoutWait = Duration(seconds: 2);
  static const _fcmLookupWait = Duration(seconds: 2);

  static Future<void> _operationQueue = Future<void>.value();
  static Future<void> _localInvalidationFlight = Future<void>.value();
  static int _intentGeneration = 0;

  static Future<T> _enqueue<T>(Future<T> Function() operation) {
    final future = _operationQueue.then<T>(
      (_) => operation(),
      onError: (Object _, StackTrace __) => operation(),
    );
    _operationQueue = future.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return future;
  }

  static bool _sameSession(int generation, String? userId) {
    return TokenStorage.isLoggedIn &&
        TokenStorage.isCurrentSession(generation) &&
        TokenStorage.userId == userId;
  }

  static bool _belongsToUser(PendingFcmRemoval pending, String? userId) {
    return pending.userId == null || pending.userId == userId;
  }

  static bool _sameRemoval(
    PendingFcmRemoval first,
    PendingFcmRemoval second,
  ) {
    return first.token == second.token && first.userId == second.userId;
  }

  static Future<_RemoteCleanupResult> _retryPendingForSession(
    int generation,
    String? userId,
  ) async {
    Object? firstError;
    final confirmed = <PendingFcmRemoval>[];
    final pending = <PendingFcmRemoval>[
      for (final item in TokenStorage.pendingFcmRemovals)
        if (_belongsToUser(item, userId)) item,
    ];

    for (final item in pending) {
      if (!_sameSession(generation, userId)) break;
      try {
        await AppApi.removeDevice(item.token);
        confirmed.add(item);
      } catch (error) {
        firstError ??= error;
        if (!_sameSession(generation, userId)) break;
      }
    }

    for (final item in confirmed) {
      try {
        await TokenStorage.clearPendingFcmRemoval(
          token: item.token,
          userId: item.userId,
        );
      } catch (error) {
        firstError ??= error;
      }
    }
    return _RemoteCleanupResult(confirmed, firstError);
  }

  static Future<PushCleanupResult> retryPendingRemoval() {
    final generation = TokenStorage.sessionGeneration;
    final userId = TokenStorage.userId;
    return _enqueue(() async {
      final remote = await _retryPendingForSession(generation, userId);
      final stillPending = TokenStorage.pendingFcmRemovals.any(
        (item) => _belongsToUser(item, userId),
      );
      return PushCleanupResult(
        remoteRemovalPending: stillPending,
        localTokenInvalidated: true,
        remoteError: remote.error,
      );
    });
  }

  static Future<_LocalCleanupResult> _prepareAndInvalidateLocal({
    required int generation,
    required String? userId,
    required String? expectedStoredToken,
    required bool lookupSdkToken,
  }) async {
    final targets = <PendingFcmRemoval>[];
    Object? preparationError;

    void addTarget(PendingFcmRemoval target) {
      if (!targets.any((item) => _sameRemoval(item, target))) {
        targets.add(target);
      }
    }

    try {
      for (final item in TokenStorage.pendingFcmRemovals) {
        if (_belongsToUser(item, userId)) addTarget(item);
      }

      final tokens = <String>{};
      if (expectedStoredToken != null && expectedStoredToken.isNotEmpty) {
        tokens.add(expectedStoredToken);
      } else if (lookupSdkToken) {
        try {
          final sdkToken = await FirebaseMessaging.instance
              .getToken()
              .timeout(_fcmLookupWait);
          if (sdkToken != null && sdkToken.isNotEmpty) tokens.add(sdkToken);
        } catch (_) {
          // deleteToken ainda deve ser aguardado mesmo sem lookup disponível.
        }
      }

      for (final token in tokens) {
        final target = PendingFcmRemoval(token: token, userId: userId);
        await TokenStorage.setPendingFcmRemoval(token: token, userId: userId);
        addTarget(target);
      }
    } catch (error) {
      preparationError = error;
    }

    Object? localError;
    var invalidated = false;
    try {
      await FirebaseMessaging.instance.deleteToken();
      invalidated = true;
    } catch (error) {
      localError = error;
    }
    try {
      await TokenStorage.clearFcmTokenIfCurrent(
        expectedGeneration: generation,
        expectedUserId: userId,
        expectedToken: expectedStoredToken,
      );
    } catch (error) {
      localError ??= error;
    }

    return _LocalCleanupResult(
      invalidated: invalidated,
      targets: List<PendingFcmRemoval>.unmodifiable(targets),
      preparationError: preparationError,
      error: localError,
    );
  }

  static Future<_LocalCleanupResult> _scheduleLocalInvalidation({
    required int generation,
    required String? userId,
    required String? expectedStoredToken,
    required bool lookupSdkToken,
  }) {
    final previous = _localInvalidationFlight;
    final future = previous.then<_LocalCleanupResult>(
      (_) => _prepareAndInvalidateLocal(
        generation: generation,
        userId: userId,
        expectedStoredToken: expectedStoredToken,
        lookupSdkToken: lookupSdkToken,
      ),
      onError: (Object _, StackTrace __) => _prepareAndInvalidateLocal(
        generation: generation,
        userId: userId,
        expectedStoredToken: expectedStoredToken,
        lookupSdkToken: lookupSdkToken,
      ),
    );
    _localInvalidationFlight = future.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return future;
  }

  static Future<void> _waitForLocalInvalidations() async {
    while (true) {
      final flight = _localInvalidationFlight;
      await flight;
      if (identical(flight, _localInvalidationFlight)) return;
    }
  }

  /// Executa apenas I/O remoto com a credencial capturada. Esta future pode
  /// sobreviver ao timeout sem ler ou alterar Firebase/Hive depois do retorno.
  static Future<_RemoteCleanupResult> _removeTargetsRemotely(
    List<PendingFcmRemoval> targets,
    String accessToken,
  ) async {
    final confirmed = <PendingFcmRemoval>[];
    Object? firstError;
    for (final item in targets) {
      try {
        await AppApi.removeDeviceForCleanup(
          item.token,
          accessToken: accessToken,
        );
        confirmed.add(item);
      } catch (error) {
        firstError ??= error;
      }
    }
    return _RemoteCleanupResult(confirmed, firstError);
  }

  static Future<_RemoteCleanupResult> _safeRemoteCleanup(
    List<PendingFcmRemoval> targets,
    String accessToken,
  ) async {
    try {
      return await _removeTargetsRemotely(targets, accessToken);
    } catch (error) {
      return _RemoteCleanupResult(const <PendingFcmRemoval>[], error);
    }
  }

  static Future<PushCleanupResult> _finishCleanup({
    required String? accessToken,
    required String? userId,
    required Duration maxRemoteWait,
    required Future<_LocalCleanupResult> localFuture,
  }) async {
    final local = await localFuture;
    var remote = const _RemoteCleanupResult(<PendingFcmRemoval>[], null);
    final credential = accessToken?.trim();
    if (local.targets.isNotEmpty &&
        credential != null &&
        credential.isNotEmpty) {
      remote = await _safeRemoteCleanup(local.targets, credential).timeout(
        maxRemoteWait,
        onTimeout: () => _RemoteCleanupResult(
          const <PendingFcmRemoval>[],
          TimeoutException("Remoção remota de push pendente"),
        ),
      );
    }

    Object? persistenceError;
    for (final item in remote.confirmed) {
      try {
        await TokenStorage.clearPendingFcmRemoval(
          token: item.token,
          userId: item.userId,
        );
      } catch (error) {
        persistenceError ??= error;
      }
    }

    bool stillPending;
    try {
      stillPending = local.preparationError != null ||
          TokenStorage.pendingFcmRemovals.any(
            (item) => _belongsToUser(item, userId),
          );
    } catch (error) {
      persistenceError ??= error;
      stillPending = true;
    }

    return PushCleanupResult(
      remoteRemovalPending: stillPending,
      localTokenInvalidated: local.invalidated,
      remoteError: remote.error ?? local.preparationError ?? persistenceError,
      localError: local.error,
    );
  }

  static Future<PushCleanupResult> _startCleanup(Duration maxRemoteWait) {
    final generation = TokenStorage.sessionGeneration;
    final userId = TokenStorage.userId;
    final accessToken = TokenStorage.accessToken;
    final storedToken = TokenStorage.fcmToken;
    final localFuture = _scheduleLocalInvalidation(
      generation: generation,
      userId: userId,
      expectedStoredToken: storedToken,
      lookupSdkToken: true,
    );
    return _finishCleanup(
      accessToken: accessToken,
      userId: userId,
      maxRemoteWait: maxRemoteWait,
      localFuture: localFuture,
    );
  }

  static Future<PushCleanupResult> disableNotifications() async {
    _intentGeneration++;
    final preferenceFuture = TokenStorage.setNotificationsEnabled(false);
    final cleanupFuture = _startCleanup(_interactiveWait);
    Object? preferenceError;
    try {
      await preferenceFuture;
    } catch (error) {
      preferenceError = error;
    }
    final cleanup = await cleanupFuture;
    if (preferenceError == null) return cleanup;
    return PushCleanupResult(
      remoteRemovalPending: true,
      localTokenInvalidated: cleanup.localTokenInvalidated,
      remoteError: cleanup.remoteError ?? preferenceError,
      localError: cleanup.localError,
    );
  }

  static Future<PushCleanupResult> cleanupForLogout() {
    _intentGeneration++;
    return _startCleanup(_logoutWait);
  }

  /// Expiração já removeu a credencial. Apenas invalida o token Firebase local
  /// e mantém as pendências persistidas por TokenStorage para retry futuro.
  static Future<PushCleanupResult> cleanupForSessionTermination() {
    _intentGeneration++;
    final generation = TokenStorage.sessionGeneration;
    final userId = TokenStorage.userId;
    final storedToken = TokenStorage.fcmToken;
    final localFuture = _scheduleLocalInvalidation(
      generation: generation,
      userId: userId,
      expectedStoredToken: storedToken,
      lookupSdkToken: false,
    );
    return localFuture.then(
      (local) => PushCleanupResult(
        remoteRemovalPending: TokenStorage.pendingFcmRemovals.isNotEmpty,
        localTokenInvalidated: local.invalidated,
        remoteError: local.preparationError,
        localError: local.error,
      ),
    );
  }

  static Future<PushCleanupResult> reconcileDisabledNotifications() {
    if (TokenStorage.notificationsEnabled) {
      return Future<PushCleanupResult>.value(
        const PushCleanupResult(
          remoteRemovalPending: false,
          localTokenInvalidated: true,
        ),
      );
    }
    if (TokenStorage.fcmToken != null ||
        TokenStorage.pendingFcmRemovals.isNotEmpty) {
      return _startCleanup(_interactiveWait);
    }
    return Future<PushCleanupResult>.value(
      const PushCleanupResult(
        remoteRemovalPending: false,
        localTokenInvalidated: true,
      ),
    );
  }

  static Future<PushRegistrationResult> registerToken(
    String token, {
    required String platform,
  }) {
    final requestedToken = token.trim();
    final intent = _intentGeneration;
    final generation = TokenStorage.sessionGeneration;
    final userId = TokenStorage.userId;

    return _enqueue(() async {
      if (requestedToken.isEmpty ||
          platform.isEmpty ||
          intent != _intentGeneration ||
          !TokenStorage.notificationsEnabled ||
          !_sameSession(generation, userId)) {
        return PushRegistrationResult(
          registered: false,
          skipped: true,
          cleanupPending: TokenStorage.pendingFcmRemovals.isNotEmpty,
        );
      }

      await _waitForLocalInvalidations();
      if (intent != _intentGeneration ||
          !TokenStorage.notificationsEnabled ||
          !_sameSession(generation, userId)) {
        return PushRegistrationResult(
          registered: false,
          skipped: true,
          cleanupPending: TokenStorage.pendingFcmRemovals.isNotEmpty,
        );
      }

      String registrationToken;
      try {
        registrationToken = (await FirebaseMessaging.instance
                    .getToken()
                    .timeout(_fcmLookupWait))
                ?.trim() ??
            "";
      } catch (_) {
        registrationToken = "";
      }
      if (registrationToken.isEmpty ||
          intent != _intentGeneration ||
          !TokenStorage.notificationsEnabled ||
          !_sameSession(generation, userId)) {
        return PushRegistrationResult(
          registered: false,
          skipped: true,
          cleanupPending: TokenStorage.pendingFcmRemovals.isNotEmpty,
        );
      }

      final matchingWasPending = TokenStorage.pendingFcmRemovals.any(
        (item) => item.token == registrationToken,
      );
      await _retryPendingForSession(generation, userId);
      if (intent != _intentGeneration ||
          !TokenStorage.notificationsEnabled ||
          !_sameSession(generation, userId)) {
        return PushRegistrationResult(
          registered: false,
          skipped: true,
          cleanupPending: TokenStorage.pendingFcmRemovals.isNotEmpty,
        );
      }

      final previous = TokenStorage.fcmToken;
      if (previous == registrationToken && !matchingWasPending) {
        return PushRegistrationResult(
          registered: true,
          skipped: false,
          cleanupPending: TokenStorage.pendingFcmRemovals.isNotEmpty,
        );
      }

      if (previous != null && previous != registrationToken) {
        await TokenStorage.setPendingFcmRemoval(
          token: previous,
          userId: userId,
        );
        await _retryPendingForSession(generation, userId);
      }

      await TokenStorage.setPendingFcmRemoval(
        token: registrationToken,
        userId: userId,
      );
      if (intent != _intentGeneration ||
          !TokenStorage.notificationsEnabled ||
          !_sameSession(generation, userId)) {
        return PushRegistrationResult(
          registered: false,
          skipped: true,
          cleanupPending: true,
        );
      }

      await AppApi.registerDevice(registrationToken, platform: platform);
      if (intent != _intentGeneration ||
          !TokenStorage.notificationsEnabled ||
          !_sameSession(generation, userId)) {
        return PushRegistrationResult(
          registered: false,
          skipped: true,
          cleanupPending: true,
        );
      }

      final stored = await TokenStorage.setFcmTokenIfCurrent(
        expectedGeneration: generation,
        expectedUserId: userId,
        token: registrationToken,
      );
      if (!stored ||
          intent != _intentGeneration ||
          !TokenStorage.notificationsEnabled ||
          !_sameSession(generation, userId)) {
        return const PushRegistrationResult(
          registered: false,
          skipped: true,
          cleanupPending: true,
        );
      }

      // Um POST confirmado move/atualiza o token no backend para esta conta.
      // Limpezas do mesmo token, inclusive de uma conta anterior, ficam obsoletas.
      final matchingPending = TokenStorage.pendingFcmRemovals
          .where((item) => item.token == registrationToken)
          .toList(growable: false);
      for (final pending in matchingPending) {
        await TokenStorage.clearPendingFcmRemoval(
          token: pending.token,
          userId: pending.userId,
        );
      }

      return PushRegistrationResult(
        registered: true,
        skipped: false,
        cleanupPending: TokenStorage.pendingFcmRemovals.isNotEmpty,
      );
    });
  }
}

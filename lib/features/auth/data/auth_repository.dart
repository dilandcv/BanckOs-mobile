import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/session/auth_session.dart';
import 'package:mobile/core/storage/secure_session_store.dart';
import 'package:mobile/features/tenants/data/tenant.dart';

/// Identidad vigente según `/auth/me`.
class CurrentIdentity {
  const CurrentIdentity({required this.user, required this.tenant});

  final UserSummary user;
  final TenantSummary tenant;
}

/// Única puerta de entrada a autenticación y sesiones multi-banco.
class AuthRepository {
  AuthRepository(this._api, this._store);

  final ApiClient _api;
  final SecureSessionStore _store;

  /// Inicio de sesión único global para BankOS (sin tenant_code).
  Future<MasterSession> loginMaster({
    required String email,
    required String password,
  }) async {
    final envelope = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.authLogin,
      data: <String, dynamic>{
        'email': email.trim().toLowerCase(),
        'password': password,
      },
      parse: (raw) => (raw as Map).cast<String, dynamic>(),
    );

    final data = envelope.data;
    if (data == null) {
      throw ApiException.network('El servidor no devolvió datos de sesión');
    }

    final token = (data['access_token'] as String?) ?? '';
    final masterUserJson = (data['master_user'] as Map?)?.cast<String, dynamic>() ??
        (data['user'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    final banksRaw = (data['linked_banks'] as List?) ?? const [];
    final linkedBanks = banksRaw
        .map((item) => LinkedBankModel.fromJson((item as Map).cast<String, dynamic>()))
        .toList();

    final masterSession = MasterSession(
      accessToken: token,
      tokenType: (data['token_type'] as String?) ?? 'Bearer',
      expiresIn: (data['expires_in'] as num?)?.toInt() ?? 7200,
      user: MasterUserSummary.fromJson(masterUserJson),
      linkedBanks: linkedBanks,
    );

    await _store.saveMasterSession(masterSession);
    return masterSession;
  }

  /// Canjea el Master Token por un token contextual del banco especificado.
  Future<AuthSession> exchangeBankToken(String tenantCode) async {
    final envelope = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.authExchangeBankToken,
      data: <String, dynamic>{
        'tenant_code': tenantCode.trim().toUpperCase(),
      },
      parse: (raw) => (raw as Map).cast<String, dynamic>(),
    );

    final data = envelope.data;
    if (data == null) {
      throw ApiException.network('El servidor no devolvió datos del banco');
    }

    final session = AuthSession.fromLogin(data);
    await _store.saveSession(session);
    await _store.setActiveTenant(session.tenant.code);
    return session;
  }

  /// Consulta la lista actualizada de bancos vinculados.
  Future<List<LinkedBankModel>> getLinkedBanks() async {
    final envelope = await _api.get<List<dynamic>>(
      ApiEndpoints.userBanks,
      parse: (raw) => raw as List<dynamic>,
    );

    final data = envelope.data ?? const [];
    return data
        .map((item) => LinkedBankModel.fromJson((item as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Consulta los bancos disponibles para vincular en la plataforma.
  Future<List<LinkedBankModel>> getAvailableBanks() async {
    final envelope = await _api.get<List<dynamic>>(
      ApiEndpoints.banksAvailable,
      parse: (raw) => raw as List<dynamic>,
    );

    final data = envelope.data ?? const [];
    return data.map((item) {
      final map = (item as Map).cast<String, dynamic>();
      return LinkedBankModel(
        linkId: '',
        tenantId: (map['tenant_id'] as String?) ?? '',
        tenantCode: (map['code'] as String?) ?? '',
        tenantName: (map['name'] as String?) ?? '',
        primaryColor: (map['primary_color'] as String?) ?? '#0B1F3A',
        secondaryColor: (map['secondary_color'] as String?) ?? '#0070BA',
        logoUrl: map['logo_url'] as String?,
        accountNickname: (map['name'] as String?) ?? '',
        accountNumberMask: '',
        isDefault: false,
        authStatus: (map['is_linked'] as bool?) == true ? 'CONNECTED' : 'AVAILABLE',
      );
    }).toList();
  }

  /// Vincula una nueva cuenta bancaria al usuario autenticado.
  Future<LinkedBankModel> linkBank({
    required String tenantCode,
    String? accountNickname,
    String? accountType,
    String? consentToken,
  }) async {
    final envelope = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.banksLink,
      data: <String, dynamic>{
        'tenant_code': tenantCode.trim().toUpperCase(),
        if (accountNickname != null && accountNickname.isNotEmpty)
          'account_nickname': accountNickname,
        if (accountType != null && accountType.isNotEmpty)
          'account_type': accountType,
        if (consentToken != null) 'consent_token': consentToken,
      },
      parse: (raw) => (raw as Map).cast<String, dynamic>(),
    );

    final data = envelope.data;
    if (data == null) {
      throw ApiException.network('No se pudo vincular la cuenta bancaria');
    }

    return LinkedBankModel.fromJson(data);
  }

  /// Desvincula una entidad bancaria.
  Future<void> unlinkBank(String linkId) async {
    await _api.delete<dynamic>(
      ApiEndpoints.userBankById(linkId),
    );
  }

  /// Establece una cuenta como predeterminada.
  Future<void> setDefaultBank(String linkId) async {
    await _api.patch<dynamic>(
      ApiEndpoints.userBankDefault(linkId),
    );
  }

  /// Reautoriza una cuenta bancaria.
  Future<LinkedBankModel> reauthorizeBank(String linkId) async {
    final envelope = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.userBankReauthorize(linkId),
      parse: (raw) => (raw as Map).cast<String, dynamic>(),
    );
    final data = envelope.data;
    if (data == null) throw ApiException.network('Error al reautorizar');
    return LinkedBankModel.fromJson(data);
  }

  /// Login legacy por tenant (retrocompatibilidad).
  Future<AuthSession> login({
    required String tenantCode,
    required String email,
    required String password,
  }) async {
    final envelope = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.authLogin,
      data: <String, dynamic>{
        'tenant_code': tenantCode.trim().toUpperCase(),
        'email': email.trim(),
        'password': password,
      },
      parse: (raw) => (raw as Map).cast<String, dynamic>(),
    );

    final data = envelope.data;
    if (data == null) {
      throw ApiException.network('El servidor no devolvió datos de sesión');
    }

    final session = AuthSession.fromLogin(data);
    await _store.saveSession(session);
    await _store.setActiveTenant(session.tenant.code);
    return session;
  }

  /// Registro público contextual de cliente por banco.
  ///
  /// Crea el usuario en el banco, el cliente asociado, su cuenta de ahorros inicial
  /// y emite su primera tarjeta digital activa.
  Future<AuthSession> registerCustomer({
    required String tenantCode,
    required String email,
    required String password,
    required String fullName,
    required String documentType,
    required String documentNumber,
  }) async {
    final envelope = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.authRegister,
      data: <String, dynamic>{
        'tenant_code': tenantCode.trim().toUpperCase(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'full_name': fullName.trim(),
        'document_type': documentType.trim().toUpperCase(),
        'document_number': documentNumber.trim(),
      },
      parse: (raw) => (raw as Map).cast<String, dynamic>(),
    );

    final data = envelope.data;
    if (data == null) {
      throw ApiException.network('El servidor no devolvió datos de sesión tras el registro');
    }

    final session = AuthSession.fromLogin(data);
    await _store.saveSession(session);
    await _store.setActiveTenant(session.tenant.code);
    return session;
  }

  /// Lista pública de instituciones financieras activas (accesible sin token previo).
  Future<List<TenantModel>> getPublicTenants() async {
    final envelope = await _api.get<List<dynamic>>(
      ApiEndpoints.tenantsPublic,
      parse: (raw) => raw as List<dynamic>,
    );

    final data = envelope.data ?? const [];
    return data
        .map((item) => TenantModel.fromJson((item as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Actualización de colores o URL de logo de una entidad bancaria.
  Future<TenantModel> updateTenantBranding({
    required String tenantId,
    String? primaryColor,
    String? secondaryColor,
    String? logoUrl,
  }) async {
    final envelope = await _api.patch<Map<String, dynamic>>(
      ApiEndpoints.tenantBranding(tenantId),
      data: <String, dynamic>{
        if (primaryColor != null) 'primary_color': primaryColor,
        if (secondaryColor != null) 'secondary_color': secondaryColor,
        if (logoUrl != null) 'logo_url': logoUrl,
      },
      parse: (raw) => (raw as Map).cast<String, dynamic>(),
    );

    final data = envelope.data;
    if (data == null) {
      throw ApiException.network('El servidor no devolvió datos actualizados de la institución');
    }

    return TenantModel.fromJson(data);
  }

  /// Subida de logotipo en formato imagen/foto mediante multipart form data.
  Future<TenantModel> uploadTenantLogo({
    required String tenantId,
    required List<int> fileBytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: filename),
    });

    final envelope = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.tenantLogo(tenantId),
      data: formData,
      parse: (raw) => (raw as Map).cast<String, dynamic>(),
    );

    final data = envelope.data;
    if (data == null) {
      throw ApiException.network('El servidor no devolvió respuesta al subir el logo');
    }

    return TenantModel.fromJson(data);
  }

  /// Valida el token activo contra el backend y devuelve la identidad real.
  Future<CurrentIdentity> me() async {
    final envelope = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.authMe,
      parse: (raw) => (raw as Map).cast<String, dynamic>(),
    );

    final data = envelope.data;
    if (data == null) {
      throw ApiException.network('El servidor no devolvió la identidad');
    }

    final userJson =
        (data['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final tenantJson =
        (data['tenant'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    return CurrentIdentity(
      user: UserSummary.fromJson(userJson),
      tenant: TenantSummary.fromJson(tenantJson),
    );
  }

  Future<MasterSession?> restoreMasterSession() => _store.readMasterSession();

  Future<AuthSession?> restoreSession() => _store.readActiveSession();

  Future<bool> hasSession(String tenantCode) async {
    return await _store.readSession(tenantCode) != null;
  }

  Future<AuthSession> switchTenant(String tenantCode) async {
    final code = tenantCode.trim().toUpperCase();
    final session = await _store.readSession(code);
    if (session == null || session.isExpired()) {
      // Si no hay token en caché o expiró, lo canjea dinámicamente con el master token
      return exchangeBankToken(code);
    }
    await _store.setActiveTenant(code);
    return session;
  }

  Future<List<AuthSession>> getSessions() async {
    final sessions = <AuthSession>[];
    for (final code in await _store.tenantCodes()) {
      final session = await _store.readSession(code);
      if (session != null) sessions.add(session);
    }
    return sessions;
  }

  Future<String?> activeTenantCode() => _store.getActiveTenant();

  Future<void> logoutActive() => _store.clearActiveTenant();

  Future<void> logoutTenant(String tenantCode) =>
      _store.removeSession(tenantCode);

  Future<void> logoutAll() => _store.clearAll();

  Future<bool> isBiometricEnabled(String tenantCode) =>
      _store.isBiometricEnabled(tenantCode);

  Future<void> setBiometricEnabled(String tenantCode, bool enabled) =>
      _store.setBiometricEnabled(tenantCode, enabled);

  Future<bool> isMasterBiometricEnabled() => _store.isMasterBiometricEnabled();

  Future<void> setMasterBiometricEnabled(bool enabled) =>
      _store.setMasterBiometricEnabled(enabled);
}

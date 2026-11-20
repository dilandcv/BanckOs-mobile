import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/config/api_config.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/providers.dart';
import 'package:mobile/core/theme/tenant_theme.dart';
import 'package:mobile/features/portal/presentation/bank_portal_screen.dart';
import 'package:mobile/features/tenants/data/tenant.dart';
import 'package:mobile/features/tenants/data/tenants_providers.dart';
import 'package:mobile/shared/constants/app_colors.dart';

/// Pantalla de Autenticación Contextual por Banco (`BankAuthScreen`).
///
/// Adopta inmediatamente la identidad corporativa y colores del banco seleccionado,
/// ofreciendo dos pestañas:
/// 1. Iniciar Sesión (con mensaje pedagógico de aislamiento si el usuario no pertenece a la entidad).
/// 2. Crear Cuenta / Registrarse (emitiendo atómicamente cuenta y tarjeta digital).
class BankAuthScreen extends ConsumerStatefulWidget {
  const BankAuthScreen({
    super.key,
    required this.tenantCode,
    this.initialTenant,
  });

  final String tenantCode;
  final TenantModel? initialTenant;

  @override
  ConsumerState<BankAuthScreen> createState() => _BankAuthScreenState();
}

class _BankAuthScreenState extends ConsumerState<BankAuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Formulario Login
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginLoading = false;
  bool _loginObscurePassword = true;
  String? _loginError;
  bool _isIsolationError = false;

  // Formulario Registro
  final _fullNameController = TextEditingController();
  final _docNumberController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  String _documentType = 'CC';
  bool _regLoading = false;
  bool _regObscurePassword = true;
  String? _regError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _fullNameController.dispose();
    _docNumberController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  TenantModel _resolveTenant(WidgetRef ref) {
    if (widget.initialTenant != null) return widget.initialTenant!;

    final publicTenants = ref.watch(publicTenantsProvider).value ?? const [];
    for (final t in publicTenants) {
      if (t.code.toUpperCase() == widget.tenantCode.toUpperCase()) return t;
    }

    for (final t in BankPortalScreen.fallbackBanks) {
      if (t.code.toUpperCase() == widget.tenantCode.toUpperCase()) return t;
    }

    return TenantModel(
      id: widget.tenantCode.toLowerCase(),
      code: widget.tenantCode.toUpperCase(),
      name: widget.tenantCode,
      status: 'ACTIVE',
      primaryColor: '#0070BA',
      secondaryColor: '#003087',
      logoUrl: null,
    );
  }

  static String _resolveLogoUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final trimmed = raw.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final host = ApiConfig.baseUrl.replaceAll('/api/v1', '');
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$host$path';
  }

  Future<void> _submitLogin(TenantModel tenant) async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _loginError = 'Por favor ingresa correo y contraseña.';
        _isIsolationError = false;
      });
      return;
    }

    setState(() {
      _loginLoading = true;
      _loginError = null;
      _isIsolationError = false;
    });

    try {
      final session = await ref.read(authRepositoryProvider).login(
            tenantCode: tenant.code,
            email: email,
            password: password,
          );

      await ref.read(sessionControllerProvider.notifier).setSession(session);

      if (!mounted) return;
      context.go('/dashboard');
    } on ApiException catch (error) {
      // Detección de error de aislamiento estricto: credenciales no existen en este tenant
      final isAuthFailure = error.statusCode == 401 ||
          error.code == 'INVALID_CREDENTIALS' ||
          error.displayMessage.toLowerCase().contains('credencial') ||
          error.displayMessage.toLowerCase().contains('no encontrado');

      setState(() {
        _isIsolationError = isAuthFailure;
        _loginError = isAuthFailure
            ? 'No encontramos una cuenta con estas credenciales en ${tenant.name}. '
                'Recuerda que cada banco opera de forma aislada e independiente en BankOS. '
                'Si creaste tu cuenta en otro banco (ej. Bancolombia o Nu), debes '
                'abrir una cuenta nueva en esta entidad para acceder.'
            : error.displayMessage;
      });
    } catch (_) {
      setState(() {
        _isIsolationError = false;
        _loginError = 'No se pudo conectar con el banco ${tenant.name}. Intenta de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _loginLoading = false);
    }
  }

  Future<void> _submitRegister(TenantModel tenant) async {
    final fullName = _fullNameController.text.trim();
    final docNumber = _docNumberController.text.trim();
    final email = _regEmailController.text.trim();
    final password = _regPasswordController.text;

    if (fullName.isEmpty || docNumber.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _regError = 'Por favor completa todos los campos requeridos.');
      return;
    }

    if (password.length < 8) {
      setState(() => _regError = 'La contraseña debe tener al menos 8 caracteres.');
      return;
    }

    setState(() {
      _regLoading = true;
      _regError = null;
    });

    try {
      final session = await ref.read(authRepositoryProvider).registerCustomer(
            tenantCode: tenant.code,
            email: email,
            password: password,
            fullName: fullName,
            documentType: _documentType,
            documentNumber: docNumber,
          );

      await ref.read(sessionControllerProvider.notifier).setSession(session);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¡Bienvenido a ${tenant.name}! Tu cuenta de ahorros y tarjeta digital están listas.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      context.go('/dashboard');
    } on ApiException catch (error) {
      setState(() => _regError = error.displayMessage);
    } catch (_) {
      setState(() => _regError = 'No se pudo registrar la cuenta en ${tenant.name}.');
    } finally {
      if (mounted) setState(() => _regLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = _resolveTenant(ref);
    final primaryColor =
        TenantTheme.parseHex(tenant.primaryColor) ?? AppColors.primary;
    final secondaryColor =
        TenantTheme.parseHex(tenant.secondaryColor) ?? AppColors.primaryDark;

    final isLightPrimary = primaryColor.computeLuminance() > 0.55;
    final onPrimaryColor = isLightPrimary ? const Color(0xFF1E293B) : Colors.white;
    final logoUrl = _resolveLogoUrl(tenant.logoUrl);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Cambiar de Banco',
          onPressed: () => context.go('/portal'),
        ),
        title: TextButton.icon(
          onPressed: () => context.go('/portal'),
          icon: const Icon(Icons.swap_horiz, size: 18, color: Color(0xFF38BDF8)),
          label: const Text(
            'Cambiar de Banco',
            style: TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              backgroundColor: const Color(0xFF334155),
              label: Text(
                tenant.code.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner con Identidad Corporativa del Banco
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Logo o avatar
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: logoUrl.isNotEmpty
                            ? Image.network(
                                logoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _DefaultBankAvatar(
                                  name: tenant.name,
                                  color: secondaryColor,
                                ),
                              )
                            : _DefaultBankAvatar(
                                name: tenant.name,
                                color: secondaryColor,
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tenant.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: onPrimaryColor,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Portal Digital y Banca Segura',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: onPrimaryColor.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, size: 13, color: onPrimaryColor),
                            const SizedBox(width: 5),
                            Text(
                              'Aislamiento Criptográfico Multi-Tenant',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: onPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Selector de Pestañas (Login vs Registro)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: onPrimaryColor,
                    unselectedLabelColor: const Color(0xFF94A3B8),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.login, size: 18),
                        text: 'Iniciar Sesión',
                      ),
                      Tab(
                        icon: Icon(Icons.person_add_alt_1, size: 18),
                        text: 'Crear Cuenta',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Contenedor de Formulario
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      return _tabController.index == 0
                          ? _buildLoginForm(tenant, primaryColor, onPrimaryColor)
                          : _buildRegisterForm(tenant, primaryColor, onPrimaryColor);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(TenantModel tenant, Color primaryColor, Color onPrimaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Accede a tu banca digital',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ingresa tus credenciales registradas en ${tenant.name}.',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 20),

        // Banner pedagógico de Aislamiento si ocurrió un fallo
        if (_loginError != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isIsolationError
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                  : const Color(0xFFEF4444).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isIsolationError
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFEF4444),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _isIsolationError ? Icons.info_outline : Icons.error_outline,
                      color: _isIsolationError
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFFF87171),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _loginError!,
                        style: TextStyle(
                          fontSize: 13,
                          color: _isIsolationError
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFFFECACA),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isIsolationError) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() => _loginError = null);
                        _tabController.animateTo(1);
                      },
                      icon: const Icon(Icons.person_add, size: 16, color: Color(0xFFFBBF24)),
                      label: Text(
                        'Crear cuenta en ${tenant.name} →',
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Campo Email
        const Text(
          'Correo Electrónico',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _loginEmailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'ejemplo@banco.com',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Campo Contraseña
        const Text(
          'Contraseña',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _loginPasswordController,
          obscureText: _loginObscurePassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Tu contraseña secreta',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF94A3B8)),
            suffixIcon: IconButton(
              icon: Icon(
                _loginObscurePassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF94A3B8),
              ),
              onPressed: () => setState(() => _loginObscurePassword = !_loginObscurePassword),
            ),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Botón Submit Login
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _loginLoading ? null : () => _submitLogin(tenant),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: onPrimaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            child: _loginLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(
                    'Ingresar a ${tenant.name}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(TenantModel tenant, Color primaryColor, Color onPrimaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Abre tu cuenta bancaria',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Recibe al instante tu cuenta de ahorros y tu tarjeta digital activa en ${tenant.name}.',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 18),

        if (_regError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF4444)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFF87171), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _regError!,
                    style: const TextStyle(color: Color(0xFFFECACA), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Nombre Completo
        const Text(
          'Nombre Completo',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _fullNameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ej. Juan Camilo Pérez',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Tipo y Número de Documento (en fila)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tipo Doc.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _documentType,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'CC', child: Text('CC')),
                      DropdownMenuItem(value: 'CE', child: Text('CE')),
                      DropdownMenuItem(value: 'PASAPORTE', child: Text('PAS')),
                      DropdownMenuItem(value: 'NIT', child: Text('NIT')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _documentType = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Número de Documento',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _docNumberController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '1098765432',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      prefixIcon: const Icon(Icons.numbers, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Correo Electrónico
        const Text(
          'Correo Electrónico',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _regEmailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'tu.correo@ejemplo.com',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Contraseña
        const Text(
          'Contraseña (mínimo 8 caracteres)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _regPasswordController,
          obscureText: _regObscurePassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Crea tu contraseña segura',
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF94A3B8)),
            suffixIcon: IconButton(
              icon: Icon(
                _regObscurePassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF94A3B8),
              ),
              onPressed: () => setState(() => _regObscurePassword = !_regObscurePassword),
            ),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Botón Submit Registro
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _regLoading ? null : () => _submitRegister(tenant),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: onPrimaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            child: _regLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(
                    'Abrir Cuenta y Tarjeta en ${tenant.name}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }
}

class _DefaultBankAvatar extends StatelessWidget {
  const _DefaultBankAvatar({
    required this.name,
    required this.color,
  });

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'B';
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

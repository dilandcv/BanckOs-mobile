import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/config/api_config.dart';
import 'package:mobile/core/providers.dart';
import 'package:mobile/core/theme/tenant_theme.dart';
import 'package:mobile/features/tenants/data/tenant.dart';
import 'package:mobile/features/tenants/data/tenants_providers.dart';
import 'package:mobile/shared/constants/app_colors.dart';

/// Portal Principal de Bancos de BankOS.
///
/// Expone visualmente todas las instituciones financieras activas creadas en
/// la plataforma (ej. Bancolombia, Nu, Daviplata, Nequi, Banco Horizonte), con
/// sus colores corporativos, logotipo y acceso contextualizado.
class BankPortalScreen extends ConsumerWidget {
  const BankPortalScreen({super.key});

  /// Bancos por defecto preconfigurados en el ecosistema para previsualización inmediata.
  static const List<TenantModel> fallbackBanks = [
    TenantModel(
      id: 'tenant-bancolombia',
      code: 'BANCOLOMBIA',
      name: 'Bancolombia',
      status: 'ACTIVE',
      primaryColor: '#FDDA24',
      secondaryColor: '#1D1D1B',
      logoUrl: null,
    ),
    TenantModel(
      id: 'tenant-nu',
      code: 'NU',
      name: 'Nu Bank',
      status: 'ACTIVE',
      primaryColor: '#820AD1',
      secondaryColor: '#4C0677',
      logoUrl: null,
    ),
    TenantModel(
      id: 'tenant-daviplata',
      code: 'DAVIPLATA',
      name: 'Daviplata',
      status: 'ACTIVE',
      primaryColor: '#ED1C24',
      secondaryColor: '#A80006',
      logoUrl: null,
    ),
    TenantModel(
      id: 'tenant-nequi',
      code: 'NEQUI',
      name: 'Nequi',
      status: 'ACTIVE',
      primaryColor: '#1F0433',
      secondaryColor: '#DA0081',
      logoUrl: null,
    ),
    TenantModel(
      id: 'tenant-horizonte',
      code: 'BANCO_HORIZONTE',
      name: 'Banco Horizonte',
      status: 'ACTIVE',
      primaryColor: '#0070BA',
      secondaryColor: '#003087',
      logoUrl: null,
    ),
  ];

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publicTenantsAsync = ref.watch(publicTenantsProvider);

    // Si el backend responde bancos activos, los combinamos asegurando que los fallbacks
    // existan si aún no se han creado en BD.
    final dynamicTenants = publicTenantsAsync.value ?? const <TenantModel>[];
    final activeTenants = <TenantModel>[];

    if (dynamicTenants.isNotEmpty) {
      activeTenants.addAll(dynamicTenants);
      // Agregar fallbacks cuyos códigos no estén ya en dynamicTenants
      final existingCodes = dynamicTenants.map((t) => t.code.toUpperCase()).toSet();
      for (final fallback in fallbackBanks) {
        if (!existingCodes.contains(fallback.code.toUpperCase())) {
          activeTenants.add(fallback);
        }
      }
    } else {
      activeTenants.addAll(fallbackBanks);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900 para una estética fintech premium
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0070BA), Color(0xFF00C6FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0070BA).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'BankOS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981), // Emerald active
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Portal Multi-Banco Core',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.admin_panel_settings, size: 18, color: Color(0xFF38BDF8)),
              label: const Text(
                'Plataforma Admin',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(publicTenantsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E293B),
                          const Color(0xFF0F172A).withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF334155),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified, size: 13, color: Color(0xFF10B981)),
                                  SizedBox(width: 5),
                                  Text(
                                    'Ecosistema Aislado Multi-Tenant',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Selecciona tu Entidad Financiera',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Cada banco cuenta con su propia identidad visual corporativa, emisión '
                          'de tarjetas digitales EMV y estricto aislamiento criptográfico de datos.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Sección de Bancos Disponibles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bancos del Ecosistema',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${activeTenants.length} Entidades Activas',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Cuadrícula de tarjetas bancarias
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 640;
                      return GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: activeTenants.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWide ? 2 : 1,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 220,
                        ),
                        itemBuilder: (context, index) {
                          final tenant = activeTenants[index];
                          return _BankCard(
                            tenant: tenant,
                            onTap: () {
                              context.go(
                                '/bank/${tenant.code}',
                                extra: tenant,
                              );
                            },
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 36),

                  // Footer de seguridad y aislamiento
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 16, color: Color(0xFF64748B)),
                          SizedBox(width: 8),
                          Text(
                            'Seguridad BankOS: Las cuentas de un banco no pueden operar en otro banco sin registro previo.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({
    required this.tenant,
    required this.onTap,
  });

  final TenantModel tenant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryColor =
        TenantTheme.parseHex(tenant.primaryColor) ?? AppColors.primary;
    final secondaryColor =
        TenantTheme.parseHex(tenant.secondaryColor) ?? AppColors.primaryDark;

    // Determinar legibilidad sobre el color del banco
    final isLightPrimary = primaryColor.computeLuminance() > 0.55;
    final onPrimaryColor = isLightPrimary ? const Color(0xFF1E293B) : Colors.white;

    final logoUrl = BankPortalScreen._resolveLogoUrl(tenant.logoUrl);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF334155),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Banner corporativo superior con gradiente de la entidad
            Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo o Avatar representativo
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
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
                  const SizedBox(width: 14),
                  // Nombre e institución
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          tenant.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: onPrimaryColor,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tenant.code.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: onPrimaryColor.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badge "Banco Activo"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 7, color: Color(0xFF10B981)),
                        SizedBox(width: 4),
                        Text(
                          'Activo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Cuerpo de la tarjeta
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.credit_card, size: 15, color: Color(0xFF94A3B8)),
                        SizedBox(width: 6),
                        Text(
                          'Cuenta Ahorros · Tarjeta Débito Digital',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Acceso Seguro',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'Operar en ${tenant.name}',
                              style: TextStyle(
                                color: primaryColor.computeLuminance() > 0.4
                                    ? const Color(0xFF38BDF8)
                                    : primaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: primaryColor.computeLuminance() > 0.4
                                  ? const Color(0xFF38BDF8)
                                  : primaryColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/providers.dart';
import 'package:mobile/core/theme/tenant_theme.dart';
import 'package:mobile/features/cards/data/card_model.dart';
import 'package:mobile/shared/constants/app_colors.dart';

/// Componente visual hiperrealista y premium de tarjeta bancaria.
///
/// Soporta:
/// - Gradiente dinámico con colores corporativos del banco activo.
/// - Chip EMV metálico dorado con circuito interno.
/// - Símbolo de pago sin contacto (Contactless NFC).
/// - Logo/nombre del banco activo y badge de franquicia (Mastercard / Visa).
/// - Número de tarjeta con toggle para revelar/ocultar dígitos.
/// - Nombre del titular, fecha de vencimiento y CVV dinámico.
/// - Badge de estado: "Activa" o "Bloqueada / Congelada" con feedback visual.
class CardVisualWidget extends ConsumerStatefulWidget {
  const CardVisualWidget({
    super.key,
    required this.card,
    this.bankName,
    this.bankLogoUrl,
    this.primaryColor,
    this.secondaryColor,
    this.isCompact = false,
    this.onTap,
    this.showActions = true,
  });

  final CardModel card;
  final String? bankName;
  final String? bankLogoUrl;
  final Color? primaryColor;
  final Color? secondaryColor;
  final bool isCompact;
  final VoidCallback? onTap;
  final bool showActions;

  @override
  ConsumerState<CardVisualWidget> createState() => _CardVisualWidgetState();
}

class _CardVisualWidgetState extends ConsumerState<CardVisualWidget> {
  bool _showNumber = false;
  bool _showCvv = false;

  void _toggleNumber() {
    setState(() {
      _showNumber = !_showNumber;
    });
  }

  void _toggleCvv() {
    setState(() {
      _showCvv = !_showCvv;
    });
  }

  String _formatNumber(String number, bool reveal) {
    final clean = number.replaceAll(' ', '');
    final last4 = clean.length >= 4 ? clean.substring(clean.length - 4) : '••••';

    if (!reveal) {
      return '••••  ••••  ••••  $last4';
    }

    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write('  ');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(sessionControllerProvider).value;
    final tenantTheme = ref.watch(tenantThemeProvider);

    final resolvedBankName = widget.bankName ??
        activeSession?.tenant.name ??
        tenantTheme.tenantName ??
        'BankOS';

    final resolvedLogoUrl = widget.bankLogoUrl ??
        activeSession?.tenant.logoUrl ??
        tenantTheme.logoUrl;

    final primary = widget.primaryColor ??
        (activeSession != null
            ? TenantTheme.parseHex(activeSession.tenant.primaryColor)
            : null) ??
        tenantTheme.primary;

    final secondary = widget.secondaryColor ??
        (activeSession != null
            ? TenantTheme.parseHex(activeSession.tenant.secondaryColor)
            : null) ??
        tenantTheme.secondary;

    final isCompact = widget.isCompact;
    final card = widget.card;
    final isBlocked = card.isBlocked;

    final cardHeight = isCompact ? 172.0 : 216.0;

    return Semantics(
      label: 'Tarjeta ${card.cardType} de $resolvedBankName terminada en ${card.cardNumber.length >= 4 ? card.cardNumber.substring(card.cardNumber.length - 4) : ""}',
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: cardHeight,
          margin: EdgeInsets.symmetric(
            horizontal: isCompact ? 0 : 4,
            vertical: isCompact ? 2 : 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primary,
                secondary,
                Color.lerp(secondary, Colors.black, 0.25) ?? secondary,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.35),
                blurRadius: isCompact ? 10 : 16,
                offset: Offset(0, isCompact ? 4 : 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // Textura visual sutil y patrones geométricos premium
                Positioned(
                  top: -50,
                  right: -40,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -60,
                  left: -30,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.12),
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 90,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.04),
                        width: 2,
                      ),
                    ),
                  ),
                ),

                // Contenido de la tarjeta
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 16 : 20,
                    vertical: isCompact ? 12 : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Header superior: Nombre del Banco / Logo + Badge de Estado
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Logo o Nombre del Banco
                          Expanded(
                            child: Row(
                              children: [
                                if (resolvedLogoUrl != null &&
                                    resolvedLogoUrl.isNotEmpty) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      resolvedLogoUrl,
                                      height: isCompact ? 20 : 26,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          _buildBankText(resolvedBankName, isCompact),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ] else
                                  _buildBankText(resolvedBankName, isCompact),
                              ],
                            ),
                          ),
                          // Badge de Estado (Activa / Congelada)
                          _buildStatusBadge(isBlocked: isBlocked, isCompact: isCompact),
                        ],
                      ),

                      // Fila Intermedia: Chip EMV dorado + Símbolo Contactless
                      Row(
                        children: [
                          _buildEmvChip(isCompact: isCompact),
                          const SizedBox(width: 12),
                          _buildContactlessSymbol(isCompact: isCompact),
                          const Spacer(),
                          // Tipo de tarjeta (DÉBITO / CRÉDITO)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              card.cardType.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: isCompact ? 9 : 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Número de tarjeta con espaciado en 4 bloques y botón de ojo
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _formatNumber(card.cardNumber, _showNumber),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isCompact ? 14 : 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: isCompact ? 1.5 : 2.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.4),
                                    offset: const Offset(1, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (widget.showActions)
                            InkWell(
                              onTap: _toggleNumber,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  _showNumber
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.white.withOpacity(0.85),
                                  size: isCompact ? 17 : 20,
                                ),
                              ),
                            ),
                        ],
                      ),

                      // Footer: Nombre del titular, Expiración, CVV dinámico y Franquicia
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Titular
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'TITULAR',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.65),
                                    fontSize: isCompact ? 8 : 9,
                                    letterSpacing: 0.8,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  card.cardholderName.isNotEmpty
                                      ? card.cardholderName.toUpperCase()
                                      : (activeSession?.user.fullName ?? 'CLIENTE BANKOS').toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isCompact ? 11 : 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Vence (MM/YY)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'VENCE',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.65),
                                    fontSize: isCompact ? 8 : 9,
                                    letterSpacing: 0.8,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  card.expirationDate.isNotEmpty
                                      ? card.expirationDate
                                      : '12/28',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isCompact ? 11 : 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // CVV con tap para revelar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: InkWell(
                              onTap: widget.showActions ? _toggleCvv : null,
                              borderRadius: BorderRadius.circular(4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'CVV',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.65),
                                      fontSize: isCompact ? 8 : 9,
                                      letterSpacing: 0.8,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    _showCvv ? card.cvvMasked.replaceAll('*', '7') : '•••',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isCompact ? 11 : 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Badge de Franquicia (Mastercard / Visa)
                          _buildFranchiseBadge(
                            cardNumber: card.cardNumber,
                            cardType: card.cardType,
                            isCompact: isCompact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Capa visual de congelada / bloqueada si aplica
                if (isBlocked)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.38),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.lock, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'TARJETA CONGELADA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBankText(String name, bool isCompact) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.account_balance,
          color: Colors.white.withOpacity(0.9),
          size: isCompact ? 16 : 18,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isCompact ? 13 : 15,
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge({required bool isBlocked, required bool isCompact}) {
    if (isBlocked) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 6 : 8,
          vertical: isCompact ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: isCompact ? 10 : 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              'Bloqueada',
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 9 : 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF81C784), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF81C784),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Activa',
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 9 : 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmvChip({required bool isCompact}) {
    final width = isCompact ? 34.0 : 42.0;
    final height = isCompact ? 24.0 : 30.0;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFDF7D),
            Color(0xFFD4AF37),
            Color(0xFFAA8010),
            Color(0xFFFFE699),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFB8860B).withOpacity(0.7),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 3,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: width * 0.72,
              height: height * 0.72,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF7A5809).withOpacity(0.55),
                  width: 0.6,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: height * 0.48,
            child: Container(
              height: 0.6,
              color: const Color(0xFF7A5809).withOpacity(0.55),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: width * 0.5,
            child: Container(
              width: 0.6,
              color: const Color(0xFF7A5809).withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactlessSymbol({required bool isCompact}) {
    return Transform.rotate(
      angle: 90 * (math.pi / 180),
      child: Icon(
        Icons.wifi,
        color: Colors.white.withOpacity(0.85),
        size: isCompact ? 18 : 22,
      ),
    );
  }

  Widget _buildFranchiseBadge({
    required String cardNumber,
    required String cardType,
    required bool isCompact,
  }) {
    final clean = cardNumber.replaceAll(' ', '');
    final isVisa = clean.startsWith('4') || cardType.toUpperCase().contains('VISA');

    if (isVisa) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 6 : 8,
          vertical: isCompact ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'VISA',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 15 : 18,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 1.5,
          ),
        ),
      );
    }

    // Mastercard (Círculos superpuestos)
    final circleSize = isCompact ? 16.0 : 20.0;
    return SizedBox(
      width: circleSize * 1.55,
      height: circleSize,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: Container(
              width: circleSize,
              height: circleSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEB001B),
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF79E1B).withOpacity(0.92),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

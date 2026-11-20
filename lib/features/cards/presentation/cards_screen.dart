import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/providers.dart';
import 'package:mobile/features/accounts/data/accounts_providers.dart';
import 'package:mobile/features/cards/data/card_model.dart';
import 'package:mobile/features/cards/data/cards_providers.dart';
import 'package:mobile/features/cards/presentation/card_visual_widget.dart';
import 'package:mobile/shared/constants/app_colors.dart';
import 'package:mobile/shared/widgets/app_scaffold.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

/// Pantalla completa de gestión y visualización de Tarjetas Bancarias del Cliente.
class CardsScreen extends ConsumerStatefulWidget {
  const CardsScreen({super.key});

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _selectedCardIndex = 0;
  bool _isTogglingStatus = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _toggleCardStatus(CardModel card) async {
    if (_isTogglingStatus) return;

    final newStatus = card.isActive ? 'BLOCKED' : 'ACTIVE';
    setState(() => _isTogglingStatus = true);

    try {
      await ref.read(cardsRepositoryProvider).toggleCardStatus(
            cardId: card.id,
            newStatus: newStatus,
          );

      ref.read(dataVersionProvider.notifier).state++;
      ref.invalidate(cardsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'BLOCKED'
                ? 'Tarjeta congelada exitosamente. Se han deshabilitado compras y retiros.'
                : 'Tarjeta reactivada exitosamente. Lista para usar.',
          ),
          backgroundColor:
              newStatus == 'BLOCKED' ? AppColors.warning : AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al modificar estado de la tarjeta: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isTogglingStatus = false);
    }
  }

  void _copyCardData(CardModel card) {
    final cleanNumber = card.cardNumber.replaceAll(' ', '');
    final data = '''
Número de Tarjeta: $cleanNumber
Titular: ${card.cardholderName}
Vencimiento: ${card.expirationDate}
CVV: ${card.cvvMasked}
Tipo: ${card.cardType}
''';

    Clipboard.setData(ClipboardData(text: data.trim()));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Datos de la tarjeta copiados al portapapeles para compras online',
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.textPrimary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showNewCardDialog() {
    final accounts = ref.read(accountsProvider).value ?? const [];
    final session = ref.read(sessionControllerProvider).value;

    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontraron cuentas activas para asociar la tarjeta.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    String selectedAccountId = accounts.first.id;
    String selectedCardType = 'DEBIT';
    final nameController = TextEditingController(
      text: session?.user.fullName ?? '',
    );
    bool isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.add_card,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text('Nueva Tarjeta Digital'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Emite una tarjeta digital al instante conectada a una de tus cuentas bancarias.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Cuenta Vinculada',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedAccountId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: accounts.map((acc) {
                      return DropdownMenuItem<String>(
                        value: acc.id,
                        child: Text(
                          '${acc.displayName} (${acc.maskedNumber})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedAccountId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Tipo de Tarjeta',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Débito')),
                          selected: selectedCardType == 'DEBIT',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => selectedCardType = 'DEBIT');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Crédito')),
                          selected: selectedCardType == 'CREDIT',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => selectedCardType = 'CREDIT');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Nombre del Titular',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'NOMBRE COMPLETO',
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        try {
                          await ref.read(cardsRepositoryProvider).createCard(
                                accountId: selectedAccountId,
                                cardType: selectedCardType,
                                cardholderName: nameController.text.trim(),
                              );

                          ref.read(dataVersionProvider.notifier).state++;
                          ref.invalidate(cardsProvider);

                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('¡Tarjeta digital emitida exitosamente!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error al emitir tarjeta: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Emitir Tarjeta'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).value;
    final cardsAsync = ref.watch(cardsProvider);

    return AppScaffold(
      title: 'Mis Tarjetas',
      showBottomNav: true,
      currentIndex: 1,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.read(dataVersionProvider.notifier).state++;
          await ref.refresh(cardsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // Banner de contexto del Banco Activo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tarjetas Digitales',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session?.tenant.name ?? 'Entidad Bancaria',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton.filledTonal(
                    onPressed: _showNewCardDialog,
                    icon: const Icon(Icons.add_card),
                    tooltip: 'Solicitar nueva tarjeta',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Carrusel o visualizador de tarjetas
            cardsAsync.when(
              loading: () => const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 40, color: AppColors.error),
                        const SizedBox(height: 10),
                        Text('Error al cargar tarjetas: $err'),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => ref.refresh(cardsProvider),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              data: (cards) {
                if (cards.isEmpty) {
                  return _buildEmptyCardsView();
                }

                if (_selectedCardIndex >= cards.length) {
                  _selectedCardIndex = 0;
                }

                final currentCard = cards[_selectedCardIndex];

                return Column(
                  children: [
                    // PageView de tarjetas si hay varias, o tarjeta única
                    SizedBox(
                      height: 236,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: cards.length,
                        onPageChanged: (idx) {
                          setState(() => _selectedCardIndex = idx);
                        },
                        itemBuilder: (context, index) {
                          final card = cards[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: CardVisualWidget(
                              card: card,
                              isCompact: false,
                              showActions: true,
                            ),
                          );
                        },
                      ),
                    ),

                    // Indicador de puntos si hay múltiples tarjetas
                    if (cards.length > 1) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(cards.length, (idx) {
                          final isSelected = idx == _selectedCardIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isSelected ? 20 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Acciones interactivas para la tarjeta seleccionada
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildCardControlActions(currentCard),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // Sección de Seguridad y Límites Diarios
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSecurityAndLimitsSection(),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCardsView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.credit_card_outlined,
                  size: 38,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No tienes tarjetas en este banco',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Emite tu tarjeta débito digital 100% gratuita para realizar compras seguras en internet y pagos contactless.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'Emitir mi primera tarjeta digital',
                icon: Icons.add_card,
                onPressed: _showNewCardDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardControlActions(CardModel card) {
    return Column(
      children: [
        // Switch de seguridad: Congelar / Bloquear tarjeta
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: card.isBlocked
                        ? AppColors.error.withOpacity(0.12)
                        : AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    card.isBlocked ? Icons.lock : Icons.lock_open,
                    color: card.isBlocked ? AppColors.error : AppColors.success,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.isBlocked ? 'Tarjeta Congelada' : 'Tarjeta Activa',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.isBlocked
                            ? 'Bloqueada temporalmente para compras'
                            : 'Habilitada para compras físicas y online',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isTogglingStatus)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: !card.isBlocked,
                    activeColor: AppColors.success,
                    inactiveThumbColor: AppColors.error,
                    inactiveTrackColor: AppColors.error.withOpacity(0.2),
                    onChanged: (_) => _toggleCardStatus(card),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Botón: Copiar datos para compras online
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copiar datos online'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                onPressed: () => _copyCardData(card),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_card, size: 18),
                label: const Text('Nueva tarjeta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _showNewCardDialog,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityAndLimitsSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Seguridad y Límites Diarios',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildLimitRow(
              icon: Icons.shopping_bag_outlined,
              title: 'Límite de compras por internet',
              value: '\$ 2,000,000 COP / día',
            ),
            const SizedBox(height: 12),
            _buildLimitRow(
              icon: Icons.local_atm_outlined,
              title: 'Límite de retiros en cajero',
              value: '\$ 1,500,000 COP / día',
            ),
            const SizedBox(height: 12),
            _buildLimitRow(
              icon: Icons.verified_user_outlined,
              title: 'Protección antifraude 24/7',
              value: 'Tokenización dinámica activa',
            ),
            const SizedBox(height: 12),
            _buildLimitRow(
              icon: Icons.public,
              title: 'Compras internacionales',
              value: 'Habilitadas (Mastercard / Visa)',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

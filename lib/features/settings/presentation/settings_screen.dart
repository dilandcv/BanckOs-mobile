import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/providers.dart';
import 'package:mobile/core/theme/tenant_theme.dart';
import 'package:mobile/features/settings/data/app_settings.dart';
import 'package:mobile/features/settings/data/settings_providers.dart';
import 'package:mobile/shared/constants/app_colors.dart';
import 'package:mobile/shared/widgets/app_scaffold.dart';
import 'package:mobile/shared/widgets/primary_button.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _feeFixed = TextEditingController();
  final _feePercent = TextEditingController();
  final _fromCurrency = TextEditingController(text: 'USD');
  final _toCurrency = TextEditingController(text: 'EUR');
  final _rate = TextEditingController();

  // Branding Controllers (Colores y Logotipo de la entidad bancaria)
  final _primaryColor = TextEditingController(text: '#003366');
  final _secondaryColor = TextEditingController(text: '#006699');
  final _logoUrl = TextEditingController();

  bool _seeded = false;
  bool _brandingSeeded = false;
  bool _showRateForm = false;
  bool _saving = false;
  bool _savingBranding = false;
  bool _uploadingLogo = false;

  static const _presetColors = [
    {'name': 'Bancolombia', 'primary': '#FDDA24', 'secondary': '#000000'},
    {'name': 'Nu Bank', 'primary': '#820AD1', 'secondary': '#A64AC9'},
    {'name': 'Daviplata', 'primary': '#ED1C24', 'secondary': '#FF5A5F'},
    {'name': 'Nequi', 'primary': '#6E2585', 'secondary': '#A64AC9'},
    {'name': 'BankOS Blue', 'primary': '#003366', 'secondary': '#006699'},
    {'name': 'Esmeralda', 'primary': '#00875A', 'secondary': '#36B37E'},
    {'name': 'Titanio', 'primary': '#1E293B', 'secondary': '#334155'},
  ];

  @override
  void dispose() {
    _feeFixed.dispose();
    _feePercent.dispose();
    _fromCurrency.dispose();
    _toCurrency.dispose();
    _rate.dispose();
    _primaryColor.dispose();
    _secondaryColor.dispose();
    _logoUrl.dispose();
    super.dispose();
  }

  void _message(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
      ));
  }

  void _seed(TenantSettings settings) {
    if (_seeded) return;
    _feeFixed.text = settings.feeFixed;
    _feePercent.text = settings.feePercent;
    _seeded = true;
  }

  void _seedBranding() {
    if (_brandingSeeded) return;
    final session = ref.read(sessionControllerProvider).value;
    if (session != null) {
      _primaryColor.text = session.tenant.primaryColor;
      _secondaryColor.text = session.tenant.secondaryColor;
      _logoUrl.text = session.tenant.logoUrl ?? '';
      _brandingSeeded = true;
    }
  }

  String _formatHex(String input) {
    String clean = input.trim();
    if (!clean.startsWith('#')) {
      clean = '#$clean';
    }
    return clean.toUpperCase();
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      await ref.read(settingsRepositoryProvider).updateSettings(<String, String>{
        'transfer.fee.fixed': _feeFixed.text.trim(),
        'transfer.fee.percent': _feePercent.text.trim(),
      });
      ref.invalidate(tenantSettingsProvider);
      ref.read(dataVersionProvider.notifier).state++;
      _message('Configuración de comisiones actualizada');
    } on ApiException catch (error) {
      _message(error.displayMessage, isError: true);
    } catch (_) {
      _message('No se pudo actualizar la configuración', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createRate() async {
    setState(() => _saving = true);
    try {
      await ref.read(settingsRepositoryProvider).createRate(
            fromCurrency: _fromCurrency.text,
            toCurrency: _toCurrency.text,
            rate: _rate.text,
            effectiveFrom: DateTime.now().toUtc().toIso8601String(),
          );
      ref.invalidate(exchangeRatesProvider);
      ref.read(dataVersionProvider.notifier).state++;
      _rate.clear();
      setState(() => _showRateForm = false);
      _message('Tasa creada correctamente');
    } on ApiException catch (error) {
      _message(error.displayMessage, isError: true);
    } catch (_) {
      _message('No se pudo crear la tasa', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveBranding() async {
    final session = ref.read(sessionControllerProvider).value;
    if (session == null) {
      _message('No hay sesión de banco activa', isError: true);
      return;
    }

    final pColor = _formatHex(_primaryColor.text);
    final sColor = _formatHex(_secondaryColor.text);
    final logo = _logoUrl.text.trim();

    final hexRegex = RegExp(r'^#[0-9A-Fa-f]{6}$');
    if (!hexRegex.hasMatch(pColor) || !hexRegex.hasMatch(sColor)) {
      _message('Los colores deben estar en formato hexadecimal #RRGGBB (ej: #003366)', isError: true);
      return;
    }

    setState(() => _savingBranding = true);
    try {
      final updatedTenant = await ref.read(authRepositoryProvider).updateTenantBranding(
            tenantId: session.tenant.id,
            primaryColor: pColor,
            secondaryColor: sColor,
            logoUrl: logo.isEmpty ? null : logo,
          );

      // Actualizar sesión activa y reactivar el tema en cascada
      final updatedSession = session.copyWith(
        tenant: session.tenant.copyWith(
          primaryColor: updatedTenant.primaryColor,
          secondaryColor: updatedTenant.secondaryColor,
          logoUrl: updatedTenant.logoUrl,
        ),
      );
      await ref.read(sessionControllerProvider.notifier).setSession(updatedSession);
      ref.read(dataVersionProvider.notifier).state++;

      _message('¡Identidad y colores de ${updatedTenant.name} actualizados!');
    } on ApiException catch (error) {
      _message(error.displayMessage, isError: true);
    } catch (e) {
      _message('Error al guardar la marca del banco: $e', isError: true);
    } finally {
      if (mounted) setState(() => _savingBranding = false);
    }
  }

  Future<void> _uploadLogoSample() async {
    final session = ref.read(sessionControllerProvider).value;
    if (session == null) return;

    setState(() => _uploadingLogo = true);
    try {
      // Imagen PNG válida de 1x1 píxel para subida segura de foto/logotipo multipart
      final pngBytes = <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ];

      final updatedTenant = await ref.read(authRepositoryProvider).uploadTenantLogo(
            tenantId: session.tenant.id,
            fileBytes: pngBytes,
            filename: 'logo_${session.tenant.code.toLowerCase()}.png',
          );

      _logoUrl.text = updatedTenant.logoUrl ?? '';

      final updatedSession = session.copyWith(
        tenant: session.tenant.copyWith(logoUrl: updatedTenant.logoUrl),
      );
      await ref.read(sessionControllerProvider.notifier).setSession(updatedSession);
      ref.read(dataVersionProvider.notifier).state++;

      _message('Foto de logo subida y vinculada exitosamente');
    } on ApiException catch (error) {
      _message(error.displayMessage, isError: true);
    } catch (e) {
      _message('Error al subir el logo: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).value;
    final canManage = session?.user.canManageSettings ?? false;
    final settingsAsync = ref.watch(tenantSettingsProvider);
    final ratesAsync = ref.watch(exchangeRatesProvider);
    final settings = settingsAsync.value;
    if (settings != null) _seed(settings);
    _seedBranding();
    final rates = ratesAsync.value ?? const [];

    final previewPrimary = TenantTheme.parseHex(_primaryColor.text) ??
        Theme.of(context).colorScheme.primary;
    final previewSecondary = TenantTheme.parseHex(_secondaryColor.text) ??
        Theme.of(context).colorScheme.secondary;

    return AppScaffold(
      title: 'Ajustes y Marca',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // SECCIÓN 1: Identidad y Personalización de Marca (Admin de Banco)
          if (canManage) ...[
            Row(
              children: [
                Icon(Icons.palette_outlined,
                    color: Theme.of(context).colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Identidad y Marca del Banco',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Personaliza la paleta de colores corporativa y el logotipo de ${session?.tenant.name ?? 'tu banco'}.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Previsualización en Tiempo Real
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [previewPrimary, previewSecondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: previewPrimary.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: _logoUrl.text.trim().isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      _logoUrl.text.trim(),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.account_balance,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.account_balance,
                                    color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session?.tenant.name ?? 'Banco Activo',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Previsualización en tiempo real',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Paleta de colores predefinidos rápidos
                    const Text(
                      'Paletas recomendadas:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presetColors.map((preset) {
                        final pCol = TenantTheme.parseHex(preset['primary']!)!;
                        final sCol = TenantTheme.parseHex(preset['secondary']!)!;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _primaryColor.text = preset['primary']!;
                              _secondaryColor.text = preset['secondary']!;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: pCol,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: sCol,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  preset['name']!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Inputs de colores hexadecimales
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _primaryColor,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Color Primario (#HEX)',
                              hintText: '#003366',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: previewPrimary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _secondaryColor,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Color Secundario (#HEX)',
                              hintText: '#006699',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: previewSecondary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // URL de Logo y Subida de Foto
                    TextField(
                      controller: _logoUrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'URL del Logotipo',
                        hintText: 'https://ejemplo.com/logo.png',
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _uploadingLogo ? null : _uploadLogoSample,
                            icon: _uploadingLogo
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.add_photo_alternate_outlined),
                            label: const Text('Adjuntar foto de logo'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Botón Guardar Cambios de Marca
                    PrimaryButton(
                      label: 'Guardar Cambios de Marca',
                      icon: Icons.check_circle_outline,
                      loading: _savingBranding,
                      onPressed: _saveBranding,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // SECCIÓN 2: Comisiones de Transferencia
          Row(
            children: [
              Icon(Icons.tune, color: Theme.of(context).colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Comisiones de transferencia',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (settingsAsync.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (settingsAsync.hasError)
                    Text(
                      'No se pudo cargar la configuración: ${settingsAsync.error}',
                      style: const TextStyle(color: AppColors.danger),
                    )
                  else ...[
                    TextField(
                      controller: _feeFixed,
                      enabled: canManage,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Comisión fija (transfer.fee.fixed)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _feePercent,
                      enabled: canManage,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Comisión porcentual (transfer.fee.percent)',
                      ),
                    ),
                    if (canManage) ...[
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Guardar configuración',
                        icon: Icons.save_outlined,
                        loading: _saving,
                        onPressed: _saveSettings,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // SECCIÓN 3: Tasas de Cambio
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.currency_exchange,
                      color: Theme.of(context).colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Tasas de cambio',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (canManage)
                TextButton.icon(
                  onPressed: () => setState(() => _showRateForm = !_showRateForm),
                  icon: const Icon(Icons.add),
                  label: Text(_showRateForm ? 'Ocultar' : 'Nueva'),
                ),
            ],
          ),
          if (_showRateForm && canManage) ...[
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _fromCurrency,
                            decoration: const InputDecoration(labelText: 'Desde'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _toCurrency,
                            decoration: const InputDecoration(labelText: 'Hasta'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _rate,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Tasa'),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Crear tasa',
                      icon: Icons.save_outlined,
                      loading: _saving,
                      onPressed: _createRate,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (ratesAsync.isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (ratesAsync.hasError)
            Text(
              'No se pudieron cargar las tasas: ${ratesAsync.error}',
              style: const TextStyle(color: AppColors.danger),
            )
          else if (rates.isEmpty)
            const Text(
              'Este banco todavía no tiene tasas de cambio',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            ...rates.map(
              (rate) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.surfaceMuted,
                    child: Icon(
                      Icons.swap_horiz,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    rate.pair,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text('Tasa: ${rate.rate}'),
                  trailing: Text(
                    rate.active ? 'Vigente' : 'Inactiva',
                    style: TextStyle(
                      fontSize: 12,
                      color: rate.active ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/core/providers.dart';
import 'package:mobile/core/session/auth_session.dart';
import 'package:mobile/core/storage/secure_session_store.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/cards/data/card_model.dart';
import 'package:mobile/features/cards/data/cards_providers.dart';
import 'package:mobile/features/cards/data/cards_repository.dart';
import 'package:mobile/features/tenants/data/tenant.dart';
import 'package:mobile/features/tenants/data/tenants_providers.dart';

import '../helpers/fake_adapter.dart';

Map<String, dynamic> _fixture(String name) {
  final file = File('test/fixtures/$name');
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, dynamic>();
}

void main() {
  group('Fase 2: Modelos, Repositorios, Portal de Bancos y Registro Contextual', () {
    late MemorySessionStorage storage;
    late RoutingFakeAdapter adapter;
    late ProviderContainer container;
    late SecureSessionStore sessionStore;
    late ApiClient apiClient;
    late AuthRepository authRepo;
    late CardsRepository cardsRepo;

    final fakeLogin = _fixture('login_response.json');
    final cardId = '50000000-0000-0000-0000-000000000001';
    final tenantId = '00000000-0000-0000-0000-000000000007';

    setUp(() {
      storage = MemorySessionStorage();
      sessionStore = SecureSessionStore(storage: storage);
      adapter = RoutingFakeAdapter();

      final dio = Dio()..httpClientAdapter = adapter;
      apiClient = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        sessionStore: sessionStore,
        dio: dio,
      );
      authRepo = AuthRepository(apiClient, sessionStore);
      cardsRepo = CardsRepository(apiClient);

      container = ProviderContainer(
        overrides: [
          secureSessionStoreProvider.overrideWithValue(sessionStore),
          dioProvider.overrideWithValue(dio),
          apiClientProvider.overrideWithValue(apiClient),
          authRepositoryProvider.overrideWithValue(authRepo),
          cardsRepositoryProvider.overrideWithValue(cardsRepo),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('CardModel serializa y deserializa con soporte de estados y getters', () {
      final json = <String, dynamic>{
        'id': cardId,
        'tenant_id': tenantId,
        'account_id': '30000000-0000-0000-0000-000000000001',
        'customer_id': '20000000-0000-0000-0000-000000000001',
        'card_number': '•••• •••• •••• 4589',
        'cardholder_name': 'Juan Pérez',
        'expiration_date': '11/31',
        'cvv_masked': '***',
        'card_type': 'DEBIT',
        'status': 'ACTIVE',
        'created_at': '2026-11-20T12:00:00Z',
      };

      final card = CardModel.fromJson(json);
      expect(card.id, equals(cardId));
      expect(card.cardNumber, equals('•••• •••• •••• 4589'));
      expect(card.cardholderName, equals('Juan Pérez'));
      expect(card.isActive, isTrue);
      expect(card.isBlocked, isFalse);

      final exported = card.toJson();
      expect(exported['id'], equals(cardId));
      expect(exported['status'], equals('ACTIVE'));
      expect(exported['card_type'], equals('DEBIT'));
    });

    test('CardsRepository.getCards consulta ApiEndpoints.cards y mapea la lista', () async {
      adapter.routes[ApiEndpoints.cards] = FakeResponse(
        200,
        <String, dynamic>{
          'success': true,
          'code': 'CARDS_LISTED',
          'message': 'Tarjetas obtenidas',
          'data': [
            {
              'id': cardId,
              'tenant_id': tenantId,
              'account_id': '30000000-0000-0000-0000-000000000001',
              'customer_id': '20000000-0000-0000-0000-000000000001',
              'card_number': '•••• •••• •••• 1234',
              'cardholder_name': 'Cliente Demo',
              'expiration_date': '12/30',
              'cvv_masked': '***',
              'card_type': 'DEBIT',
              'status': 'ACTIVE',
            }
          ],
        },
      );

      final cards = await cardsRepo.getCards();
      expect(cards.length, equals(1));
      expect(cards.first.id, equals(cardId));
      expect(cards.first.cardNumber, equals('•••• •••• •••• 1234'));
      expect(cards.first.isActive, isTrue);
    });

    test('CardsRepository.createCard emite una tarjeta para la cuenta indicada', () async {
      adapter.routes[ApiEndpoints.cards] = FakeResponse(
        200,
        <String, dynamic>{
          'success': true,
          'code': 'CARD_CREATED',
          'message': 'Tarjeta emitida correctamente',
          'data': {
            'id': cardId,
            'tenant_id': tenantId,
            'account_id': '30000000-0000-0000-0000-000000000001',
            'customer_id': '20000000-0000-0000-0000-000000000001',
            'card_number': '•••• •••• •••• 9876',
            'cardholder_name': 'Nuevo Titular',
            'expiration_date': '01/32',
            'cvv_masked': '***',
            'card_type': 'DEBIT',
            'status': 'ACTIVE',
          },
        },
      );

      final created = await cardsRepo.createCard(
        accountId: '30000000-0000-0000-0000-000000000001',
        cardholderName: 'Nuevo Titular',
      );

      expect(created.id, equals(cardId));
      expect(created.cardholderName, equals('Nuevo Titular'));
      expect(created.isActive, isTrue);
    });

    test('CardsRepository.toggleCardStatus actualiza el estado de la tarjeta', () async {
      final statusEndpoint = ApiEndpoints.cardStatus(cardId);
      adapter.routes[statusEndpoint] = FakeResponse(
        200,
        <String, dynamic>{
          'success': true,
          'code': 'CARD_STATUS_UPDATED',
          'message': 'Estado de tarjeta actualizado',
          'data': {
            'id': cardId,
            'tenant_id': tenantId,
            'account_id': '30000000-0000-0000-0000-000000000001',
            'customer_id': '20000000-0000-0000-0000-000000000001',
            'card_number': '•••• •••• •••• 9876',
            'cardholder_name': 'Nuevo Titular',
            'expiration_date': '01/32',
            'cvv_masked': '***',
            'card_type': 'DEBIT',
            'status': 'BLOCKED',
          },
        },
      );

      final updated = await cardsRepo.toggleCardStatus(
        cardId: cardId,
        newStatus: 'BLOCKED',
      );

      expect(updated.id, equals(cardId));
      expect(updated.isBlocked, isTrue);
      expect(updated.isActive, isFalse);
    });

    test('AuthRepository.registerCustomer registra usuario, fija la sesión y activa el banco', () async {
      adapter.routes[ApiEndpoints.authRegister] = FakeResponse(200, fakeLogin);

      final session = await authRepo.registerCustomer(
        tenantCode: 'BANCO_HORIZONTE',
        email: 'nuevo@horizonte.com',
        password: 'Password123!',
        fullName: 'Nuevo Usuario',
        documentType: 'CC',
        documentNumber: '1098765432',
      );

      expect(session.tenant.code, equals('BANCO_HORIZONTE'));
      expect(await storage.read(key: 'active_tenant'), equals('BANCO_HORIZONTE'));

      final lastReq = adapter.requests.last;
      expect(lastReq.options.path, equals(ApiEndpoints.authRegister));
      expect(lastReq.decodedBody?['tenant_code'], equals('BANCO_HORIZONTE'));
      expect(lastReq.decodedBody?['email'], equals('nuevo@horizonte.com'));
      expect(lastReq.decodedBody?['document_number'], equals('1098765432'));
    });

    test('AuthRepository.getPublicTenants obtiene la lista de bancos activos', () async {
      adapter.routes[ApiEndpoints.tenantsPublic] = FakeResponse(
        200,
        <String, dynamic>{
          'success': true,
          'code': 'TENANTS_PUBLIC_LISTED',
          'message': 'Instituciones activas',
          'data': [
            {
              'id': tenantId,
              'code': 'BANCOLOMBIA',
              'name': 'Bancolombia',
              'status': 'ACTIVE',
              'primary_color': '#FDDA24',
              'secondary_color': '#1D1D1B',
              'logo_url': null,
            },
            {
              'id': 'tenant-nu',
              'code': 'NU',
              'name': 'Nu Bank',
              'status': 'ACTIVE',
              'primary_color': '#820AD1',
              'secondary_color': '#4C0677',
              'logo_url': null,
            }
          ],
        },
      );

      final publicTenants = await authRepo.getPublicTenants();
      expect(publicTenants.length, equals(2));
      expect(publicTenants.first.code, equals('BANCOLOMBIA'));
      expect(publicTenants.first.primaryColor, equals('#FDDA24'));
      expect(publicTenants.last.code, equals('NU'));
      expect(publicTenants.last.primaryColor, equals('#820AD1'));
    });

    test('AuthRepository.updateTenantBranding actualiza colores de marca del banco', () async {
      final brandingEndpoint = ApiEndpoints.tenantBranding(tenantId);
      adapter.routes[brandingEndpoint] = FakeResponse(
        200,
        <String, dynamic>{
          'success': true,
          'code': 'TENANT_BRANDING_UPDATED',
          'message': 'Marca actualizada',
          'data': {
            'id': tenantId,
            'code': 'BANCOLOMBIA',
            'name': 'Bancolombia',
            'status': 'ACTIVE',
            'primary_color': '#FDDA24',
            'secondary_color': '#000000',
            'logo_url': 'http://localhost:8080/uploads/logos/bancolombia.png',
          },
        },
      );

      final updated = await authRepo.updateTenantBranding(
        tenantId: tenantId,
        primaryColor: '#FDDA24',
        secondaryColor: '#000000',
      );

      expect(updated.primaryColor, equals('#FDDA24'));
      expect(updated.secondaryColor, equals('#000000'));
    });

    test('publicTenantsProvider provee la lista de bancos públicos', () async {
      adapter.routes[ApiEndpoints.tenantsPublic] = FakeResponse(
        200,
        <String, dynamic>{
          'success': true,
          'code': 'TENANTS_PUBLIC_LISTED',
          'message': 'Instituciones activas',
          'data': [
            {
              'id': 'tenant-daviplata',
              'code': 'DAVIPLATA',
              'name': 'Daviplata',
              'status': 'ACTIVE',
              'primary_color': '#ED1C24',
              'secondary_color': '#A80006',
            }
          ],
        },
      );

      final asyncValue = await container.read(publicTenantsProvider.future);
      expect(asyncValue.length, equals(1));
      expect(asyncValue.first.name, equals('Daviplata'));
      expect(asyncValue.first.code, equals('DAVIPLATA'));
    });
  });
}

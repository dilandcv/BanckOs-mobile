import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/cards/data/card_model.dart';

class CardsRepository {
  CardsRepository(this._api);

  final ApiClient _api;

  /// Obtiene la lista de tarjetas vinculadas a las cuentas del usuario activo.
  Future<List<CardModel>> getCards({String? accountId, String? customerId}) async {
    final query = <String, dynamic>{
      if (accountId != null && accountId.isNotEmpty) 'accountId': accountId,
      if (customerId != null && customerId.isNotEmpty) 'customerId': customerId,
    };

    final envelope = await _api.get<List<dynamic>>(
      ApiEndpoints.cards,
      queryParameters: query.isNotEmpty ? query : null,
      parse: (raw) => (raw as List<dynamic>),
    );

    final data = envelope.data ?? const <dynamic>[];
    return data
        .map((item) => CardModel.fromJson((item as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Emite una nueva tarjeta digital asociada a una cuenta bancaria.
  Future<CardModel> createCard({
    required String accountId,
    String cardType = 'DEBIT',
    String? customerId,
    String? cardholderName,
  }) async {
    final envelope = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.cards,
      data: <String, dynamic>{
        'account_id': accountId,
        'card_type': cardType.toUpperCase(),
        if (customerId != null && customerId.isNotEmpty) 'customer_id': customerId,
        if (cardholderName != null && cardholderName.isNotEmpty)
          'cardholder_name': cardholderName,
      },
      parse: (raw) => (raw as Map).cast<String, dynamic>(),
    );

    final data = envelope.data;
    if (data == null) {
      throw ApiException.network('No se recibió información de la tarjeta creada');
    }

    return CardModel.fromJson(data);
  }

  /// Actualiza el estado de la tarjeta (ACTIVE o BLOCKED).
  Future<CardModel> toggleCardStatus({
    required String cardId,
    required String newStatus,
  }) async {
    final envelope = await _api.patch<Map<String, dynamic>>(
      ApiEndpoints.cardStatus(cardId),
      data: <String, dynamic>{
        'status': newStatus.toUpperCase(),
      },
      parse: (raw) => (raw as Map).cast<String, dynamic>(),
    );

    final data = envelope.data;
    if (data == null) {
      throw ApiException.network('No se pudo actualizar el estado de la tarjeta');
    }

    return CardModel.fromJson(data);
  }
}

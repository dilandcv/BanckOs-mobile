class CardModel {
  const CardModel({
    required this.id,
    required this.tenantId,
    required this.accountId,
    required this.customerId,
    required this.cardNumber,
    required this.cardholderName,
    required this.expirationDate,
    required this.cvvMasked,
    required this.cardType,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String accountId;
  final String customerId;
  final String cardNumber;
  final String cardholderName;
  final String expirationDate;
  final String cvvMasked;
  final String cardType;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isBlocked => status.toUpperCase() == 'BLOCKED';

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: (json['id'] as String?) ?? '',
      tenantId: (json['tenant_id'] ?? json['tenantId'] as String?) ?? '',
      accountId: (json['account_id'] ?? json['accountId'] as String?) ?? '',
      customerId: (json['customer_id'] ?? json['customerId'] as String?) ?? '',
      cardNumber: (json['card_number'] ?? json['cardNumber'] as String?) ?? '',
      cardholderName:
          (json['cardholder_name'] ?? json['cardholderName'] as String?) ?? '',
      expirationDate:
          (json['expiration_date'] ?? json['expirationDate'] as String?) ?? '',
      cvvMasked: (json['cvv_masked'] ?? json['cvvMasked'] as String?) ?? '***',
      cardType: (json['card_type'] ?? json['cardType'] as String?) ?? 'DEBIT',
      status: (json['status'] as String?) ?? 'ACTIVE',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'tenant_id': tenantId,
        'account_id': accountId,
        'customer_id': customerId,
        'card_number': cardNumber,
        'cardholder_name': cardholderName,
        'expiration_date': expirationDate,
        'cvv_masked': cvvMasked,
        'card_type': cardType,
        'status': status,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };
}

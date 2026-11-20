import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/providers.dart';
import 'package:mobile/features/cards/data/card_model.dart';
import 'package:mobile/features/cards/data/cards_repository.dart';

final cardsRepositoryProvider = Provider<CardsRepository>((ref) {
  return CardsRepository(ref.watch(apiClientProvider));
});

final cardsProvider = FutureProvider<List<CardModel>>((ref) async {
  ref.watch(sessionControllerProvider);
  ref.watch(dataVersionProvider);

  final activeSession = ref.watch(sessionControllerProvider).value;
  if (activeSession == null) return const <CardModel>[];

  try {
    return await ref.read(cardsRepositoryProvider).getCards();
  } catch (_) {
    return const <CardModel>[];
  }
});

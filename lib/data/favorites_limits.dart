const int freeFavoritePetsLimit = 6;
const int premiumFavoritePetsLimit = 8;
const int freeFavoriteArmorsLimit = 15;
const int premiumFavoriteArmorsLimit =
    freeFavoriteArmorsLimit * 2 < 40 ? freeFavoriteArmorsLimit * 2 : 40;

bool canAddFavorite({
  required bool isPremium,
  required int currentCount,
  required int freeLimit,
  int? premiumLimit,
}) {
  final limit = isPremium ? premiumLimit : freeLimit;
  if (limit == null) return true;
  return currentCount < limit;
}

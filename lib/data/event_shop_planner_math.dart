class EventShopPlannerTotals {
  final int required;
  final int available;
  final int remaining;
  final bool inventoryIsInfinite;

  const EventShopPlannerTotals({
    required this.required,
    required this.available,
    required this.remaining,
    required this.inventoryIsInfinite,
  });
}

EventShopPlannerTotals computeEventShopPlannerTotals({
  required int requiredAmount,
  required int manualInventory,
  required int trackedInventory,
  required bool trackedInfinite,
}) {
  final normalizedRequired = requiredAmount.clamp(0, 2000000000);
  final normalizedManual = manualInventory.clamp(0, 2000000000);
  final normalizedTracked = trackedInventory.clamp(0, 2000000000);
  final available = trackedInfinite
      ? normalizedRequired
      : (normalizedManual + normalizedTracked).clamp(0, 2000000000);
  final remaining = trackedInfinite
      ? 0
      : (normalizedRequired - available).clamp(0, 2000000000);
  return EventShopPlannerTotals(
    required: normalizedRequired,
    available: available,
    remaining: remaining,
    inventoryIsInfinite: trackedInfinite,
  );
}

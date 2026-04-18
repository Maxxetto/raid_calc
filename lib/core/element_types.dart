enum ElementType {
  fire,
  spirit,
  earth,
  air,
  water,
  starmetal,
}

extension ElementTypeCycle on ElementType {
  static const List<ElementType> all = <ElementType>[
    ElementType.fire,
    ElementType.spirit,
    ElementType.earth,
    ElementType.air,
    ElementType.water,
    ElementType.starmetal,
  ];

  static const List<ElementType> bossCycle = <ElementType>[
    ElementType.fire,
    ElementType.spirit,
    ElementType.earth,
    ElementType.air,
    ElementType.water,
  ];

  ElementType next({bool allowStarmetal = true}) {
    final cycle = allowStarmetal ? all : bossCycle;
    final idx = cycle.indexOf(this);
    if (idx < 0) return cycle.first;
    return cycle[(idx + 1) % cycle.length];
  }

  String get id => name;

  static ElementType fromId(String? id,
      {ElementType fallback = ElementType.fire}) {
    if (id == null || id.isEmpty) return fallback;
    for (final e in ElementType.values) {
      if (e.name == id) return e;
    }
    return fallback;
  }
}

bool elementBeats(ElementType attacker, ElementType defender) {
  if (attacker == ElementType.starmetal) return true;
  return switch (attacker) {
    ElementType.fire => defender == ElementType.spirit,
    ElementType.spirit => defender == ElementType.earth,
    ElementType.earth => defender == ElementType.air,
    ElementType.air => defender == ElementType.water,
    ElementType.water => defender == ElementType.fire,
    ElementType.starmetal => true,
  };
}

double advantageMultiplier(
  List<ElementType> attacker,
  List<ElementType> defender,
) {
  if (attacker.any((e) => e == ElementType.starmetal)) return 2.0;
  int hits = 0;
  for (final atk in attacker) {
    for (final def in defender) {
      if (elementBeats(atk, def)) hits += 1;
    }
  }
  if (hits >= 2) return 2.0;
  if (hits == 1) return 1.5;
  return 1.0;
}

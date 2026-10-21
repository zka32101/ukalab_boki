import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_boki3/oshi/boki3_character_overrides.dart';
import 'package:ukalab_core/ui.dart';

ProviderContainer _container(EntitlementState initial) {
  final c = ProviderContainer(overrides: [
    entitlementServiceProvider.overrideWithValue(FakeEntitlementService(initial: initial)),
    ...boki3CharacterOverrides(),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('appId は boki3 で、UkalabCert.boki3 とソロの appIds に一致する', () {
    final c = _container(EntitlementState.free);
    expect(c.read(characterAppIdProvider), 'boki3');
    expect(boki3CharacterAppId, UkalabCert.boki3.id);
    expect(UkalabCharacters.soro.isAvailableIn(boki3CharacterAppId), isTrue);
  });

  test('無料は false、プレミアムは true', () async {
    final free = _container(EntitlementState.free);
    free.listen(entitlementStateProvider, (_, __) {});
    await free.read(entitlementStateProvider.future);
    expect(free.read(characterPremiumProvider), isFalse);

    final premium = _container(const EntitlementState(hasPremium: true));
    premium.listen(entitlementStateProvider, (_, __) {});
    await premium.read(entitlementStateProvider.future);
    expect(premium.read(characterPremiumProvider), isTrue);
  });
}

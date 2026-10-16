import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_boki3/purchase/revenuecat_key.dart';

String? sel({bool web = false, bool android = false, bool ios = false, String g = '', String a = ''}) =>
    selectRevenueCatKey(isWeb: web, isAndroid: android, isIOS: ios, googleKey: g, appleKey: a);

void main() {
  test('Android は Google キー', () => expect(sel(android: true, g: 'g', a: 'a'), 'g'));
  test('iOS は Apple キー', () => expect(sel(ios: true, g: 'g', a: 'a'), 'a'));
  test('キー未指定は null（Fake）', () {
    expect(sel(android: true, a: 'a'), isNull);
    expect(sel(ios: true, g: 'g'), isNull);
  });
  test('Web・その他は null', () {
    expect(sel(web: true, android: true, g: 'g'), isNull);
    expect(sel(g: 'g', a: 'a'), isNull);
  });
}

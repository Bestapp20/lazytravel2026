import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_travel/core/utils/formatters.dart';

void main() {
  test('ILS formatter', () {
    expect(ils(1000), contains('1'));
  });

  test('nights between dates', () {
    expect(nightsBetween(DateTime(2026, 6, 12), DateTime(2026, 6, 18)), 6);
  });
}

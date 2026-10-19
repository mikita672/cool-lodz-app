import 'package:cool_lodz/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('successText passes WCAG AA (4.5:1) on white and background', () {
    expect(
      contrast(AppColors.successText, AppColors.surface),
      greaterThan(4.5),
    );
    expect(
      contrast(AppColors.successText, AppColors.background),
      greaterThan(4.5),
    );
  });

  test('icon colours keep 3:1 non-text contrast where used', () {
    // Cool stop icon on the selected route card.
    expect(
      contrast(AppColors.primary, AppColors.primaryContainer),
      greaterThan(3),
    );
    expect(
      contrast(AppColors.water, AppColors.primaryContainer),
      greaterThan(3),
    );
    // Glyphs on map pins.
    expect(contrast(AppColors.onSurface, AppColors.cool), greaterThan(3));
    expect(contrast(AppColors.onPrimary, AppColors.water), greaterThan(3));
    // Error icon on the dark toast.
    expect(contrast(AppColors.heat3, AppColors.onSurface), greaterThan(3));
  });

  test('heat banner text passes AA on every level', () {
    expect(contrast(AppColors.onSurface, AppColors.heat1), greaterThan(4.5));
    expect(contrast(AppColors.onSurface, AppColors.heat2), greaterThan(4.5));
    expect(contrast(AppColors.onPrimary, AppColors.heat3), greaterThan(4.5));
  });
}

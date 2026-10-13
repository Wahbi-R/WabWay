import 'package:flutter_test/flutter_test.dart';
import 'package:wabway/core/text_utils.dart';
import 'package:wabway/data/invite_data.dart';

void main() {
  test('foldForSearch matches without diacritics', () {
    expect(searchMatches('Sensō-ji', foldForSearch('senso')), isTrue);
    expect(searchMatches('Café de Flore', foldForSearch('cafe')), isTrue);
    expect(searchMatches('München', foldForSearch('MUNCHEN')), isTrue);
    expect(searchMatches(null, 'x'), isFalse);
  });

  test('initialsFor is one rule everywhere', () {
    expect(initialsFor('Test User'), 'TU');
    expect(initialsFor('Wahbi'), 'W');
    expect(initialsFor('  Ana  María  López '), 'AL');
    expect(initialsFor(''), '?');
  });

  test('pluralize', () {
    expect(pluralize(1, 'day'), '1 day');
    expect(pluralize(0, 'day'), '0 days');
    expect(pluralWord(2, 'Day'), 'Days');
  });

  test('invite codes accept the displayed format', () {
    expect(InviteCode.normalize('1d70 d387'), '1D70D387');
    expect(InviteCode.normalize(' 1D70-D387 '), '1D70D387');
  });
}

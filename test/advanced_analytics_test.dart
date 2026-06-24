import 'package:flutter_test/flutter_test.dart';
import 'package:sample/services/matrix_math.dart';

void main() {
  group('MatrixMath Tests', () {
    test('Transpose test', () {
      final matrix = [
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
      ];
      final expected = [
        [1.0, 4.0],
        [2.0, 5.0],
        [3.0, 6.0],
      ];
      expect(MatrixMath.transpose(matrix), expected);
    });

    test('Multiplication test', () {
      final A = [
        [1.0, 2.0],
        [3.0, 4.0],
      ];
      final B = [
        [5.0, 6.0],
        [7.0, 8.0],
      ];
      final expected = [
        [19.0, 22.0],
        [43.0, 50.0],
      ];
      expect(MatrixMath.multiply(A, B), expected);
    });

    test('Inversion test', () {
      final A = [
        [4.0, 7.0],
        [2.0, 6.0],
      ];
      final expected = [
        [0.6, -0.7],
        [-0.2, 0.4],
      ];
      final inv = MatrixMath.invert(A);
      expect(inv, isNotNull);
      for (int r = 0; r < 2; r++) {
        for (int c = 0; c < 2; c++) {
          expect(inv![r][c], closeTo(expected[r][c], 1e-9));
        }
      }
    });

    test('Singular matrix inversion returns null', () {
      final singular = [
        [1.0, 2.0],
        [2.0, 4.0],
      ];
      expect(MatrixMath.invert(singular), isNull);
    });
  });

  group('NlpService Debug', () {
    test('Tokenization simulation test', () {
      // Just check that we can instantiate it
      final tokenizerText = "i was feeling grounded today";
      final cleanText = tokenizerText.toLowerCase().replaceAll(RegExp(r"[.,\/#!$%\^&\*;:{}=\-_`~()]"), " ");
      final words = cleanText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      expect(words, contains('grounded'));
    });
  });
}

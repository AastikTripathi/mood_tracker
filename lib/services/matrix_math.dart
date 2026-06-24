class MatrixMath {
  static List<List<double>> transpose(List<List<double>> matrix) {
    if (matrix.isEmpty) return [];
    int rows = matrix.length;
    int cols = matrix[0].length;
    List<List<double>> result = List.generate(cols, (_) => List.filled(rows, 0.0));
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        result[c][r] = matrix[r][c];
      }
    }
    return result;
  }

  static List<List<double>> multiply(List<List<double>> A, List<List<double>> B) {
    int rowsA = A.length;
    int colsA = A[0].length;
    int colsB = B[0].length;
    List<List<double>> result = List.generate(rowsA, (_) => List.filled(colsB, 0.0));
    for (int i = 0; i < rowsA; i++) {
      for (int j = 0; j < colsB; j++) {
        double sum = 0.0;
        for (int k = 0; k < colsA; k++) {
          sum += A[i][k] * B[k][j];
        }
        result[i][j] = sum;
      }
    }
    return result;
  }

  static List<double> multiplyVector(List<List<double>> A, List<double> v) {
    int rows = A.length;
    int cols = A[0].length;
    List<double> result = List.filled(rows, 0.0);
    for (int i = 0; i < rows; i++) {
      double sum = 0.0;
      for (int j = 0; j < cols; j++) {
        sum += A[i][j] * v[j];
      }
      result[i] = sum;
    }
    return result;
  }

  /// Inverts a square matrix using Gauss-Jordan elimination with partial pivoting.
  /// Returns null if the matrix is singular (non-invertible).
  static List<List<double>>? invert(List<List<double>> matrix) {
    int n = matrix.length;
    List<List<double>> temp = List.generate(n, (i) => List.from(matrix[i]));
    List<List<double>> identity = List.generate(n, (i) => List.generate(n, (j) => i == j ? 1.0 : 0.0));

    for (int i = 0; i < n; i++) {
      int pivotRow = i;
      double maxVal = temp[i][i].abs();
      for (int r = i + 1; r < n; r++) {
        if (temp[r][i].abs() > maxVal) {
          maxVal = temp[r][i].abs();
          pivotRow = r;
        }
      }

      if (maxVal < 1e-12) {
        return null; // Singular matrix
      }

      if (pivotRow != i) {
        List<double> tRow = temp[i];
        temp[i] = temp[pivotRow];
        temp[pivotRow] = tRow;

        List<double> idRow = identity[i];
        identity[i] = identity[pivotRow];
        identity[pivotRow] = idRow;
      }

      double pivotVal = temp[i][i];
      for (int c = 0; c < n; c++) {
        temp[i][c] /= pivotVal;
        identity[i][c] /= pivotVal;
      }

      for (int r = 0; r < n; r++) {
        if (r != i) {
          double factor = temp[r][i];
          for (int c = 0; c < n; c++) {
            temp[r][c] -= factor * temp[i][c];
            identity[r][c] -= factor * identity[i][c];
          }
        }
      }
    }
    return identity;
  }
}

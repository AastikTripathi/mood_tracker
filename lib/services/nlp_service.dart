import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

class NlpAnalysis {
  final List<double> vector;
  final List<String> suggestedTags;

  const NlpAnalysis({required this.vector, required this.suggestedTags});
}

class NlpService {
  static final NlpService _instance = NlpService._internal();
  factory NlpService() => _instance;
  NlpService._internal();

  Interpreter? _interpreter;
  final Map<String, int> _vocab = {};
  int _unkId = 100;
  bool _isModelLoaded = false;

  /// Loads the 30k vocabulary asset file and initializes the C++ TFLite engine bindings
  Future<void> initialize() async {
    await init();
  }

  /// Loads the 30k vocabulary asset file and initializes the C++ TFLite engine bindings
  Future<void> init() async {
    if (_isModelLoaded) return;

    try {
      final vocabData = await rootBundle.loadString('assets/vocab.txt');
      final lines = const LineSplitter().convert(vocabData);
      for (int i = 0; i < lines.length; i++) {
        final token = lines[i].trim();
        if (token.isNotEmpty) {
          _vocab[token] = i;
        }
      }
      _unkId = _vocab['[UNK]'] ?? 100;

      // Initialize interpreter with the quantized model asset
      _interpreter = await Interpreter.fromAsset('all-MiniLM-L6-v2-quant.tflite');
      _isModelLoaded = true;
      print("NLP SETUP: On-device Transformer engine successfully booted.");
    } catch (e) {
      print("CRITICAL ERROR: Failed to load on-device ML system: $e");
    }
  }

  /// Splits text string down to internal Transformer WordPiece tokens
  List<int> _tokenize(String text) {
    final cleanText = text.toLowerCase().replaceAll(RegExp(r"[.,\/#!$%\^&\*;:{}=\-_`~()]"), " ");
    final words = cleanText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final List<int> inputIds = [];

    if (_vocab.containsKey('[CLS]')) inputIds.add(_vocab['[CLS]']!);

    for (final word in words) {
      int start = 0;
      bool isBad = false;
      final List<int> subwordIds = [];

      while (start < word.length) {
        int end = word.length;
        int matchedId = -1;

        while (start < end) {
          String substr = word.substring(start, end);
          if (start > 0) substr = "##$substr";

          if (_vocab.containsKey(substr)) {
            matchedId = _vocab[substr]!;
            break;
          }
          end--;
        }

        if (matchedId == -1) {
          isBad = true;
          break;
        }
        subwordIds.add(matchedId);
        start = end;
      }

      if (isBad) {
        inputIds.add(_unkId);
      } else {
        inputIds.addAll(subwordIds);
      }
    }

    if (_vocab.containsKey('[SEP]')) inputIds.add(_vocab['[SEP]']!);
    return inputIds;
  }

  /// Runs hardware inference on text to return a 384D coordinate vector array
  NlpAnalysis analyze(String text) {
    if (!_isModelLoaded || text.trim().isEmpty) {
      return NlpAnalysis(vector: List.filled(384, 0.0), suggestedTags: []);
    }

    try {
      final List<int> inputIds = _tokenize(text);
      final int seqLen = inputIds.length;
      final List<int> attentionMask = List.filled(seqLen, 1);

      // Dynamic Allocation: Resize model input gates to match exact token size
      _interpreter!.resizeInputTensor(0, [1, seqLen]); // Gate 0: Attention Mask
      _interpreter!.resizeInputTensor(1, [1, seqLen]); // Gate 1: Token IDs
      _interpreter!.allocateTensors();

      final List<Object> inputs = [
        [attentionMask],
        [inputIds],
      ];

      final Map<int, Object> outputs = {
        0: List.generate(1, (_) => List<double>.filled(384, 0.0)),
      };

      // Execute matrix computations via hardware layer
      _interpreter!.runForMultipleInputs(inputs, outputs);

      final List<double> finalVector = (outputs[0] as List<List<double>>).first;
      final derivedTags = _extractTagsFromVector(finalVector);

      return NlpAnalysis(vector: finalVector, suggestedTags: derivedTags);
    } catch (e) {
      print("Error running on-device inference: $e");
      return NlpAnalysis(vector: List.filled(384, 0.0), suggestedTags: []);
    }
  }

  /// Runs vectorization on text and returns the raw 384D coordinate vector array
  List<double> vectorize(String text) {
    return analyze(text).vector;
  }

  /// Computes spatial alignment between two 384D arrays
  double calculateSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length || v1.isEmpty) return 0.0;
    double dotProduct = 0.0;
    double mag1 = 0.0;
    double mag2 = 0.0;

    for (int i = 0; i < v1.length; i++) {
      dotProduct += v1[i] * v2[i];
      mag1 += v1[i] * v1[i];
      mag2 += v2[i] * v2[i];
    }

    if (mag1 == 0 || mag2 == 0) return 0.0;
    return dotProduct / (math.sqrt(mag1) * math.sqrt(mag2));
  }

  List<String> _extractTagsFromVector(List<double> vector) {
    final List<String> tags = [];
    // Basic structural anchors using high-signal vector boundaries 
    if (vector[10].abs() > 0.08) tags.add("Focus");
    if (vector[250].abs() > 0.08) tags.add("Calm");
    return tags;
  }

  /// Extracts categories from text. This preserves the original app category list
  /// but can also be augmented by vector tags or keep the existing robust keyword parsing.
  List<String> extractCategories(String text) {
    final clean = text.toLowerCase();
    List<String> results = [];

    if (clean.contains('work') || clean.contains('task') || clean.contains('deadline')) {
      results.add('Work');
    }
    if (clean.contains('anxious') || clean.contains('stressed') || clean.contains('overwhelmed')) {
      if (!clean.contains('not stressed') && !clean.contains('not anxious') && !clean.contains('dont feel anxious')) {
        results.add('Stress');
      }
    }
    if (clean.contains('tired') || clean.contains('sleep') || clean.contains('exhausted')) {
      results.add('Energy');
    }
    if (clean.contains('walk') || clean.contains('nature') || clean.contains('garden') || clean.contains('sun')) {
      results.add('Nature');
    }

    // Add suggestions from model if available
    final analysis = analyze(text);
    for (var tag in analysis.suggestedTags) {
      if (!results.contains(tag)) {
        results.add(tag);
      }
    }

    if (results.isEmpty) results.add('Reflection');
    return results;
  }
}
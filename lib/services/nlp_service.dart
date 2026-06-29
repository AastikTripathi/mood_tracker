import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/thought.dart';

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

  bool get isModelLoaded => _isModelLoaded;
  Map<String, int> get vocab => _vocab;

  Map<String, dynamic> getDiagnosticTokenization(String text) {
    final cleanText = text.toLowerCase().replaceAll(RegExp(r"[.,\/#!$%\^&\*;:{}=\-_`~()]"), " ");
    final words = cleanText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final List<int> inputIds = [];
    final List<String> tokenStrings = [];

    if (_vocab.containsKey('[CLS]')) {
      inputIds.add(_vocab['[CLS]']!);
      tokenStrings.add('[CLS]');
    }

    for (final word in words) {
      int start = 0;
      bool isBad = false;
      final List<int> subwordIds = [];
      final List<String> subwords = [];

      while (start < word.length) {
        int end = word.length;
        int matchedId = -1;
        String matchedStr = "";

        while (start < end) {
          String substr = word.substring(start, end);
          if (start > 0) substr = "##$substr";

          if (_vocab.containsKey(substr)) {
            matchedId = _vocab[substr]!;
            matchedStr = substr;
            break;
          }
          end--;
        }

        if (matchedId == -1) {
          isBad = true;
          break;
        }
        subwordIds.add(matchedId);
        subwords.add(matchedStr);
        start = end;
      }

      if (isBad) {
        inputIds.add(_unkId);
        tokenStrings.add('[UNK]');
      } else {
        inputIds.addAll(subwordIds);
        tokenStrings.addAll(subwords);
      }
    }

    if (_vocab.containsKey('[SEP]')) {
      inputIds.add(_vocab['[SEP]']!);
      tokenStrings.add('[SEP]');
    }
    return {
      'tokens': tokenStrings,
      'ids': inputIds,
    };
  }


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
      _interpreter = await Interpreter.fromAsset('assets/all-MiniLM-L6-v2-quant.tflite');
      _isModelLoaded = true;
      print("NLP SETUP: On-device Transformer engine successfully booted.");
      try {
        final tensors = _interpreter!.getInputTensors();
        print("TFLITE TENSORS: ${tensors.map((t) => "${t.name} (type: ${t.type}, shape: ${t.shape})").toList()}");
      } catch (ex) {
        print("TFLITE TENSOR LOGGING FAILED: $ex");
      }
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

  /// Runs hardware inference or fallback vectorizer to return a 384D coordinate vector array.
  /// This is a low-level helper that has no dependencies on tag extraction or emotion scoring.
  List<double> _getVector(String text) {
    if (text.trim().isEmpty) {
      return List.filled(384, 0.0);
    }

    if (!_isModelLoaded) {
      return _generateFallbackVector(text);
    }

    try {
      final List<int> inputIds = _tokenize(text);
      final int seqLen = inputIds.length;
      final List<int> attentionMask = List.filled(seqLen, 1);

      _interpreter!.resizeInputTensor(0, [1, seqLen]); // Index 0 is input_ids
      _interpreter!.resizeInputTensor(1, [1, seqLen]); // Index 1 is attention_mask
      _interpreter!.allocateTensors();

      final List<Object> inputs = [
        [inputIds],      // Index 0: token ids
        [attentionMask], // Index 1: attention mask
      ];

      final Map<int, Object> outputs = {
        0: List.generate(1, (_) => List<double>.filled(384, 0.0)),
      };

      _interpreter!.runForMultipleInputs(inputs, outputs);
      return (outputs[0] as List<List<double>>).first;
    } catch (e) {
      print("Error running on-device inference: $e");
      return _generateFallbackVector(text);
    }
  }

  /// Runs hardware inference on text to return a 384D coordinate vector array
  NlpAnalysis analyze(String text) {
    if (text.trim().isEmpty) {
      return NlpAnalysis(vector: List.filled(384, 0.0), suggestedTags: []);
    }

    final vector = _getVector(text);
    final bool isModelFailed = !_isModelLoaded;

    // Dynamic semantic extraction of emotion/sentiment from the note
    final emotionScores = getEmotionScores(text, vector);
    final derivedTags = <String>[];
    emotionScores.forEach((emotion, score) {
      final double threshold = isModelFailed ? 0.05 : 0.20;
      if (score >= threshold) {
        derivedTags.add(emotion);
      }
    });

    return NlpAnalysis(vector: vector, suggestedTags: derivedTags);
  }

  /// Generates a fallback 384D pseudo-embedding vector when the ML model is unloaded.
  /// Uses a term-frequency hashing trick normalized to unit length.
  List<double> _generateFallbackVector(String text) {
    final List<double> vector = List.filled(384, 0.0);
    final cleanText = text.toLowerCase().replaceAll(RegExp(r"[.,\/#!$%\^&\*;:{}=\-_`~()]"), " ");
    final words = cleanText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (words.isEmpty) return vector;

    for (final word in words) {
      int hash = 0;
      for (int i = 0; i < word.length; i++) {
        hash = (hash * 31 + word.codeUnitAt(i)) & 0xFFFFFFFF;
      }
      final int index = hash.abs() % 384;
      vector[index] += 1.0;
    }

    double sumSq = 0.0;
    for (final val in vector) {
      sumSq += val * val;
    }
    if (sumSq > 0) {
      final double norm = math.sqrt(sumSq);
      for (int i = 0; i < vector.length; i++) {
        vector[i] /= norm;
      }
    }

    return vector;
  }

  /// Runs vectorization on text and returns the raw 384D coordinate vector array
  List<double> vectorize(String text) {
    return _getVector(text);
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

  // Pre-defined semantic profile descriptions for dynamic zero-shot emotion matching
  static const Map<String, String> emotionProfiles = {
    'Stress': 'anxious stressed worried overwhelmed nervous tense concerned',
    'Calm': 'calm peaceful relaxed serene quiet tranquil mindful',
    'Energy': 'tired exhausted sleepy fatigued low energy weary',
    'Focus': 'focused concentrated productive hard working studying tasks',
    'Joy': 'happy cheerful joyful excited glad positive content',
    'Sadness': 'sad down depressed lonely gloomy sorrowful',
    'Gratitude': 'grateful thankful appreciated blessed happy positive hopeful optimistic motivated',
    'Frustration': 'frustrated angry annoyed irritated mad furious upset',
    'Discomfort': 'foggy groggy dizzy nauseous sick hurt headache pain tired fatigued',
  };

  // Cache compiled vector profiles to minimize redundant inferences
  final Map<String, List<double>> _cachedProfileVectors = {};

  /// Calculates semantic similarity of input text compared to emotion profile definitions.
  /// Evaluates sub-clauses separately to isolate mixed sentiments and combines scores via max-pooling.
  Map<String, double> getEmotionScores(String text, [List<double>? textVector]) {
    if (text.trim().isEmpty) return {};

    final Map<String, double> scores = {};
    for (final emotion in emotionProfiles.keys) {
      scores[emotion] = 0.0;
    }

    final bool isModelFailed = !_isModelLoaded;

    // Split text into clauses by common conjunctions and punctuation
    final RegExp splitReg = RegExp(r"[,.;!?]|\b(but|yet|however|although|whereas|though)\b", caseSensitive: false);
    final List<String> clauses = text.split(splitReg)
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty && c.split(RegExp(r'\s+')).length >= 2) // only analyze clauses with 2+ words
        .toList();

    // Fall back to whole text if no valid sub-clauses are extracted
    if (clauses.isEmpty) {
      clauses.add(text.trim());
    }

    for (final clause in clauses) {
      if (isModelFailed) {
        emotionProfiles.forEach((emotion, profileText) {
          final sim = _calculateTextJaccard(clause, profileText);
          scores[emotion] = math.max(scores[emotion]!, sim);
        });
      } else {
        final clauseVector = _getVector(clause);
        emotionProfiles.forEach((emotion, profileText) {
          final profileVector = _cachedProfileVectors.putIfAbsent(
            emotion,
            () => _getVector(profileText),
          );
          final sim = calculateSimilarity(clauseVector, profileVector);
          scores[emotion] = math.max(scores[emotion]!, sim); // Max pooling
        });
      }
    }

    return scores;
  }

  /// Calculates scoring weights for all candidate tags from historical thoughts.
  Map<String, double> getTagScores(String text, [List<Thought>? history]) {
    if (history == null || history.isEmpty) {
      return {};
    }

    final currentVector = vectorize(text);
    final bool isModelFailed = !_isModelLoaded; // Correctly check if TFLite model is unloaded
    final Map<String, double> tagScores = {};

    for (var thought in history) {
      double similarity = 0.0;
      if (isModelFailed) {
        // Fallback to Jaccard word-overlap similarity if ML model is unloaded
        similarity = _calculateTextJaccard(text, thought.textContent);
      } else {
        final pastVector = thought.embedding ?? vectorize(thought.textContent);
        similarity = calculateSimilarity(currentVector, pastVector);
      }

      // Use a lower threshold (0.05) for Jaccard overlap so single-word matches are captured, and 0.35 for dense ML vectors
      final double threshold = isModelFailed ? 0.05 : 0.35;
      if (similarity > threshold) {
        final weight = similarity; // Scale weight by similarity
        
        // Aggregate all categories and userTags
        final allTags = <String>{...thought.categories, ...thought.userTags};
        for (final tag in allTags) {
          if (tag == 'Reflection') continue; // Skip default tag to encourage learning specific tags
          tagScores[tag] = (tagScores[tag] ?? 0.0) + weight;
        }
      }
    }
    return tagScores;
  }

  /// Extracts categories from text dynamically by mining user's tagging patterns
  /// from historical thoughts using semantic similarity.
  List<String> extractCategories(String text, [List<Thought>? history]) {
    if (history == null || history.isEmpty) {
      // Fallback if no history exists: extract from vector anchors and default to Reflection if empty
      final analysis = analyze(text);
      final results = List<String>.from(analysis.suggestedTags);
      if (results.isEmpty) results.add('Reflection');
      return results;
    }

    final Map<String, double> tagScores = getTagScores(text, history);

    // Sort tags by accumulated score descending
    final sortedTags = tagScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Take the top recommended tags
    final results = sortedTags.map((e) => e.key).take(3).toList();
    
    // Add model-derived spatial tags (e.g. Focus, Calm) if they match the current vector
    final analysis = analyze(text);
    for (var tag in analysis.suggestedTags) {
      if (!results.contains(tag)) {
        results.add(tag);
      }
    }

    if (results.isEmpty) {
      results.add('Reflection');
    }

    return results;
  }

  /// Public Jaccard similarity utility wrapper for testing/diagnostics
  double calculateJaccard(String s1, String s2) {
    return _calculateTextJaccard(s1, s2);
  }

  /// Simple Jaccard similarity utility for text fallback
  double _calculateTextJaccard(String s1, String s2) {
    final clean1 = s1.toLowerCase().replaceAll(RegExp(r"[.,\/#!$%\^&\*;:{}=\-_`~()]"), " ");
    final clean2 = s2.toLowerCase().replaceAll(RegExp(r"[.,\/#!$%\^&\*;:{}=\-_`~()]"), " ");
    final set1 = clean1.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
    final set2 = clean2.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
    if (set1.isEmpty && set2.isEmpty) return 1.0;
    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;
    return intersection / union;
  }
}
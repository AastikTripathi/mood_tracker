import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/thought.dart';
import '../models/habit.dart';
import '../models/physical_log.dart';
import '../services/database_service.dart';
import '../services/nlp_service.dart';
import 'detailed_analytics_screen.dart'; // import emerald color constant or define locally

class DeveloperViewScreen extends StatefulWidget {
  final List<Thought> historyThoughts;
  final List<HabitDefinition> availableHabits;
  final List<HabitLog> allHabitLogs;
  final List<PhysicalLog> physicalLogs;
  final bool isTwilight;

  const DeveloperViewScreen({
    super.key,
    required this.historyThoughts,
    required this.availableHabits,
    required this.allHabitLogs,
    required this.physicalLogs,
    required this.isTwilight,
  });

  @override
  State<DeveloperViewScreen> createState() => _DeveloperViewScreenState();
}

class _DeveloperViewScreenState extends State<DeveloperViewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _db = DatabaseService();
  final NlpService _nlp = NlpService();

  // NLP Sandbox State
  final TextEditingController _nlpInputController = TextEditingController(
    text: "Feeling very anxious and tired today, but walking in the nature garden made me feel calm.",
  );
  Map<String, dynamic> _tokenizationResult = {};
  NlpAnalysis? _nlpAnalysis;
  double _vectorL2Norm = 0.0;
  double _vectorMin = 0.0;
  double _vectorMax = 0.0;
  double _vectorAvgAbs = 0.0;

  // Similarity Explorer State
  Thought? _selectedThoughtA;
  Thought? _selectedThoughtB;
  double _similarityScore = 0.0;
  double _dotProduct = 0.0;
  double _magnitudeA = 0.0;
  double _magnitudeB = 0.0;

  // Hybrid Similarity Explorer State
  double _hybridSimilarityScore = 0.0;
  double _moodSim = 0.0;
  double _semanticSim = 0.0;
  double _habitSim = 0.0;



  // Diagnostics loaded state
  Map<String, dynamic>? _regressionResults;
  Map<String, dynamic>? _habitMetrics;
  Map<String, dynamic>? _resilienceRoadmap;
  Map<String, String>? _causalCorrelations;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _nlpInputController.addListener(_runNlpAnalysis);
    _runNlpAnalysis();
    _initializeThoughtsForSimilarity();
    _loadEngineDiagnostics();
  }

  @override
  void dispose() {
    _nlpInputController.removeListener(_runNlpAnalysis);
    _nlpInputController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _runNlpAnalysis() {
    final text = _nlpInputController.text;
    if (text.isEmpty) {
      setState(() {
        _tokenizationResult = {'tokens': <String>[], 'ids': <int>[]};
        _nlpAnalysis = null;
        _vectorL2Norm = 0.0;
        _vectorMin = 0.0;
        _vectorMax = 0.0;
        _vectorAvgAbs = 0.0;
      });
      return;
    }

    final tok = _nlp.getDiagnosticTokenization(text);
    final analysis = _nlp.analyze(text);

    // Calculate embedding stats
    double sumSq = 0.0;
    double minVal = 999.0;
    double maxVal = -999.0;
    double sumAbs = 0.0;
    for (var val in analysis.vector) {
      sumSq += val * val;
      sumAbs += val.abs();
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
    }
    final l2Norm = math.sqrt(sumSq);
    final avgAbs = analysis.vector.isNotEmpty ? (sumAbs / analysis.vector.length) : 0.0;

    setState(() {
      _tokenizationResult = tok;
      _nlpAnalysis = analysis;
      _vectorL2Norm = l2Norm;
      _vectorMin = minVal;
      _vectorMax = maxVal;
      _vectorAvgAbs = avgAbs;
    });
  }

  void _initializeThoughtsForSimilarity() {
    if (widget.historyThoughts.length >= 2) {
      _selectedThoughtA = widget.historyThoughts[0];
      _selectedThoughtB = widget.historyThoughts[1];
      _calculateSimilarityScore();
    }
  }

  void _calculateSimilarityScore() {
    if (_selectedThoughtA == null || _selectedThoughtB == null) return;
    
    final tA = _selectedThoughtA!;
    final tB = _selectedThoughtB!;

    final vecA = tA.embedding ?? _nlp.vectorize(tA.textContent);
    final vecB = tB.embedding ?? _nlp.vectorize(tB.textContent);
    
    // Cache vectors if missing
    if (tA.embedding == null) tA.embedding = vecA;
    if (tB.embedding == null) tB.embedding = vecB;

    double dotProduct = 0.0;
    double magA = 0.0;
    double magB = 0.0;

    for (int i = 0; i < vecA.length; i++) {
      dotProduct += vecA[i] * vecB[i];
      magA += vecA[i] * vecA[i];
      magB += vecB[i] * vecB[i];
    }

    magA = math.sqrt(magA);
    magB = math.sqrt(magB);

    final double rawSemanticSim = (magA == 0 || magB == 0) ? 0.0 : (dotProduct / (magA * magB));

    final breakdown = _db.getHybridSimilarityBreakdown(tA, tB);

    setState(() {
      _dotProduct = dotProduct;
      _magnitudeA = magA;
      _magnitudeB = magB;
      _similarityScore = rawSemanticSim;
      _moodSim = breakdown['moodSim']!;
      _semanticSim = breakdown['semanticSim']!;
      _habitSim = breakdown['habitSim']!;
      _hybridSimilarityScore = breakdown['total']!;
    });
  }

  void _loadEngineDiagnostics() {
    setState(() {
      _regressionResults = _db.performRidgeRegression();
      _habitMetrics = _db.calculateHabitMetrics();
      _resilienceRoadmap = _db.findResilienceRoadmap();
      _causalCorrelations = _db.calculateLocalCausalCorrelations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark || widget.isTwilight;
    final primaryBg = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textThemeColor = isDark ? Colors.white70 : Colors.black87;
    final codeFontColor = isDark ? Colors.teal.shade200 : Colors.teal.shade700;

    return Scaffold(
      backgroundColor: primaryBg,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.terminal_rounded, color: Colors.teal),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Engine Diagnostics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("On-device ML & Math Inspections", style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black45)),
              ],
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.teal,
          unselectedLabelColor: isDark ? Colors.white38 : Colors.black45,
          indicatorColor: Colors.teal,
          tabs: const [
            Tab(text: "NLP Sandbox"),
            Tab(text: "Semantic Similarity"),
            Tab(text: "Pearson Correlation"),
            Tab(text: "Ridge Regression"),
            Tab(text: "Routine Synergy"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNlpSandboxTab(isDark, cardColor, textThemeColor, codeFontColor),
          _buildSimilarityTab(isDark, cardColor, textThemeColor, codeFontColor),
          _buildPearsonTab(isDark, cardColor, textThemeColor, codeFontColor),
          _buildRidgeTab(isDark, cardColor, textThemeColor, codeFontColor),
          _buildSynergyTab(isDark, cardColor, textThemeColor, codeFontColor),
        ],
      ),
    );
  }

  // TAB 1: NLP WordPiece Tokenizer & Embedding Sandbox
  Widget _buildNlpSandboxTab(bool isDark, Color cardBg, Color textColor, Color codeColor) {
    final tokens = _tokenizationResult['tokens'] as List<String>? ?? [];
    final ids = _tokenizationResult['ids'] as List<int>? ?? [];
    final isModelLoaded = _nlp.isModelLoaded;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTabHeader("WordPiece Tokenizer & Transformer Sandbox", "Inspect raw token splits and ML coordinate outputs from the on-device transformer model in real-time."),
          const SizedBox(height: 16),
          
          // Sandbox Controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.teal.withOpacity(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        "Input Log Text (Real-time evaluation)", 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isModelLoaded ? emerald.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: isModelLoaded ? emerald : Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            isModelLoaded ? "TFLite Model Active" : "TFLite Unloaded",
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isModelLoaded ? emerald : Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nlpInputController,
                  maxLines: 3,
                  style: TextStyle(fontSize: 13, color: textColor),
                  decoration: InputDecoration(
                    hintText: "Type something to observe neural network diagnostics...",
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.teal.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.teal, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // WordPiece Tokenizer Output
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("1. WordPiece Token Splits & Vocabulary IDs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                const Text("Transformer engines require text split into sub-word tokens with CLS (start) and SEP (end) tags.", style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                const SizedBox(height: 12),
                if (tokens.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(12), child: Text("No tokens generated. Input text.", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey))))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(tokens.length, (index) {
                      final token = tokens[index];
                      final id = ids[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.teal.withOpacity(0.08) : Colors.teal.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.teal.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Text(token, style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: codeColor)),
                            const SizedBox(height: 2),
                            Text("ID: $id", style: const TextStyle(fontSize: 8.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 384D Coordinate Embeddings
          if (_nlpAnalysis != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("2. Dense Vector Coordinate Profile (384D)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text("Dim: ${_nlpAnalysis!.vector.length}", style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: codeColor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text("The transformer projects input tokens into a 384-dimensional mathematical space.", style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                  const SizedBox(height: 14),

                  // Embedding Stats Grid
                  Row(
                    children: [
                      Expanded(child: _buildMetricItem("L2 Vector Norm", _vectorL2Norm.toStringAsFixed(4), isDark)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMetricItem("Mean Abs Value", _vectorAvgAbs.toStringAsFixed(4), isDark)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMetricItem("Coordinate Range", "${_vectorMin.toStringAsFixed(2)} to ${_vectorMax.toStringAsFixed(2)}", isDark)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text("First 24 Coordinates Profile:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 10),
                  
                  // Visual bar chart for coordinates
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: math.min(24, _nlpAnalysis!.vector.length),
                    itemBuilder: (context, idx) {
                      final val = _nlpAnalysis!.vector[idx];
                      final double ratio = (val.abs() / 0.25).clamp(0.0, 1.0);
                      final Color barColor = val >= 0 ? Colors.teal : Colors.orangeAccent;
                      return Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.withOpacity(0.05)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("D$idx", style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              (val >= 0 ? "+" : "") + val.toStringAsFixed(3),
                              style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: textColor, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            // Simple linear gauge bar
                            Stack(
                              children: [
                                Container(height: 2, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                                FractionallySizedBox(
                                  widthFactor: ratio,
                                  child: Container(height: 2, color: barColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Semantic Emotion & Sentiment Extraction
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("3. Semantic Emotion & Sentiment Extraction", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text("The NLP engine calculates the semantic similarity of the text to baseline emotion profiles.", style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                  const SizedBox(height: 14),

                  Builder(
                    builder: (context) {
                      final isModelFailed = !_nlp.isModelLoaded;
                      final double threshold = isModelFailed ? 0.05 : 0.20;
                      final emotionScores = _nlp.getEmotionScores(_nlpInputController.text);

                      if (emotionScores.isEmpty) {
                        return const Text(
                          "No emotion scores calculated (input some text to analyze).",
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                        );
                      }

                      // Sort emotions by score descending (highest matching first)
                      final sortedEmotions = emotionScores.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));

                      return Column(
                        children: [
                          ...sortedEmotions.map((entry) {
                            final emotion = entry.key;
                            final score = entry.value;
                            final bool isPassed = score >= threshold;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(emotion, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text(
                                          "Similarity: ${score.toStringAsFixed(4)} (Threshold: > ${threshold.toStringAsFixed(2)})",
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPassed ? Colors.teal.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isPassed ? Colors.teal.withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      isPassed ? "PASS" : "FAIL",
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isPassed ? Colors.teal : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const Divider(height: 16),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              const Text("Extracted Emotion Tags: ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                              if (_nlpAnalysis == null || _nlpAnalysis!.suggestedTags.isEmpty)
                                const Text("None", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey))
                              else
                                ..._nlpAnalysis!.suggestedTags.map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.teal.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                  child: Text(tag, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.teal)),
                                )),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Keyword fallbacks
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("4. Dynamic Tag & Category Learning", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text("Calculates similarity weight scores for each tag dynamically based on past thoughts and user tagging patterns.", style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                  const SizedBox(height: 14),
                  Builder(
                    builder: (context) {
                      final tagScores = _nlp.getTagScores(_nlpInputController.text, widget.historyThoughts);
                      final finalRecommended = _nlp.extractCategories(_nlpInputController.text, widget.historyThoughts);

                      if (tagScores.isEmpty) {
                        return const Text(
                          "No historical tags matched (type keywords that match your past journal entries).",
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                        );
                      }

                      // Find max score in the map to normalize progress bar width
                      final maxScore = tagScores.values.fold(0.001, (prev, val) => val > prev ? val : prev);

                      // Sort tags by score descending
                      final sortedScores = tagScores.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...sortedScores.map((entry) {
                            final tag = entry.key;
                            final score = entry.value;
                            final double ratio = (score / maxScore).clamp(0.0, 1.0);

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(tag, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      Text(
                                        "Weight Score: ${score.toStringAsFixed(3)}",
                                        style: TextStyle(fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: codeColor),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Stack(
                                    children: [
                                      Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: ratio,
                                        child: Container(
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: Colors.teal,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const Divider(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text("Recommended Tags: ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: finalRecommended.map((tag) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.teal.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                    child: Text(tag, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.teal)),
                                  )).toList(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Historically Matched Thoughts
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.teal.withOpacity(0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("5. Historically Matched Thoughts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text("Displaying past journal entries that semantically align with the sandbox input query.", style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                  const SizedBox(height: 14),

                  Builder(
                    builder: (context) {
                      final isModelFailed = !_nlp.isModelLoaded;
                      final double threshold = isModelFailed ? 0.05 : 0.35;
                      final currentVector = _nlp.vectorize(_nlpInputController.text);

                      // Calculate similarities for all thoughts
                      final List<MapEntry<Thought, double>> matched = [];
                      for (final thought in widget.historyThoughts) {
                        double similarity = 0.0;
                        if (isModelFailed) {
                          similarity = _nlp.calculateJaccard(_nlpInputController.text, thought.textContent);
                        } else {
                          final pastVector = thought.embedding ?? _nlp.vectorize(thought.textContent);
                          similarity = _nlp.calculateSimilarity(currentVector, pastVector);
                        }

                        if (similarity >= threshold) {
                          matched.add(MapEntry(thought, similarity));
                        }
                      }

                      // Sort by similarity descending
                      matched.sort((a, b) => b.value.compareTo(a.value));

                      if (matched.isEmpty) {
                        return const Text(
                          "No historical thoughts matched this query (threshold is >= 0.35).",
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                        );
                      }

                      return Column(
                        children: matched.take(5).map((entry) {
                          final thought = entry.key;
                          final similarity = entry.value;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.teal.withOpacity(0.1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "${thought.timestamp.day}/${thought.timestamp.month}/${thought.timestamp.year} (Mood: ${thought.moodScore})",
                                      style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.teal.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        "Sim: ${similarity.toStringAsFixed(3)}",
                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.teal),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  thought.textContent,
                                  style: TextStyle(fontSize: 11.5, color: textColor),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: [
                                    ...thought.categories.map((cat) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        cat,
                                        style: TextStyle(fontSize: 8.5, color: isDark ? Colors.white70 : Colors.black54),
                                      ),
                                    )),
                                    ...thought.userTags.map((tag) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tag,
                                        style: const TextStyle(fontSize: 8.5, color: Colors.indigo),
                                      ),
                                    )),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignalRow({
    required int index,
    required String tagName,
    required double value,
    required double threshold,
    required bool isDark,
  }) {
    final bool isPassed = value.abs() > threshold;
    final color = isPassed ? emerald : Colors.grey;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tagName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text(
                "Coordinate Index $index: Value = ${value.toStringAsFixed(4)} (Threshold: absolute value > $threshold)",
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            isPassed ? "PASS" : "FAIL",
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  // TAB 2: Semantic Similarity Explorer
  Widget _buildSimilarityTab(bool isDark, Color cardBg, Color textColor, Color codeColor) {
    if (widget.historyThoughts.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.psychology_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                "Need at least 2 saved thoughts",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                "Seed the database sandbox or enter notes to compare embedding alignments.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final isLinked = _hybridSimilarityScore >= 0.55;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTabHeader("Semantic Alignment & Cosine Similarity Inspector", "Select two thoughts and calculate how the spatial vector alignments and links are generated."),
          const SizedBox(height: 16),

          // Selectors
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Select Thought A", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal)),
                const SizedBox(height: 6),
                DropdownButton<Thought>(
                  isExpanded: true,
                  value: _selectedThoughtA,
                  items: widget.historyThoughts.map((t) {
                    return DropdownMenuItem<Thought>(
                      value: t,
                      child: Text(
                        "(${t.moodScore}/10) \"${t.textContent.length > 60 ? '${t.textContent.substring(0, 60)}...' : t.textContent}\"",
                        style: TextStyle(fontSize: 12, color: textColor),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedThoughtA = val;
                      _calculateSimilarityScore();
                    });
                  },
                ),
                const SizedBox(height: 16),

                const Text("Select Thought B", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal)),
                const SizedBox(height: 6),
                DropdownButton<Thought>(
                  isExpanded: true,
                  value: _selectedThoughtB,
                  items: widget.historyThoughts.map((t) {
                    return DropdownMenuItem<Thought>(
                      value: t,
                      child: Text(
                        "(${t.moodScore}/10) \"${t.textContent.length > 60 ? '${t.textContent.substring(0, 60)}...' : t.textContent}\"",
                        style: TextStyle(fontSize: 12, color: textColor),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedThoughtB = val;
                      _calculateSimilarityScore();
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Hybrid Day Similarity Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Unified Hybrid Day Similarity Breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                const Text("Combines mood score alignment (40%), semantic vectors (30%), and habits overlap (30%).", style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                const SizedBox(height: 16),

                // Unified Similarity Score
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Unified Similarity Score", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                    Text(
                      _hybridSimilarityScore.toStringAsFixed(4),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isLinked ? emerald : Colors.orangeAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Hybrid Visual Gauge
                Stack(
                  children: [
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (_hybridSimilarityScore.clamp(0.0, 1.0)),
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: isLinked ? emerald : Colors.orangeAccent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                    Positioned(
                      left: MediaQuery.of(context).size.width * 0.44, // 0.55 center marker estimate
                      child: Container(
                        width: 2,
                        height: 14,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("0.0 (Different)", style: TextStyle(fontSize: 8.5, color: Colors.grey)),
                    Text("0.55 Linking Threshold (Red)", style: TextStyle(fontSize: 8.5, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    Text("1.0 (Identical Day)", style: TextStyle(fontSize: 8.5, color: Colors.grey)),
                  ],
                ),
                const Divider(height: 24),

                // 1. Mood Similarity details
                _buildHybridParameterRow(
                  label: "1. Mood Alignment Similarity (Weight: 40%)",
                  value: _moodSim,
                  contribution: _moodSim * 0.4,
                  detailsText: "Mood A: ${_selectedThoughtA!.moodScore}/10 vs Mood B: ${_selectedThoughtB!.moodScore}/10  •  Diff: ${(_selectedThoughtA!.moodScore - _selectedThoughtB!.moodScore).abs()}. If diff > 1, similarity drops to 0.0.",
                  color: Colors.teal,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // 2. Semantic Text Similarity details
                _buildHybridParameterRow(
                  label: "2. Semantic Text Similarity (Weight: 30%)",
                  value: _semanticSim,
                  contribution: _semanticSim * 0.3,
                  detailsText: "Cosine similarity of dense sentence embeddings.",
                  color: Colors.indigoAccent,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // 3. Habitual Overlap details
                Builder(
                  builder: (context) {
                    final habitsA = _db.getHabitsForDay(_selectedThoughtA!.timestamp);
                    final habitsB = _db.getHabitsForDay(_selectedThoughtB!.timestamp);
                    final overlapList = habitsA.intersection(habitsB);

                    return _buildHybridParameterRow(
                      label: "3. Habitual Overlap Similarity (Weight: 30%)",
                      value: _habitSim,
                      contribution: _habitSim * 0.3,
                      detailsText: "Jaccard intersection of logged habits.\n"
                          "Day A: {${habitsA.isEmpty ? 'None' : habitsA.join(', ')}}\n"
                          "Day B: {${habitsB.isEmpty ? 'None' : habitsB.join(', ')}}\n"
                          "Overlap: {${overlapList.isEmpty ? 'None' : overlapList.join(', ')}}",
                      color: Colors.orange,
                      isDark: isDark,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Math Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("TFLite Dense Vector Similarity details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 14),

                // Formula Widget
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      "Cosine Similarity = (A · B) / (||A|| * ||B||)",
                      style: TextStyle(fontSize: 12.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: codeColor),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _buildMathRow("Dot Product (A · B)", _dotProduct.toStringAsFixed(6)),
                _buildMathRow("Vector Magnitude ||A||", _magnitudeA.toStringAsFixed(6)),
                _buildMathRow("Vector Magnitude ||B||", _magnitudeB.toStringAsFixed(6)),
                const Divider(height: 20),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Raw Cosine Score (Text-Only)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      _similarityScore.toStringAsFixed(4),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Linking logic
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLinked ? emerald.withOpacity(0.05) : Colors.orangeAccent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isLinked ? emerald.withOpacity(0.2) : Colors.orangeAccent.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isLinked ? Icons.link : Icons.link_off,
                      color: isLinked ? emerald : Colors.orangeAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isLinked ? "Thoughts Linked Successfully" : "Thoughts Too Distant to Link",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isLinked ? emerald : Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (isLinked) ...[
                  const Text("Generated Connection Insight:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    _getConnectionReasonMock(_selectedThoughtA!, _selectedThoughtB!),
                    style: TextStyle(fontSize: 12, color: textColor, fontStyle: FontStyle.italic),
                  ),
                ] else
                  const Text("Hybrid similarity is below the required 0.55 threshold. The system keeps these thoughts separate.", style: TextStyle(fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Organic Semantic Thought Clusters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.teal.withOpacity(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Organic Semantic Thought Clusters", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                const Text("Groups your history dynamically into clusters where thoughts are semantically close (threshold >= 0.55).", style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                const SizedBox(height: 14),

                Builder(
                  builder: (context) {
                    final clusters = _db.clusterHistory(clusterThreshold: 0.55);

                    if (clusters.isEmpty) {
                      return const Text(
                        "No semantic clusters could be generated (database sandbox is empty).",
                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                      );
                    }

                    return Column(
                      children: List.generate(clusters.length, (idx) {
                        final cluster = clusters[idx];
                        final centroid = cluster.first;
                        
                        // Calculate average mood
                        double sumMood = 0;
                        for (final t in cluster) {
                          sumMood += t.moodScore;
                        }
                        final double avgMood = sumMood / cluster.length;

                        // Get topic preview
                        final words = centroid.textContent.split(' ');
                        final topicPreview = words.take(5).join(' ') + (words.length > 5 ? '...' : '');

                        // Aggregate unique categories across the cluster
                        final allClusterTags = cluster.expand((t) => {...t.categories, ...t.userTags}).toSet().take(5);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.teal.withOpacity(0.08)),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: Text(
                                "Cluster ${idx + 1}: \"$topicPreview\"",
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      "${cluster.length} entries  •  Avg Mood: ${avgMood.toStringAsFixed(1)}",
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                    ...allClusterTags.map((tag) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        tag,
                                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.teal),
                                      ),
                                    )),
                                  ],
                                ),
                              ),
                              children: [
                                const Divider(height: 1),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: cluster.map((thought) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "• ",
                                              style: TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    thought.textContent,
                                                    style: TextStyle(fontSize: 11.5, color: textColor),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    "${thought.timestamp.day}/${thought.timestamp.month}/${thought.timestamp.year} (Mood: ${thought.moodScore}/10)",
                                                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getConnectionReasonMock(Thought tA, Thought tB) {
    final curMood = tA.moodScore;
    final pastMood = tB.moodScore;
    
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = "${months[tB.timestamp.month - 1]} ${tB.timestamp.day.toString().padLeft(2, '0')}";

    if (curMood <= 4 && pastMood <= 4) {
      return "You experienced a similar quiet headspace on $dateStr. You made your way through it then.";
    } else if (curMood >= 7 && pastMood >= 7) {
      return "This connects with the bright energy you felt on $dateStr.";
    } else if (curMood <= 4 && pastMood >= 7) {
      return "A reminder of the bright moment you captured on $dateStr: \"${tB.textContent}\"";
    } else {
      return "Semantically connected to your reflection from $dateStr.";
    }
  }

  Widget _buildMathRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildHybridParameterRow({
    required String label,
    required double value,
    required double contribution,
    required String detailsText,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "Sim: ${value.toStringAsFixed(3)} (+$contribution)",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: (value.clamp(0.0, 1.0)),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          detailsText,
          style: const TextStyle(fontSize: 9.5, color: Colors.grey, height: 1.2),
        ),
      ],
    );
  }

  // TAB 3: Pearson Correlation diagnostics
  Widget _buildPearsonTab(bool isDark, Color cardBg, Color textColor, Color codeColor) {
    if (_causalCorrelations == null || widget.historyThoughts.isEmpty || widget.physicalLogs.isEmpty) {
      return _buildNoDataPlaceholder();
    }

    final sleepCorrStr = _causalCorrelations!['sleepCorrelation'] ?? '0.00';
    final cycleCorrStr = _causalCorrelations!['cycleCorrelation'] ?? '0.00';
    final seizureCorrStr = _causalCorrelations!['seizureCorrelation'] ?? '0.00';
    final painCorrStr = _causalCorrelations!['painCorrelation'] ?? '0.00';

    final double sleepCorr = double.tryParse(sleepCorrStr) ?? 0.0;
    final double cycleCorr = double.tryParse(cycleCorrStr) ?? 0.0;
    final double seizureCorr = double.tryParse(seizureCorrStr) ?? 0.0;
    final double painCorr = double.tryParse(painCorrStr) ?? 0.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTabHeader("Pearson Causal Correlation diagnostics", "Inspect how raw Sleep, Period cycle, Seizures, and Pain parameters align with Mood score trends."),
          const SizedBox(height: 16),

          // Math formula
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Pearson Coefficient (r) Equation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      "r = cov(X, Y) / (std(X) * std(Y))",
                      style: TextStyle(fontSize: 12.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: codeColor),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "r > +0.5 indicates strong positive correlation. r < -0.4 indicates strong negative correlation.",
                  style: TextStyle(fontSize: 10.5, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Computed results
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Computed Correlation Outputs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 16),

                _buildCorrelationMeter(
                  label: "Sleep Hours vs Mood Score",
                  score: sleepCorr,
                  helpText: "Positive (+) means more sleep improves mood; negative (-) means sleep triggers fatigue.",
                  isDark: isDark,
                ),
                const Divider(height: 24),
                _buildCorrelationMeter(
                  label: "Period Active vs Mood Score",
                  score: cycleCorr,
                  helpText: "Negative (-) means active menstruation days decrease mood averages.",
                  isDark: isDark,
                ),
                const Divider(height: 24),
                _buildCorrelationMeter(
                  label: "Seizure Incidents vs Mood Score",
                  score: seizureCorr,
                  helpText: "Negative (-) means seizure incidents strongly align with drops in mood.",
                  isDark: isDark,
                ),
                const Divider(height: 24),
                _buildCorrelationMeter(
                  label: "Chronic Pain Level vs Mood Score",
                  score: painCorr,
                  helpText: "Negative (-) means higher physical pain levels match lower daily mood scores.",
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Insight message generated
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.teal.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.lightbulb_outline, color: Colors.teal, size: 18),
                    SizedBox(width: 8),
                    Text("Triggered Insight Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _causalCorrelations!['status'] ?? 'No Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  _causalCorrelations!['insight'] ?? 'No Insight',
                  style: TextStyle(fontSize: 12, color: textColor, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrelationMeter({
    required String label,
    required double score,
    required String helpText,
    required bool isDark,
  }) {
    final color = score >= 0.4 ? emerald : (score <= -0.4 ? Colors.redAccent : Colors.grey);
    // Normalized value from -1 to 1 into width factor 0 to 1
    final double widthFactor = ((score + 1.0) / 2.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            Text(
              score.toStringAsFixed(2),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(helpText, style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
        const SizedBox(height: 10),
        Stack(
          children: [
            Container(height: 6, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(3))),
            FractionallySizedBox(
              widthFactor: widthFactor,
              child: Container(
                height: 6,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Positioned(
              left: MediaQuery.of(context).size.width * 0.41, // ~center (0.0)
              child: Container(width: 1, height: 6, color: isDark ? Colors.white24 : Colors.black26),
            ),
          ],
        ),
      ],
    );
  }

  // TAB 4: Ridge Regression Diagnostics
  Widget _buildRidgeTab(bool isDark, Color cardBg, Color textColor, Color codeColor) {
    if (_regressionResults == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.query_stats_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text("Ridge Regression Unlocked at N >= 10", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              const Text(
                "Please seed the mock database sandbox to review Isolated Confounder-free parameter beta weights.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final coeffs = _regressionResults!['coefficients'] as Map<String, double>;
    final sampleSize = _regressionResults!['sampleSize'] as int;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTabHeader("Ridge Regression Matrix Diagnostics", "Ridge Regression isolates the independent influence of each parameter, penalizing variables to prevent multicollinearity."),
          const SizedBox(height: 16),

          // Math Equation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Ridge Regression Loss Penalty Equation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      "beta = (X^T * X + lambda * I)^-1 * X^T * y",
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: codeColor),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Hyperparameter Lambda (L2 Regularization Weight) = 1.0\nMatrix size XtX: [M x M] where M = ${coeffs.length} features.\nDataset rows (N): $sampleSize entries.",
                  style: const TextStyle(fontSize: 10, color: Colors.grey, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Computed Beta coefficients
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Estimated Beta Weights (Coefficients)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 14),
                ...coeffs.entries.map((entry) {
                  return _buildBetaRow(
                    feature: entry.key,
                    val: entry.value,
                    isDark: isDark,
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetaRow({
    required String feature,
    required double val,
    required bool isDark,
  }) {
    final bool isPositive = val >= 0;
    final color = isPositive ? emerald : Colors.redAccent;
    // Map -2.0 to +2.0 to 0.0 to 1.0 width factor
    final double ratio = ((val + 1.5) / 3.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatFeatureName(feature),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              Text(
                (isPositive ? "+" : "") + val.toStringAsFixed(4),
                style: TextStyle(fontSize: 11.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(height: 4, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(2))),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Positioned(
                left: MediaQuery.of(context).size.width * 0.41, // ~center (0.0)
                child: Container(width: 1, height: 4, color: isDark ? Colors.white24 : Colors.black26),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatFeatureName(String raw) {
    switch (raw) {
      case 'intercept': return 'Baseline Intercept (c)';
      case 'pain': return 'Chronic Pain Index';
      case 'seizures': return 'Seizure Incident Count';
      case 'isPeriodDay': return 'Active Menstruation Cycle';
      case 'externalShockShield': return 'External Stress Shield Active';
      default:
        if (raw.startsWith('habit_')) {
          String id = raw.replaceFirst('habit_', '');
          String lagStr = '';
          if (id.endsWith('_lag0')) {
            id = id.substring(0, id.length - 5);
            lagStr = ' (Today)';
          } else if (id.endsWith('_lag1')) {
            id = id.substring(0, id.length - 5);
            lagStr = ' (Yesterday)';
          } else if (id.endsWith('_lag2')) {
            id = id.substring(0, id.length - 5);
            lagStr = ' (2 Days Ago)';
          } else if (id.endsWith('_lag3')) {
            id = id.substring(0, id.length - 5);
            lagStr = ' (3 Days Ago)';
          }

          final match = widget.availableHabits.cast<HabitDefinition?>().firstWhere(
            (h) => h!.id == id || h.name == id,
            orElse: () => null,
          );
          return match != null
              ? "Routine: ${match.iconEmoji} ${match.name}$lagStr"
              : "Routine: $id$lagStr";
        }
        return raw;
    }
  }

  // TAB 5: Synergy & Habit Metrics Tab
  Widget _buildSynergyTab(bool isDark, Color cardBg, Color textColor, Color codeColor) {
    if (_habitMetrics == null) {
      return _buildNoDataPlaceholder();
    }

    final baselines = _habitMetrics!['baselineWeights'] as Map<String, double>? ?? {};
    final synergies = _habitMetrics!['synergies'] as Map<String, double>? ?? {};
    final decays = _habitMetrics!['decays'] as Map<String, double>? ?? {};

    if (baselines.isEmpty && synergies.isEmpty && decays.isEmpty) {
      return _buildNoDataPlaceholder();
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTabHeader("Routine Synergy & Habituation Diagnostics", "Inspect compound habits done together, baseline deviation scores, and novelty response decay values."),
          const SizedBox(height: 16),

          // Baseline weight deviation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Baseline Habit Weights", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                const Text("Formula: weight = avg_mood_on_habit_days - baseline_mood", style: TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 14),

                if (baselines.isEmpty)
                  const Text("No baseline weights computed yet.", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey))
                else
                  ...baselines.entries.map((entry) {
                    final h = widget.availableHabits.cast<HabitDefinition?>().firstWhere((habit) => habit!.id == entry.key || habit.name == entry.key, orElse: () => null);
                    final name = h != null ? "${h.iconEmoji} ${h.name}" : entry.key;
                    final val = entry.value;
                    final isPositive = val >= 0;
                    final color = isPositive ? emerald : Colors.redAccent;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          Text(
                            (isPositive ? "+" : "") + val.toStringAsFixed(2),
                            style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: color),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Synergies
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Compound Synergy Boosts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                const Text("Formula: synergy = pair_weight - (w1 + w2)", style: TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 14),

                if (synergies.isEmpty)
                  const Text("No active synergistic combinations found.", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey))
                else
                  ...synergies.entries.map((entry) {
                    final parts = entry.key.split('+');
                    final h1 = widget.availableHabits.cast<HabitDefinition?>().firstWhere((h) => h!.id == parts[0] || h.name == parts[0], orElse: () => null);
                    final h2 = widget.availableHabits.cast<HabitDefinition?>().firstWhere((h) => h!.id == parts[1] || h.name == parts[1], orElse: () => null);
                    final name1 = h1 != null ? "${h1.iconEmoji} ${h1.name}" : parts[0];
                    final name2 = h2 != null ? "${h2.iconEmoji} ${h2.name}" : parts[1];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text("$name1 + $name2", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: emerald.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              "+${entry.value.toStringAsFixed(2)} boost",
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: emerald),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Novelty Decay
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Stagnation / Decay Warnings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                const Text("Formula: decay = recent_weight - lifetime_weight", style: TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 14),

                if (decays.isEmpty)
                  const Text("No routine decay warnings active.", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey))
                else
                  ...decays.entries.map((entry) {
                    final h = widget.availableHabits.cast<HabitDefinition?>().firstWhere((habit) => habit!.id == entry.key || habit.name == entry.key, orElse: () => null);
                    final name = h != null ? "${h.iconEmoji} ${h.name}" : entry.key;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          Text(
                            entry.value.toStringAsFixed(2),
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataPlaceholder() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_customize_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("Diagnostics Unavailable", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            const Text(
              "Not enough saved logs to evaluate metrics. Log more data or use the mock database seeder.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabHeader(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: -0.3, color: Colors.teal),
        ),
        const SizedBox(height: 4),
        Text(
          desc,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

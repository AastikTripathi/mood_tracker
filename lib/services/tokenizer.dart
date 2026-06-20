import 'dart:math' as math;

class TokenizerResult {
  final List<int> tokenIds;
  final List<int> attentionMask;

  TokenizerResult({required this.tokenIds, required this.attentionMask});
}

class WordPieceTokenizer {
  final Map<String, int> vocab;
  final int maxSeqLen;

  WordPieceTokenizer(String vocabContent, {this.maxSeqLen = 128}) : vocab = _parseVocab(vocabContent);

  static Map<String, int> _parseVocab(String content) {
    final Map<String, int> map = {};
    final lines = content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) {
        map[line] = i;
      }
    }
    return map;
  }

  TokenizerResult tokenize(String text) {
    final List<int> ids = [101]; // [CLS]
    
    // Simple basic text cleaning
    final cleanText = text.toLowerCase().replaceAll(RegExp(r"[^\w\s']"), " ");
    final words = cleanText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    for (var word in words) {
      final subTokens = _wordpiece(word);
      for (var token in subTokens) {
        final id = vocab[token];
        if (id != null) {
          ids.add(id);
        } else {
          ids.add(100); // [UNK]
        }
      }
    }

    ids.add(102); // [SEP]

    // Pad or truncate to maxSeqLen
    final List<int> tokenIds = List.filled(maxSeqLen, 0);
    final List<int> attentionMask = List.filled(maxSeqLen, 0);

    final limit = math.min(maxSeqLen, ids.length);
    for (int i = 0; i < limit; i++) {
      tokenIds[i] = ids[i];
      attentionMask[i] = 1;
    }

    return TokenizerResult(tokenIds: tokenIds, attentionMask: attentionMask);
  }

  List<String> _wordpiece(String word) {
    if (vocab.containsKey(word)) {
      return [word];
    }

    final List<String> subTokens = [];
    int start = 0;
    
    while (start < word.length) {
      int end = word.length;
      String? curSubstr;
      
      while (start < end) {
        String substr = word.substring(start, end);
        if (start > 0) {
          substr = "##$substr";
        }
        if (vocab.containsKey(substr)) {
          curSubstr = substr;
          break;
        }
        end--;
      }
      
      if (curSubstr == null) {
        return ["[UNK]"];
      }
      
      subTokens.add(curSubstr);
      start = end;
    }
    
    return subTokens;
  }
}

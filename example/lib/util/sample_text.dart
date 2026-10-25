const _words = [
  "list",
  "sliver",
  "scroll",
  "offset",
  "extent",
  "viewport",
  "render",
  "layout",
  "item",
  "jump",
  "leap",
  "estimate",
  "measure",
  "paint",
  "frame",
  "anchor",
  "header",
  "align",
  "snap",
  "build",
  "widget",
  "pixel",
  "tree",
  "cache",
  "range",
  "sticky",
  "chat",
  "message",
  "section",
  "index",
];

/// Deterministic pseudo random number in `[0, max)` for [seed].
int hashed(int seed, int max) {
  var h = (seed ^ 0x9E3779B9) * 2654435761;
  h = (h ^ (h >> 15)) & 0x7fffffff;
  return h % max;
}

/// A sentence of [wordCount] words that depends only on [seed].
String sampleText(int seed, int wordCount) {
  final buffer = StringBuffer();
  for (var i = 0; i < wordCount; ++i) {
    if (i > 0) {
      buffer.write(" ");
    }
    buffer.write(_words[hashed(seed * 131 + i, _words.length)]);
  }
  final text = buffer.toString();
  return "${text[0].toUpperCase()}${text.substring(1)}.";
}

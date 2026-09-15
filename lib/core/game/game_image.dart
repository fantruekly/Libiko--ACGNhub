const Map<String, String> galgameZywzImageHeaders = {
  'Referer': 'https://game.galgamezywz.org/',
};

const Map<String, String> nekogalImageHeaders = {
  'Referer': 'https://www.nekogal.com/',
};

Map<String, String> gameImageHeadersFor(String? url) {
  if (url != null && url.contains('nekogal')) return nekogalImageHeaders;
  return galgameZywzImageHeaders;
}

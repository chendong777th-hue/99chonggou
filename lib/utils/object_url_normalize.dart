String normalizeObjectUrl(String url) {
  if (url.isEmpty) {
    return url;
  }
  final schemeIndex = url.indexOf('://');
  if (schemeIndex == -1) {
    return url.replaceAll('#', '%23');
  }
  final hostPathSeparator = url.indexOf('/', schemeIndex + 3);
  if (hostPathSeparator == -1) {
    return url;
  }
  final queryIndex = url.indexOf('?', hostPathSeparator);
  final prefix = url.substring(0, hostPathSeparator);
  final rawPath = queryIndex == -1
      ? url.substring(hostPathSeparator)
      : url.substring(hostPathSeparator, queryIndex);
  final query = queryIndex == -1 ? '' : url.substring(queryIndex);
  final encodedPath = rawPath.split('/').map((segment) {
    if (segment.isEmpty) {
      return '';
    }
    try {
      return Uri.encodeComponent(Uri.decodeComponent(segment));
    } catch (_) {
      return Uri.encodeComponent(segment);
    }
  }).join('/');
  return '$prefix$encodedPath$query';
}

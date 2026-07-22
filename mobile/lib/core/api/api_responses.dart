T unwrap<T>(dynamic body, T Function(dynamic data) parse) {
  if (body is Map<String, dynamic> && body.containsKey('data')) {
    return parse(body['data']);
  }
  return parse(body);
}

List<T> unwrapList<T>(dynamic body, T Function(dynamic item) parse) {
  return unwrap<List<T>>(body, (data) {
    if (data is! List) return <T>[];
    return data.map(parse).toList();
  });
}
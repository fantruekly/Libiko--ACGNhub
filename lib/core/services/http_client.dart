import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

class HttpClient {
  static final HttpClient _instance = HttpClient._();
  factory HttpClient() => _instance;
  HttpClient._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    },
  ));

  Future<Response> get(String url, {Map<String, String>? headers}) async {
    return _dio.get(url, options: Options(headers: headers));
  }

  Future<Response> post(String url, {dynamic data, Map<String, String>? headers}) async {
    return _dio.post(url, data: data, options: Options(headers: headers));
  }

  Future<dom.Document> getHtml(String url, {Map<String, String>? headers}) async {
    final response = await get(url, headers: headers);
    return html_parser.parse(response.data.toString());
  }

  void setCookie(String url, String name, String value) {
    _dio.options.headers['Cookie'] = '$name=$value';
  }
}
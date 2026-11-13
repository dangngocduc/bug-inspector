import 'package:dio/dio.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

/// The recorder of the API calls of the example, given to
/// `FlutterQaInspector.install` in `main.dart`.
///
/// `GET /comments` answers about 150 KB of JSON: the bodies are kept up to
/// 256 KB, instead of the default 16 KB, so the report can open them as a
/// JSON tree. The comments hold e-mail addresses: `email` joins the
/// redacted fields, so the report shows `REDACTED` instead.
BugNetworkRecorder exampleNetworkRecorder() => BugNetworkRecorder(
      maxBodyLength: 256 * 1024,
      redactedFields: {...BugNetworkRecorder.defaultRedactedFields, 'email'},
    );

/// The Dio client of https://jsonplaceholder.typicode.com, a public fake
/// REST API: the example calls it over the network.
final Dio jsonPlaceholderDio = createJsonPlaceholderDio();

/// Creates the client. Tests pass an [adapter] that answers without the
/// network.
Dio createJsonPlaceholderDio({HttpClientAdapter? adapter}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  // Only in builds made with --dart-define=FLUTTER_QA_INSPECTOR=true. Last,
  // after the interceptors that change the request.
  if (BugInspector.enabledFromEnvironment) {
    dio.interceptors.add(const BugInspectorDioInterceptor());
  }
  return dio;
}

/// A comment of jsonplaceholder.
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.name,
    required this.email,
    required this.body,
  });

  factory Comment.fromJson(Map<String, Object?> json) => Comment(
        id: json['id']! as int,
        postId: json['postId']! as int,
        name: json['name']! as String,
        email: json['email']! as String,
        body: json['body']! as String,
      );

  final int id;
  final int postId;
  final String name;
  final String email;
  final String body;
}

/// `GET /comments` and `GET /comments/{id}`.
class CommentsApi {
  CommentsApi([Dio? dio]) : _dio = dio ?? jsonPlaceholderDio;

  final Dio _dio;

  Future<List<Comment>> fetchComments() async {
    final response = await _dio.get<List<Object?>>('/comments');
    return [
      for (final item in response.data!)
        Comment.fromJson(item! as Map<String, Object?>),
    ];
  }

  Future<Comment> fetchComment(int id) async {
    final response = await _dio.get<Map<String, Object?>>('/comments/$id');
    return Comment.fromJson(response.data!);
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

import 'jsonplaceholder_api.dart';

enum LoadStatus { loading, ready, failure }

/// Why a load failed, without the response data: the report has the call.
String _failureOf(Object error) => switch (error) {
      DioException(response: Response(:final statusCode?)) =>
        'HTTP $statusCode',
      DioException(:final type) => type.name,
      _ => error.runtimeType.toString(),
    };

class CommentsState {
  const CommentsState({
    this.status = LoadStatus.loading,
    this.comments = const [],
    this.failure,
  });

  final LoadStatus status;
  final List<Comment> comments;
  final String? failure;
}

/// Loads `GET /comments`.
class CommentsCubit extends Cubit<CommentsState> {
  CommentsCubit(this._api) : super(const CommentsState());

  final CommentsApi _api;

  Future<void> load() async {
    emit(const CommentsState());
    try {
      final comments = await _api.fetchComments();
      if (!isClosed) {
        emit(CommentsState(status: LoadStatus.ready, comments: comments));
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          CommentsState(status: LoadStatus.failure, failure: _failureOf(error)),
        );
      }
    }
  }
}

class CommentDetailState {
  const CommentDetailState({
    this.status = LoadStatus.loading,
    this.comment,
    this.failure,
  });

  final LoadStatus status;
  final Comment? comment;
  final String? failure;
}

/// Loads `GET /comments/{id}`.
class CommentDetailCubit extends Cubit<CommentDetailState> {
  CommentDetailCubit(this._api, this.id) : super(const CommentDetailState());

  final CommentsApi _api;
  final int id;

  Future<void> load() async {
    emit(const CommentDetailState());
    try {
      final comment = await _api.fetchComment(id);
      if (!isClosed) {
        emit(CommentDetailState(status: LoadStatus.ready, comment: comment));
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          CommentDetailState(
            status: LoadStatus.failure,
            failure: _failureOf(error),
          ),
        );
      }
    }
  }
}

/// The comments of https://jsonplaceholder.typicode.com/comments, over the
/// network. A tap on a comment opens `/comments/{id}`.
class CommentsPage extends StatelessWidget {
  const CommentsPage({super.key, this.api});

  /// The API, `CommentsApi()` over the network when `null`. Tests pass one
  /// that answers without the network.
  final CommentsApi? api;

  /// An id that jsonplaceholder does not have: its call fails with a 404.
  static const int missingCommentId = 999999;

  @override
  Widget build(BuildContext context) {
    final api = this.api ?? CommentsApi();
    return BlocProvider<CommentsCubit>(
      create: (_) => CommentsCubit(api)..load(),
      child: BugBlocScope<CommentsState>.lazy(
        id: 'comments_cubit',
        readBloc: (context) => context.read<CommentsCubit>(),
        // No comment content: the report has the response of the call.
        snapshotBuilder: (state) => {
          'status': state.status.name,
          'count': state.comments.length,
          'failure': state.failure,
        },
        child: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Comments'),
              actions: [
                IconButton(
                  tooltip: 'Comment không tồn tại (404)',
                  icon: const Icon(Icons.report_gmailerrorred),
                  onPressed: () => _openComment(
                    context,
                    api,
                    CommentsPage.missingCommentId,
                  ),
                ),
              ],
            ),
            body: BlocBuilder<CommentsCubit, CommentsState>(
              builder: (context, state) => switch (state.status) {
                LoadStatus.loading => const Center(
                    child: BugInspectable(
                      id: 'comments.loading',
                      sourceFile: 'example/lib/comments_page.dart',
                      child: CircularProgressIndicator(),
                    ),
                  ),
                LoadStatus.failure => _FailureView(
                    id: 'comments.failure',
                    message: 'Không tải được comments (${state.failure})',
                    onRetry: context.read<CommentsCubit>().load,
                  ),
                LoadStatus.ready => ListView.builder(
                    itemCount: state.comments.length,
                    itemBuilder: (context, index) {
                      final comment = state.comments[index];
                      return BugInspectable(
                        id: 'comments.item',
                        label: 'Comment ${comment.id}',
                        sourceFile: 'example/lib/comments_page.dart',
                        child: _CommentTile(
                          id: comment.id,
                          postId: comment.postId,
                          name: comment.name,
                          onTap: () => _openComment(context, api, comment.id),
                        ),
                      );
                    },
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }

  static void _openComment(BuildContext context, CommentsApi api, int id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/comments/detail'),
        builder: (_) => BugInspectablePage(
          id: 'comment_detail',
          label: 'Comment $id',
          sourceFile: 'example/lib/comments_page.dart',
          child: CommentDetailPage(id: id, api: api),
        ),
      ),
    );
  }
}

/// One comment of the list, with the parameters the report needs.
class _CommentTile extends StatelessWidget with BugInspectableWidget {
  const _CommentTile({
    required this.id,
    required this.postId,
    required this.name,
    required this.onTap,
  });

  final int id;
  final int postId;
  final String name;
  final VoidCallback onTap;

  @override
  Map<String, Object?> bugSnapshot() => {'id': id, 'postId': postId};

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text('$id')),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('Post $postId'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// https://jsonplaceholder.typicode.com/comments/{id}.
class CommentDetailPage extends StatelessWidget with BugInspectableWidget {
  const CommentDetailPage({super.key, required this.id, this.api});

  final int id;

  /// The API, `CommentsApi()` over the network when `null`.
  final CommentsApi? api;

  @override
  Map<String, Object?> bugSnapshot() => {'id': id};

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CommentDetailCubit>(
      create: (_) => CommentDetailCubit(api ?? CommentsApi(), id)..load(),
      child: BugBlocScope<CommentDetailState>.lazy(
        id: 'comment_detail_cubit',
        readBloc: (context) => context.read<CommentDetailCubit>(),
        snapshotBuilder: (state) => {
          'id': id,
          'status': state.status.name,
          'failure': state.failure,
        },
        child: Scaffold(
          appBar: AppBar(title: Text('Comment $id')),
          body: BlocBuilder<CommentDetailCubit, CommentDetailState>(
            builder: (context, state) {
              final comment = state.comment;
              return switch (state.status) {
                LoadStatus.loading =>
                  const Center(child: CircularProgressIndicator()),
                LoadStatus.failure => _FailureView(
                    id: 'comment_detail.failure',
                    message: 'Không tải được comment $id (${state.failure})',
                    onRetry: context.read<CommentDetailCubit>().load,
                  ),
                LoadStatus.ready => ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      BugInspectable(
                        id: 'comment_detail.name',
                        sourceFile: 'example/lib/comments_page.dart',
                        child: Text(
                          comment!.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${comment.email} · Post ${comment.postId}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      BugInspectable(
                        id: 'comment_detail.body',
                        sourceFile: 'example/lib/comments_page.dart',
                        child: Text(comment.body),
                      ),
                    ],
                  ),
              };
            },
          ),
        ),
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.id,
    required this.message,
    required this.onRetry,
  });

  final String id;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: BugInspectable(
          id: id,
          sourceFile: 'example/lib/comments_page.dart',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

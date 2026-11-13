import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

import 'catalog_page.dart';
import 'comments_page.dart';

class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);

  void reset() => emit(0);
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Expose the cubit to every BugInspectable below. The cubit is only read
    // when the tester selects a widget. Without an enabled BugInspector the
    // scope and the inspectables only return their child.
    return BugBlocScope<int>.lazy(
      id: 'counter_cubit',
      readBloc: (context) => context.read<CounterCubit>(),
      snapshotBuilder: (value) => {'value': value},
      child: Scaffold(
        appBar: AppBar(title: const Text('Counter')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BlocBuilder<CounterCubit, int>(
                builder: (context, value) => BugInspectable(
                  id: 'counter.increment',
                  label: 'Increment button',
                  sourceFile: 'example/lib/counter_page.dart',
                  sourceLine: 34,
                  child: FilledButton(
                    onPressed: context.read<CounterCubit>().increment,
                    child: Text('Tăng ($value)'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              BugInspectable(
                id: 'counter.reset',
                sourceFile: 'example/lib/counter_page.dart',
                child: TextButton(
                  onPressed: context.read<CounterCubit>().reset,
                  child: const Text('Đặt lại'),
                ),
              ),
              const SizedBox(height: 32),
              BugInspectable(
                id: 'counter.open_catalog',
                sourceFile: 'example/lib/counter_page.dart',
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: '/catalog'),
                      builder: (_) => const BugInspectablePage(
                        id: 'catalog',
                        label: 'Danh mục',
                        sourceFile: 'example/lib/catalog_page.dart',
                        child: CatalogPage(),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.list),
                  label: const Text('Mở danh mục'),
                ),
              ),
              const SizedBox(height: 12),
              BugInspectable(
                id: 'counter.open_comments',
                sourceFile: 'example/lib/counter_page.dart',
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: '/comments'),
                      builder: (_) => const BugInspectablePage(
                        id: 'comments',
                        label: 'Comments',
                        sourceFile: 'example/lib/comments_page.dart',
                        child: CommentsPage(),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('Comments (API thật)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

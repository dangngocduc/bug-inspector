import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_qa_inspector/flutter_qa_inspector.dart';

enum CatalogStatus { loading, ready }

enum CatalogFilter { all, favorites }

class CatalogState {
  const CatalogState({
    this.status = CatalogStatus.loading,
    this.items = const [],
    this.favorites = const {},
    this.filter = CatalogFilter.all,
  });

  final CatalogStatus status;
  final List<String> items;
  final Set<String> favorites;
  final CatalogFilter filter;

  List<String> get visibleItems => filter == CatalogFilter.all
      ? items
      : items.where(favorites.contains).toList();

  CatalogState copyWith({
    CatalogStatus? status,
    List<String>? items,
    Set<String>? favorites,
    CatalogFilter? filter,
  }) {
    return CatalogState(
      status: status ?? this.status,
      items: items ?? this.items,
      favorites: favorites ?? this.favorites,
      filter: filter ?? this.filter,
    );
  }
}

sealed class CatalogEvent {
  const CatalogEvent();
}

final class CatalogStarted extends CatalogEvent {
  const CatalogStarted();
}

final class CatalogFavoriteToggled extends CatalogEvent {
  const CatalogFavoriteToggled(this.item);

  final String item;
}

final class CatalogFilterChanged extends CatalogEvent {
  const CatalogFilterChanged(this.filter);

  final CatalogFilter filter;
}

class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  CatalogBloc() : super(const CatalogState()) {
    on<CatalogStarted>((event, emit) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      emit(
        state.copyWith(
          status: CatalogStatus.ready,
          items: [for (var i = 1; i <= 30; i++) 'Sản phẩm $i'],
        ),
      );
    });
    on<CatalogFavoriteToggled>((event, emit) {
      final favorites = {...state.favorites};
      if (!favorites.remove(event.item)) favorites.add(event.item);
      emit(state.copyWith(favorites: favorites));
    });
    on<CatalogFilterChanged>(
      (event, emit) => emit(state.copyWith(filter: event.filter)),
    );
  }
}

class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CatalogBloc>(
      create: (_) => CatalogBloc()..add(const CatalogStarted()),
      // Read with the context of the scope, which is below the provider, and
      // only when the tester selects a widget.
      child: BugBlocScope<CatalogState>.lazy(
        id: 'catalog_bloc',
        readBloc: (context) => context.read<CatalogBloc>(),
        // Only fields that help diagnose a bug, as JSON values.
        snapshotBuilder: (state) => {
          'status': state.status.name,
          'filter': state.filter.name,
          'itemCount': state.items.length,
          'visibleCount': state.visibleItems.length,
          'favorites': state.favorites.toList()..sort(),
        },
        child: const _CatalogView(),
      ),
    );
  }
}

class _CatalogView extends StatefulWidget {
  const _CatalogView();

  @override
  State<_CatalogView> createState() => _CatalogViewState();
}

/// Keeps the search query, which only this screen needs, so it lives in the
/// state instead of the bloc.
class _CatalogViewState extends State<_CatalogView> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<String> _matching(List<String> items) {
    final query = _query.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return [
      for (final item in items)
        if (item.toLowerCase().contains(query)) item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh mục'),
      ),
      body: BlocBuilder<CatalogBloc, CatalogState>(
        builder: (context, state) {
          if (state.status == CatalogStatus.loading) {
            return const Center(
              child: BugInspectable(
                id: 'catalog.loading',
                sourceFile: 'example/lib/catalog_page.dart',
                child: CircularProgressIndicator(),
              ),
            );
          }
          final items = _matching(state.visibleItems);
          return Column(
            children: [
              BugInspectable(
                id: 'catalog.filter',
                sourceFile: 'example/lib/catalog_page.dart',
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SegmentedButton<CatalogFilter>(
                    segments: const [
                      ButtonSegment(
                        value: CatalogFilter.all,
                        label: Text('Tất cả'),
                      ),
                      ButtonSegment(
                        value: CatalogFilter.favorites,
                        label: Text('Yêu thích'),
                      ),
                    ],
                    selected: {state.filter},
                    onSelectionChanged: (selection) => context
                        .read<CatalogBloc>()
                        .add(CatalogFilterChanged(selection.single)),
                  ),
                ),
              ),
              BugInspectable(
                id: 'catalog.search',
                sourceFile: 'example/lib/catalog_page.dart',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Tìm sản phẩm',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    // The id names the widget in code, the label tells which
                    // item. The selection describes the child: its type and
                    // the parameters from its bugSnapshot.
                    return BugInspectable(
                      id: 'catalog.item',
                      label: item,
                      sourceFile: 'example/lib/catalog_page.dart',
                      child: _CatalogItemTile(
                        item: item,
                        favorite: state.favorites.contains(item),
                        onToggleFavorite: () => context
                            .read<CatalogBloc>()
                            .add(CatalogFavoriteToggled(item)),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One item of the list. BugInspectableWidget adds the parameters the list
/// passes in to the bug report of the BugInspectable around it.
class _CatalogItemTile extends StatelessWidget with BugInspectableWidget {
  const _CatalogItemTile({
    required this.item,
    required this.favorite,
    required this.onToggleFavorite,
  });

  final String item;
  final bool favorite;
  final VoidCallback onToggleFavorite;

  // Only called when the tester selects the item.
  @override
  Map<String, Object?> bugSnapshot() => {'item': item, 'favorite': favorite};

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item),
      trailing: IconButton(
        tooltip: 'Yêu thích',
        icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
        onPressed: onToggleFavorite,
      ),
    );
  }
}

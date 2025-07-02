import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solvix/src/core/api/search_service.dart';
import 'package:rxdart/rxdart.dart';
import 'search_event.dart';
import 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchService _searchService;

  SearchBloc(this._searchService) : super(const SearchState()) {
    on<SearchQueryChanged>(
      _onSearchQueryChanged,
      transformer: (events, mapper) => events
          .debounceTime(const Duration(milliseconds: 400))
          .switchMap(mapper),
    );
    on<ClearSearch>(_onClearSearch);
  }

  Future<void> _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    if (event.query.isEmpty) {
      emit(
        state.copyWith(status: SearchStatus.initial, results: [], query: ''),
      );
      return;
    }

    emit(state.copyWith(status: SearchStatus.loading, query: event.query));

    try {
      final results = await _searchService.search(event.query);
      emit(state.copyWith(status: SearchStatus.success, results: results));
    } catch (e) {
      emit(
        state.copyWith(
          status: SearchStatus.failure,
          errorMessage: e.toString().replaceFirst("Exception: ", ""),
        ),
      );
    }
  }

  void _onClearSearch(ClearSearch event, Emitter<SearchState> emit) {
    emit(const SearchState());
  }
}

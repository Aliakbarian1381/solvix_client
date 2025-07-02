import 'package:equatable/equatable.dart';
import 'package:solvix/src/core/models/search_result_model.dart';

enum SearchStatus { initial, loading, success, failure }

class SearchState extends Equatable {
  final SearchStatus status;
  final List<SearchResultModel> results;
  final String query;
  final String errorMessage;

  const SearchState({
    this.status = SearchStatus.initial,
    this.results = const [],
    this.query = '',
    this.errorMessage = '',
  });

  SearchState copyWith({
    SearchStatus? status,
    List<SearchResultModel>? results,
    String? query,
    String? errorMessage,
  }) {
    return SearchState(
      status: status ?? this.status,
      results: results ?? this.results,
      query: query ?? this.query,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object> get props => [status, results, query, errorMessage];
}

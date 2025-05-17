import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_infinite_list/posts/model/post.dart';
import 'package:bloc/bloc.dart';

import 'package:flutter_infinite_list/posts/model/post.dart';
import 'package:http/http.dart' as http;
import 'package:stream_transform/stream_transform.dart';
import 'dart:convert';


part 'post_event.dart';
part 'post_state.dart';


const throttleDuration = Duration(milliseconds: 100);
const postOffset = 20;

EventTransformer<E> throttleDroppable<E>(Duration duration) {
  return (events, mapper) {
    return droppable<E>().call(events.throttle(duration), mapper);
  };
}


class PostBloc extends Bloc<PostEvent, PostState> {
  PostBloc({ required this.httpClient }) : super(const PostState()) { 
    on<PostFetched>(
      _onFetched,
      transformer: throttleDroppable(throttleDuration),
      );
  }

  final http.Client httpClient;

  Future<void> _onFetched(PostFetched event, Emitter<PostState> emit) async {
    if (state.hasReachedMax) return;
    
    try {
      final posts = await _fetchPosts(startIndex: state.posts.length);
      
      if (posts.isEmpty) { 
        return emit(state.copyWith(hasReachedMax: true));
      }

      emit(state.copyWith(posts: [...state.posts, ...posts], status: PostStatus.success));
    }
    catch (_) {
      emit(state.copyWith(status: PostStatus.failure));
    }
  }

  Future<List<Post>> _fetchPosts({required int startIndex}) async {
  final response = await this.httpClient.get(Uri.https('jsonplaceholder.typicode.com', '/posts',
    <String, String> {
      '_start': '$startIndex',
      '_limit': '$postOffset',
    }));

  if (response.statusCode == 200) {
    final body = json.decode(response.body) as List;
    return body.map(( dynamic json) {
      return Post(
        id: json['id'] as int,
        title: json['title'] as String,
        body: json['body'] as String,
      );
    }).toList();
  }
  else {
    throw Exception('error fetching posts');
  }
}
}


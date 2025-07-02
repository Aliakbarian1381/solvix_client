import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solvix/src/core/api/chat/chat_service.dart';
import 'package:solvix/src/core/models/chat_model.dart';

part 'chat_list_event.dart';

part 'chat_list_state.dart';

class ChatListBloc extends Bloc<ChatListEvent, ChatListState> {
  final ChatService _chatService;
  final Box<ChatModel> _chatBox = Hive.box<ChatModel>('chats');

  ChatListBloc(this._chatService) : super(ChatListInitial()) {
    on<FetchChatList>(_onFetchChatList);
    on<ResetChatListState>(_onResetChatListState);
    on<UpdateChatReceived>(_onUpdateChatReceived);
  }

  Future<void> _onFetchChatList(
    FetchChatList event,
    Emitter<ChatListState> emit,
  ) async {
    // 1. خواندن فوری اطلاعات از کش
    final cachedChats = _chatBox.values.toList();
    cachedChats.sort(
      (a, b) => (b.lastMessageTime ?? b.createdAt).compareTo(
        a.lastMessageTime ?? a.createdAt,
      ),
    );

    if (cachedChats.isNotEmpty) {
      // اگر کش وجود داشت، همان را فورا نمایش بده
      emit(ChatListLoaded(cachedChats));
    } else {
      // اگر کش خالی بود، حالت لودینگ را نشان بده
      emit(ChatListLoading());
    }

    // 2. درخواست اطلاعات جدید از سرور در پس‌زمینه
    try {
      final chatsFromServer = await _chatService.getUserChats();

      // 3. به‌روزرسانی کامل کش
      await _chatBox.clear();
      await _chatBox.putAll({for (var chat in chatsFromServer) chat.id: chat});

      // 4. نمایش لیست جدید و آپدیت شده در UI
      final freshChats = _chatBox.values.toList();
      freshChats.sort(
        (a, b) => (b.lastMessageTime ?? b.createdAt).compareTo(
          a.lastMessageTime ?? a.createdAt,
        ),
      );

      emit(ChatListLoaded(freshChats));
    } catch (e) {
      // 5. مدیریت خطا: فقط اگر کش خالی بود خطا را نشان بده
      if (cachedChats.isEmpty) {
        emit(ChatListError(e.toString().replaceFirst("Exception: ", "")));
      }
      // در غیر این صورت، کاربر همان دیتای کش شده را میبیند و متوجه خطا نمی‌شود
    }
  }

  // این هندلر جدید، یک رفرش کامل را انجام می‌دهد
  Future<void> _onResetChatListState(
    ResetChatListState event,
    Emitter<ChatListState> emit,
  ) async {
    // 1. کش را کاملا پاک کن
    await _chatBox.clear();
    // 2. یک واکشی جدید را از ابتدا آغاز کن
    add(FetchChatList());
  }

  void _onUpdateChatReceived(
    UpdateChatReceived event,
    Emitter<ChatListState> emit,
  ) {
    // 1. چت جدید یا آپدیت شده را در کش ذخیره/جایگزین کن
    _chatBox.put(event.updatedChat.id, event.updatedChat);

    // 2. لیست فعلی را از کش بخوان
    final currentChats = _chatBox.values.toList();

    // 3. لیست را مرتب کن تا چت جدید در بالای لیست قرار گیرد
    currentChats.sort(
      (a, b) => (b.lastMessageTime ?? b.createdAt).compareTo(
        a.lastMessageTime ?? a.createdAt,
      ),
    );

    // 4. وضعیت جدید را با لیست آپدیت شده به UI بفرست
    emit(ChatListLoaded(currentChats));
  }
}

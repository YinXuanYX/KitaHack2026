import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Send a message
  Future<void> sendMessage(String receiverId, String message, {required String receiverName, required String senderName}) async {
    final String currentUserId = _auth.currentUser!.uid;
    final Timestamp timestamp = Timestamp.now();

    // Determine the chat room ID. To keep it simple and unique, we sort the IDs.
    // However, since it's consumer to vendor, we can just use consumerId_vendorId.
    // To make it robust, sorting is standard.
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomId = ids.join('_');

    // Add message to subcollection
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add({
      'senderId': currentUserId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
    });

    // Update the main chat room document with metadata for list view
    await _firestore.collection('chats').doc(chatRoomId).set({
      'users': [currentUserId, receiverId],
      'chatRoomId': chatRoomId,
      'lastMessage': message,
      'lastMessageTime': timestamp,
      // We store names so the inbox can display them without fetching user docs
      // A more robust app would fetch the user docs, but this is quicker for MVP
      currentUserId: senderName,
      receiverId: receiverName,
    }, SetOptions(merge: true));
  }

  // Get messages stream
  Stream<QuerySnapshot> getMessages(String userId, String otherUserId) {
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Get all chat rooms for current user
  Stream<QuerySnapshot> getUserChats() {
    final String currentUserId = _auth.currentUser!.uid;
    
    return _firestore
        .collection('chats')
        .where('users', arrayContains: currentUserId)
        .snapshots();
  }
}

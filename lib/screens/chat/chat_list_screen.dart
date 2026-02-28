import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/chat_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return const Center(child: Text('Not logged in'));
    }

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getUserChats(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error.toString();
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading messages:\n\n$error', textAlign: TextAlign.center),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No messages yet',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final docs = snapshot.data!.docs.toList();
          
          // Sort in memory locally to bypass Firebase Composite Index requirement
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['lastMessageTime'] as Timestamp?;
            final bTime = bData['lastMessageTime'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime); // Descending
          });

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final document = docs[index];
              final data = document.data() as Map<String, dynamic>;

              final users = data['users'] as List<dynamic>;
              final opponentId = users.firstWhere((id) => id != _auth.currentUser!.uid, orElse: () => '');
              
              if (opponentId.isEmpty) return const SizedBox.shrink();

              // For a simple MVP name grabbing approach matching the hackathon code structure
              String title = 'User';
              if (data[opponentId] != null && data[opponentId] is String) {
                 title = data[opponentId]; // The opponent's name saved on send
              } else if (data['receiverId'] != null) {
                  // Fallback due to standard naming logic
                  title = 'Store Context User';
              }

              // Let's resolve the exact opponent's name dynamically if missing
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(opponentId).get(),
                builder: (context, userSnap) {
                  if (userSnap.hasData && userSnap.data!.exists) {
                    final userData = userSnap.data!.data() as Map<String, dynamic>;
                    title = userData['storeName'] ?? userData['name'] ?? 'User';
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Icon(Icons.person, color: Theme.of(context).colorScheme.onPrimary),
                      ),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        data['lastMessage'] ?? 'No message', 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              receiverId: opponentId,
                              receiverName: title,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }
              );
            },
          );
        },
      ),
    );
  }
}

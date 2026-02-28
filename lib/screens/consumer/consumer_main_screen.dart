import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import 'consumer_home_screen.dart'; // Map Page
import 'orders/consumer_orders_screen.dart';
import 'profile/consumer_profile_screen.dart';
import '../chatbot_screen.dart';
import '../chat/chat_list_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ConsumerMainScreen extends StatefulWidget {
  final int initialIndex;
  const ConsumerMainScreen({super.key, this.initialIndex = 0});

  @override
  State<ConsumerMainScreen> createState() => _ConsumerMainScreenState();
}

class _ConsumerMainScreenState extends State<ConsumerMainScreen> {
  late int _selectedIndex;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<QuerySnapshot>? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _initNotifications();
    _listenToOrders();
  }

  Future<void> _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotifications.initialize(initSettings);

    // Request permissions (Android 13+)
    _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  void _listenToOrders() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _ordersSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('consumerId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data() as Map<String, dynamic>;
          if (data['status'] == 'confirmed') {
             final itemTitle = data['itemTitle'] ?? 'Your item';
             _showOrderConfirmedAlert(itemTitle);
          }
        }
      }
    });
  }

  Future<void> _showOrderConfirmedAlert(String itemTitle) async {
    // 1. External Push Notification
    const androidDetails = AndroidNotificationDetails(
      'order_updates', 'Order Updates',
      importance: Importance.max, priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    
    await _localNotifications.show(
      0,
      'Order Accepted! 🎉',
      'The vendor has confirmed your order for $itemTitle. Head over to pick it up!',
      details,
    );

    // 2. Internal Pop-Up Dialog
    if (mounted) {
       showDialog(
         context: context,
         builder: (context) => AlertDialog(
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           title: const Row(
             children: [
               Icon(Icons.check_circle, color: Colors.green),
               SizedBox(width: 8),
               Text('Order Accepted!'),
             ]
           ),
           content: Text('The vendor has confirmed your payment for $itemTitle.\n\nPlease head to the "My Orders" tab to present your QR code for pickup.'),
           actions: [
             TextButton(
               onPressed: () {
                 Navigator.pop(context);
                 _onItemTapped(1); // Switch to Orders tab safely
               },
               child: const Text('View Order'),
             ),
             TextButton(
               onPressed: () => Navigator.pop(context),
               child: const Text('Dismiss'),
             )
           ],
         ),
       );
    }
  }

  static const List<Widget> _widgetOptions = <Widget>[
    ConsumerHomeScreen(),
    ConsumerOrdersScreen(),
    ChatListScreen(),
    ConsumerProfileScreen(),
  ];

  static const List<String> _titles = [
    'Discover Deals',
    'My Orders',
    'Messages',
    'Profile',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatbotScreen()),
          );
        },
        backgroundColor: Colors.white,
        child: Icon(
          Icons.chat_bubble_outline,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}

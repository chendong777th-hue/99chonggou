import 'package:flutter/material.dart';
import 'community_api_test.dart';
import 'conversation_api_test.dart';
import 'friendship_api_test.dart';
import 'group_api_test.dart';
import 'main_api_test.dart';
import 'message_api_test.dart';

class APITestPage extends StatefulWidget {
  const APITestPage({Key? key}) : super(key: key);

  @override
  State<APITestPage> createState() => _APITestPageState();
}

class _APITestPageState extends State<APITestPage> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const MainAPITest(),
    const ConversationAPITest(),
    const MessageAPITest(),
    const GroupAPITest(),
    const FriendshipAPITest(),
    const CommunityAPITest(),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '基础',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: '会话',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: '消息',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: '群组',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: '关系链',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum),
            label: '社群',
          ),
        ],
      ),
    );
  }
} 
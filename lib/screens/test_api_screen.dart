import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TestApiScreen extends StatefulWidget {
  const TestApiScreen({super.key});

  @override
  State<TestApiScreen> createState() => _TestApiScreenState();
}

class _TestApiScreenState extends State<TestApiScreen> {
  final ApiService _apiService = ApiService();
  String _status = 'Ready to test';
  bool _isLoading = false;

  Future<void> _testRegister() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing register...';
    });

    try {
      final response = await _apiService.register(
        name: 'Test User',
        email: 'testuser@example.com',
        password: 'password123',
        phone: '081234567890',
      );

      if (response['success']) {
        setState(() {
          _status = '✅ Register successful!\nUser: ${response['data']['user']['name']}\nEmail: ${response['data']['user']['email']}';
        });
      } else {
        setState(() {
          _status = '❌ Register failed: ${response['message']}';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testLogin() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing login...';
    });

    try {
      final response = await _apiService.login(
        email: 'testuser@example.com',
        password: 'password123',
      );

      if (response['success']) {
        setState(() {
          _status = '✅ Login successful!\nToken: ${response['data']['token'].substring(0, 20)}...';
        });
      } else {
        setState(() {
          _status = '❌ Login failed: ${response['message']}';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('API Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _status,
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testRegister,
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Text('Test Register'),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testLogin,
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Text('Test Login'),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Make sure Laravel server is running on localhost:8000'),
                    Text('2. Make sure database MySQL is connected'),
                    Text('3. Press "Test Register" to create a new user'),
                    Text('4. Press "Test Login" to login with the created user'),
                    Text('5. Check Laravel database to verify data is saved'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}






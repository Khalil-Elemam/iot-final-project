import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/firebase_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  String _errorMessage = '';
  bool _isLoading = false;

  bool _validateInputs() {
    if (_emailController.text.isEmpty) {
      _errorMessage = 'Please enter your email address.';
      return false;
    }
    if (_passwordController.text.isEmpty) {
      _errorMessage = 'Please enter your password.';
      return false;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _errorMessage = 'Passwords do not match.';
      return false;
    }
    return true;
  }

  Future<void> _signup() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    if (!_validateInputs()) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final firebaseService =
          Provider.of<FirebaseService>(context, listen: false);
      await firebaseService.createUserWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
      );
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
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
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sign Up',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _signup,
                    child: const Text('Sign Up'),
                  ),
            const SizedBox(height: 10),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              child: const Text('Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}

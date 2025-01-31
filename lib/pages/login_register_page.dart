/*
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:paymatefyp/auth.dart';
import '../auth.dart';




class LoginPage extends StatefulWidget{
  const LoginPage({Key?key}) : super(key:key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>{
  String? errorMessage="";
  bool isLogin=true;


  final TextEditingController _controllerEmail = TextEditingController();
  final TextEditingController _controllerPassword = TextEditingController();


  Future<void> signinWithEmailAndPassword() async{
    try{
      await Auth().signinwithEmailAndPassword
        (email: _controllerEmail.text, password: _controllerPassword.text,);
    } on FirebaseAuthException catch(e) {
      setState(() {
        errorMessage=e.message;
      });
    }
  }



  Future<void> createUserWithEmailAndPassword() async{
    try{
      await Auth().createUserwithEmailAndPassword
        (email: _controllerEmail.text, password: _controllerPassword.text,);
    } on FirebaseAuthException catch(e) {
      setState(() {
        errorMessage=e.message;
      });
    }
  }
  Widget _title(){
    return const Text('Firebase Auth');
  }
  Widget _entryField(String title, TextEditingController controller){
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: title,
      ),
    );
  }

  Widget _errorMessage(){
    return Text(_errorMessage == ''?'' :'Hum ? $errorMessage');
  }

  Widget _submitButton(){
    return ElevatedButton(
        onPressed:
        isLogin ? signinWithEmailAndPassword : createUserWithEmailAndPassword,
        child: Text(isLogin?'Login':'Register'),
    );
  }

  Widget _loginorRegisterButton(){
    return TextButton(
      onPressed :(){
        setState(() {
          isLogin=!isLogin;
        });
      },
      child: Text(isLogin?'Register instead':'Login instead'),
    );
  }








  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: _title(),
        ),
        body:Container(
          height: double.infinity,
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget >[
              _entryField('email', _controllerEmail),
              _entryField('password', _controllerPassword),
              _errorMessage(),
              _submitButton(),
              _loginorRegisterButton(),
            ],
          ),
        )
    );
  }
}*/

/*
//===new one===
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? errorMessage = "";
  bool isLogin = true;
  bool _obscurePassword = true;  // For password visibility toggle

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _controllerEmail = TextEditingController();
  final TextEditingController _controllerPassword = TextEditingController();
  final TextEditingController _controllerConfirmPassword = TextEditingController();
  final TextEditingController _controllerDOB = TextEditingController();

  Future<void> signinWithEmailAndPassword() async {
    try {
      await Auth().signinwithEmailAndPassword(
        email: _controllerEmail.text,
        password: _controllerPassword.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    }
  }

  Future<void> createUserWithEmailAndPassword() async {
    // First validate confirm password
    if (_controllerPassword.text != _controllerConfirmPassword.text) {
      setState(() {
        errorMessage = "Passwords do not match";
      });
      return;
    }

    try {
      await Auth().createUserwithEmailAndPassword(
        email: _controllerEmail.text,
        password: _controllerPassword.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _controllerDOB.text = "${picked.year}-${picked.month
            .toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Widget _title() {
    return Text(
      isLogin ? 'Welcome Back!' : 'Create Account',
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _subtitle() {
    return Text(
      isLogin ? 'Please sign in to continue' : 'Please register below',
      style: const TextStyle(fontSize: 16, color: Colors.grey),
    );
  }

  Widget _entryField(String title, TextEditingController controller, {bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      decoration: InputDecoration(
        labelText: title,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[100],
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        )
            : null,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $title';
        }
        if (isPassword && value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _errorMessage() {
    return errorMessage?.isNotEmpty == true
        ? Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        errorMessage ?? '',
        style: const TextStyle(color: Colors.red),
      ),
    )
        : const SizedBox.shrink();
  }

  Widget _submitButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            isLogin ? signinWithEmailAndPassword() : createUserWithEmailAndPassword();
          }
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 2,
        ),
        child: Text(
          isLogin ? 'Sign In' : 'Register',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _loginOrRegisterButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isLogin ? 'Have an account? ' : 'Need an account? ',
            style: const TextStyle(fontSize: 14),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                isLogin = !isLogin;
                errorMessage = "";
              });
            },
            child: Text(
              isLogin ? 'Sign In' : 'Register',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controllerEmail.dispose();
    _controllerPassword.dispose();
    _controllerConfirmPassword.dispose();
    _controllerDOB.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 40),
                  // Logo space
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/paymate.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.account_circle, size: 80, color: Colors.black54);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _title(),
                  const SizedBox(height: 8),
                  _subtitle(),
                  const SizedBox(height: 32),
                  _entryField('Email', _controllerEmail),
                  const SizedBox(height: 16),
                  _entryField('Password', _controllerPassword, isPassword: true),
                  const SizedBox(height: 16),
                  if (!isLogin) ...[
                    _entryField('Confirm Password', _controllerConfirmPassword, isPassword: true),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _controllerDOB,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Date of Birth',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _selectDate(context),
                        ),
                      ),
                      validator: (value) {
                        if (!isLogin && (value == null || value.isEmpty)) {
                          return 'Please select your date of birth';
                        }
                        return null;
                      },
                      onTap: () => _selectDate(context),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  _errorMessage(),
                  const SizedBox(height: 24),
                  _submitButton(),
                  const SizedBox(height: 16),
                  _loginOrRegisterButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}*/
//===============/
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? errorMessage = "";
  bool isLogin = true;
  bool _obscurePassword = true;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _controllerEmail = TextEditingController();
  final TextEditingController _controllerPassword = TextEditingController();
  final TextEditingController _controllerConfirmPassword = TextEditingController();
  final TextEditingController _controllerDOB = TextEditingController();

  // Email validation regular expression
  final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  Future<void> signinWithEmailAndPassword() async {
    if (!emailRegex.hasMatch(_controllerEmail.text)) {
      setState(() {
        errorMessage = "Please enter a valid email address";
      });
      return;
    }

    try {
      await Auth().signinwithEmailAndPassword(
        email: _controllerEmail.text.trim(),
        password: _controllerPassword.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    }
  }

  Future<void> createUserWithEmailAndPassword() async {
    if (!emailRegex.hasMatch(_controllerEmail.text)) {
      setState(() {
        errorMessage = "Please enter a valid email address";
      });
      return;
    }

    if (_controllerPassword.text != _controllerConfirmPassword.text) {
      setState(() {
        errorMessage = "Passwords do not match";
      });
      return;
    }

    try {
      await Auth().createUserwithEmailAndPassword(
        email: _controllerEmail.text.trim(),
        password: _controllerPassword.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _controllerDOB.text =
        "${picked.year}-${picked.month.
        toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Widget _title() {
    return Text(
      isLogin ? 'Welcome Back!' : 'Create Account',
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _subtitle() {
    return Text(
      isLogin ? 'Please sign in to continue' : 'Please register below',
      style: const TextStyle(fontSize: 16, color: Colors.deepOrangeAccent),
    );
  }

  Widget _entryField(String title, TextEditingController controller, {bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      keyboardType: title.toLowerCase() == 'email' ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        labelText: title,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[100],
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        )
            : null,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $title';
        }
        if (title.toLowerCase() == 'email' && !emailRegex.hasMatch(value)) {
          return 'Please enter a valid email address';
        }
        if (isPassword && value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
      onChanged: (value) {
        if (title.toLowerCase() == 'email') {
          controller.text = value.trim();
        }
      },
    );
  }

  Widget _errorMessage() {
    return errorMessage?.isNotEmpty == true
        ? Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        errorMessage ?? '',
        style: const TextStyle(color: Colors.red),
      ),
    )
        : const SizedBox.shrink();
  }

  Widget _submitButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            isLogin ? signinWithEmailAndPassword() : createUserWithEmailAndPassword();
          }
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          backgroundColor: Colors.deepOrange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 2,
        ),
        child: Text(
          isLogin ? 'Sign In' : 'Register',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _loginOrRegisterButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isLogin ? 'Don\'t have an account? ' : 'Already have an account? ',
            style: const TextStyle(fontSize: 14),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                isLogin = !isLogin;
                errorMessage = "";
                // Clear form fields when switching between login and register
                _controllerEmail.clear();
                _controllerPassword.clear();
                _controllerConfirmPassword.clear();
                _controllerDOB.clear();
              });
            },
            child: Text(
              isLogin ? 'Register' : 'Sign In',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.deepOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controllerEmail.dispose();
    _controllerPassword.dispose();
    _controllerConfirmPassword.dispose();
    _controllerDOB.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 40),
                  // Logo space
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.deepOrange, width: 2),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'images/paymate.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.account_circle, size: 80, color: Colors.deepOrange);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _title(),
                  const SizedBox(height: 8),
                  _subtitle(),
                  const SizedBox(height: 32),
                  _entryField('Email', _controllerEmail),
                  const SizedBox(height: 16),
                  _entryField('Password', _controllerPassword, isPassword: true),
                  const SizedBox(height: 16),
                  if (!isLogin) ...[
                    _entryField('Confirm Password', _controllerConfirmPassword, isPassword: true),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _controllerDOB,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Date of Birth',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _selectDate(context),
                        ),
                      ),
                      validator: (value) {
                        if (!isLogin && (value == null || value.isEmpty)) {
                          return 'Please select your date of birth';
                        }
                        return null;
                      },
                      onTap: () => _selectDate(context),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  _errorMessage(),
                  const SizedBox(height: 24),
                  _submitButton(),
                  const SizedBox(height: 16),
                  _loginOrRegisterButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/show_dialog.dart';
import 'package:retroshare/model/http_exception.dart';
import 'package:retroshare/provider/auth.dart';
import 'package:retroshare/provider/identity.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  SignUpScreenState createState() => SignUpScreenState();
}

enum PasswordError { correct, notTheSame, tooShort }

class SignUpScreenState extends State<SignUpScreen> {
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController repeatPasswordController = TextEditingController();
  TextEditingController nodeNameController = TextEditingController();

  bool advancedOption = false;
  bool isUsernameCorrect = true;
  PasswordError passwordError = PasswordError.correct;

  @override
  void initState() {
    super.initState();
    advancedOption = false;
    isUsernameCorrect = true;
    passwordError = PasswordError.correct;
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    repeatPasswordController.dispose();
    nodeNameController.dispose();
    super.dispose();
  }

  Future<void> createAccount() async {
    var success = true;
    if (usernameController.text.length < 3) {
      setState(() {
        isUsernameCorrect = false;
      });
      success = false;
    }
    if (passwordController.text != repeatPasswordController.text) {
      setState(() {
        passwordError = PasswordError.notTheSame;
      });
      success = false;
    }
    if (passwordController.text.length < 3) {
      setState(() {
        passwordError = PasswordError.tooShort;
      });
      success = false;
    }

    if (!success) return;

    unawaited(
      Navigator.pushNamed(
        context,
        '/',
        arguments: {
          'statusText': 'Creating account...\nThis could take minutes',
          'isLoading': true,
          'spinner': true,
        },
      ),
    );
    try {
      final accountSignup =
          Provider.of<AccountCredentials>(context, listen: false);
      await accountSignup
          .signup(
        usernameController.text,
        passwordController.text,
        nodeNameController.text,
      )
          .then((value) {
        final ids = Provider.of<Identities>(context, listen: false);
        ids.fetchOwnidenities().then((value) {
          ids.ownIdentity.isEmpty
              ? Navigator.pushReplacementNamed(
                  context,
                  '/create_identity',
                  arguments: true,
                )
              : Navigator.pushReplacementNamed(context, '/home');
        });
      });
    } on HttpException {
      const errorMessage = 'Authentication failed';
      await errorShowDialog(errorMessage, 'Something went wrong', context);
    } catch (e) {
      debugPrint('Error creating account: $e');
      await errorShowDialog(
        'Retroshare Service Down',
        'Try to restart the app Again!',
        context,
      );
    }
  }

  Widget _buildLogo() {
    return Hero(
      tag: 'logo',
      child: Image.asset(
        'assets/rs-logo.png',
        height: 250,
        width: 250,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        height: 40,
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            border: InputBorder.none,
            icon: Icon(
              icon,
              color: Theme.of(context).hintColor,
              size: 22,
            ),
            hintText: hintText,
          ),
          style: Theme.of(context).textTheme.bodyLarge,
          obscureText: obscureText,
        ),
      ),
    );
  }

  Widget _buildUsernameField() {
    return _buildTextField(
      controller: usernameController,
      hintText: 'Username',
      icon: Icons.person_outline,
    );
  }

  Widget _buildPasswordField() {
    return _buildTextField(
      controller: passwordController,
      hintText: 'Password',
      icon: Icons.lock_outline,
      obscureText: true,
    );
  }

  Widget _buildRepeatPasswordField() {
    return _buildTextField(
      controller: repeatPasswordController,
      hintText: 'Repeat password',
      icon: Icons.lock_outline,
      obscureText: true,
    );
  }

  Widget _buildNodeNameField() {
    return _buildTextField(
      controller: nodeNameController,
      hintText: 'Node name',
      icon: Icons.smartphone,
    );
  }

  Widget _buildErrorText(String message) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(left: 52, top: 2, bottom: 8),
        child: Text(
          message,
          style: const TextStyle(color: Colors.red, fontSize: 12),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  Widget _buildUsernameError() {
    if (!isUsernameCorrect) {
      return _buildErrorText('Username is too short');
    }
    return const SizedBox(height: 10);
  }

  Widget _buildPasswordError() {
    if (passwordError == PasswordError.tooShort) {
      return _buildErrorText('Password is too short');
    }
    return const SizedBox(height: 10);
  }

  Widget _buildRepeatPasswordError() {
    if (passwordError == PasswordError.notTheSame) {
      return _buildErrorText('Passwords do not match');
    }
    return const SizedBox(height: 10);
  }

  Widget _buildAdvancedOptionsToggle() {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () {
          setState(() {
            advancedOption = !advancedOption;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          height: 45,
          child: Row(
            children: <Widget>[
              Checkbox(
                value: advancedOption,
                onChanged: (bool? value) {
                  setState(() {
                    advancedOption = value ?? false;
                  });
                },
              ),
              const SizedBox(width: 3),
              Text(
                'Advanced option',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedOptionsFields() {
    return Visibility(
      visible: advancedOption,
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildNodeNameField(),
          const SizedBox(height: 10),
          _buildImportButton(context),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              height: 45,
              child: Row(
                children: <Widget>[
                  Checkbox(
                    value: false,
                    onChanged: (bool? value) {},
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Tor/I2p Hidden node',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportButton(BuildContext context) {
    return TextButton(
      onPressed: () => _showImportDialog(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.file_download,
              color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            'Import existing account',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    final screenContext = context;
    final certController = TextEditingController();
    final passController = TextEditingController();
    var isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Import Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Import an exported RetroShare profile (.asc) and create a new mobile node using its existing PGP key.',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['asc'],
                    );
                    if (result != null) {
                      final file = File(result.files.single.path!);
                      final content = await file.readAsString();
                      certController.text = content;
                    }
                  },
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Choose Profile File (.asc)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: certController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Paste exported RetroShare profile here...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Profile password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (certController.text.isEmpty ||
                          passController.text.isEmpty) {
                        showToast('Please fill all fields');
                        return;
                      }
                      setState(() => isLoading = true);
                      try {
                        final authProvider = Provider.of<AccountCredentials>(
                            context,
                            listen: false);
                        final rawContent = certController.text.trim();

                        await authProvider.importIdentityAndCreateLocation(
                          rawContent,
                          passController.text,
                          nodeName: nodeNameController.text,
                        );

                        if (!context.mounted) return;
                        Navigator.pop(context);
                        if (!screenContext.mounted) return;

                        final identities = Provider.of<Identities>(
                          screenContext,
                          listen: false,
                        )..authToken = authProvider.authtoken;
                        await identities.fetchOwnidenities();
                        if (!screenContext.mounted) return;

                        showToast('Profile imported successfully');
                        if (identities.ownIdentity.isEmpty) {
                          await Navigator.of(screenContext)
                              .pushReplacementNamed(
                            '/create_identity',
                            arguments: true,
                          );
                        } else {
                          await Navigator.of(screenContext)
                              .pushReplacementNamed('/home');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showToast('Import failed: $e');
                        }
                      } finally {
                        if (context.mounted) {
                          setState(() => isLoading = false);
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateAccountButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      onPressed: createAccount,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[
              Color(0xFF00FFFF),
              Color(0xFF29ABE2),
            ],
            begin: Alignment(-1, -4),
            end: Alignment(1, 4),
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          alignment: Alignment.center,
          child: const Text(
            'Create account',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _buildLogo(),
                _buildUsernameField(),
                _buildUsernameError(),
                _buildPasswordField(),
                _buildPasswordError(),
                _buildRepeatPasswordField(),
                _buildRepeatPasswordError(),
                _buildAdvancedOptionsToggle(),
                _buildAdvancedOptionsFields(),
                const SizedBox(height: 20),
                _buildCreateAccountButton(),
                const SizedBox(height: 70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

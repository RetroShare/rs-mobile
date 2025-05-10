import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/show_dialog.dart';
import 'package:retroshare/provider/auth.dart';
import 'package:retroshare/provider/identity.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  SignInScreenState createState() => SignInScreenState();
}

class SignInScreenState extends State<SignInScreen> {
  TextEditingController passwordController = TextEditingController();

  late List<DropdownMenuItem<Account>> accountsDropdown;
  late Account? currentAccount;
  late bool hideLocations;
  late bool wrongPassword;

  @override
  void initState() {
    super.initState();
    hideLocations = true;
    wrongPassword = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    currentAccount = Provider.of<AccountCredentials>(context, listen: false)
        .getlastAccountUsed;
  }

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  Future<void> attemptLogIn(Account currentAccount, String password) async {
    if (!mounted) return;
    unawaited(Navigator.pushNamed(
      context,
      '/',
      arguments: {
        'statusText': 'Attempt login...\nCrypto in course',
        'isLoading': true,
        'spinner': true,
      },
    ));

    try {
      if (!mounted) return;
      final authProvider =
          Provider.of<AccountCredentials>(context, listen: false);
      await authProvider.login(currentAccount, password);

      if (!mounted) return;
      final idsProvider = Provider.of<Identities>(context, listen: false);
      await idsProvider.fetchOwnidenities();

      if (!mounted) return;
      if (idsProvider.ownIdentity.isEmpty) {
        await Navigator.pushReplacementNamed(
          context,
          '/create_identity',
          arguments: true,
        );
      } else {
        await Navigator.pushReplacementNamed(context, '/home');
      }
    } on HttpException catch (error) {
      if (!mounted) return;
      if (error.message.contains('WRONG PASSWORD')) {
        _handleWrongPassword();
      } else {
        await errorShowDialog(
          'Authentication Failed',
          error.message,
          context,
        );
        if (Navigator.canPop(context)) Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      await errorShowDialog(
        'Retroshare Service Down',
        'An error occurred: $e'.trim(),
        context,
      );
      if (Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  void _handleWrongPassword() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    if (mounted) {
      setState(() {
        wrongPassword = true;
      });
    }
  }

  List<DropdownMenuItem<Account>> _buildDropdownMenuItems() {
    final accounts =
        Provider.of<AccountCredentials>(context, listen: false).accountList;
    if (accounts.isEmpty && currentAccount != null) {
      return [
        DropdownMenuItem(
          value: currentAccount,
          key: UniqueKey(),
          child: Row(
            children: <Widget>[
              Text(currentAccount!.pgpName),
              if (!hideLocations) Text(':${currentAccount!.locationName}'),
            ],
          ),
        ),
      ];
    }
    return accounts.map((account) {
      return DropdownMenuItem(
        value: account,
        key: UniqueKey(),
        child: Row(
          children: <Widget>[
            Text(account.pgpName),
            if (!hideLocations) Text(':${account.locationName}'),
          ],
        ),
      );
    }).toList();
  }

  void _onAccountChanged(Account? selectedAccount) {
    if (selectedAccount != null) {
      setState(() {
        currentAccount = selectedAccount;
        wrongPassword = false;
      });
    }
  }

  void _revealLocations() {
    if (hideLocations && mounted) {
      setState(() {
        hideLocations = false;
      });
      showToast('Locations revealed', duration: const Duration(seconds: 2));
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

  Widget _buildAccountDropdown() {
    final dropdownItems = _buildDropdownMenuItems();
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: const Color(0xFFF5F5F5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        height: 40,
        child: GestureDetector(
          onLongPress: _revealLocations,
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.person_outline,
                color: Color(0xFF9E9E9E),
                size: 22,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: dropdownItems.isNotEmpty
                    ? DropdownButtonHideUnderline(
                        child: DropdownButton<Account>(
                          value: currentAccount,
                          items: dropdownItems,
                          onChanged: _onAccountChanged,
                          isExpanded: true,
                          hint: const Text('Select Account'),
                          disabledHint: currentAccount != null
                              ? Text(currentAccount!.pgpName)
                              : const Text('No accounts found'),
                        ),
                      )
                    : const Center(
                        child: Text(
                          'No accounts available. Please create one.',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: const Color(0xFFF5F5F5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        height: 40,
        child: TextField(
          controller: passwordController,
          decoration: const InputDecoration(
            border: InputBorder.none,
            icon: Icon(
              Icons.lock_outline,
              color: Color(0xFF9E9E9E),
              size: 22,
            ),
            hintText: 'Password',
          ),
          obscureText: true,
          onChanged: (_) {
            if (wrongPassword && mounted) {
              setState(() {
                wrongPassword = false;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildWrongPasswordError() {
    return Visibility(
      visible: wrongPassword,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: const Padding(
        padding: EdgeInsets.only(top: 8, left: 16, right: 16),
        child: Text(
          'Wrong password. Please try again.',
          style: TextStyle(color: Colors.red, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
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
      onPressed: (currentAccount == null || passwordController.text.isEmpty)
          ? null
          : () {
              if (currentAccount != null) {
                attemptLogIn(currentAccount!, passwordController.text);
              }
            },
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Text(
            'Sign In',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpButton(BuildContext context) {
    return TextButton(
      onPressed: () async {
        await Navigator.pushNamed(context, '/signup');
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
            style: TextStyle(color: Theme.of(context).colorScheme.secondary),
          ),
          Text(
            'Sign Up',
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentAccount == null) {
      final accounts =
          Provider.of<AccountCredentials>(context, listen: false).accountList;
      if (accounts.isNotEmpty) {
        currentAccount = Provider.of<AccountCredentials>(context, listen: false)
                .getlastAccountUsed ??
            accounts.first;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints viewportConstraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: viewportConstraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Spacer(),
                        _buildLogo(),
                        const SizedBox(height: 30),
                        _buildAccountDropdown(),
                        const SizedBox(height: 15),
                        _buildPasswordField(),
                        _buildWrongPasswordError(),
                        const SizedBox(height: 25),
                        _buildSignInButton(),
                        const SizedBox(height: 15),
                        _buildSignUpButton(context),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// WIP : Import Identity Functionlity
/** 

Future<bool> importAccountFunc(BuildContext context) async {
    // FilePickerResult result = await FilePicker.platform.pickFiles();
    final result = 'abc';
    if (result != null) {
      File pgpFile = File(
          '/data/user/0/cc.retroshare.retroshare/app_flutter/A154FAA45930DB66.txt');
      try {
        final file = pgpFile;
        final contents = await file.readAsString();
        final pgpId = await importIdentity(contents);
      } catch (e) {
        final snackBar = SnackBar(
          content: Text('Oops! Something went wrong'),
          duration: Duration(milliseconds: 200),
          backgroundColor: Colors.red[200],
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    } else {
      final snackBar = SnackBar(
        content: Text('Oops! Please pick up the file'),
        duration: Duration(milliseconds: 200),
        backgroundColor: Colors.red[200],
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }
  **/

///data/user/0/cc.retroshare.retroshare/app_flutter/A154FAA45930DB66.txt

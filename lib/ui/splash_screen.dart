import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/apiUtils/retroshare_service.dart';
import 'package:retroshare/common/color_loader_3.dart';
import 'package:retroshare/common/show_dialog.dart';
import 'package:retroshare/provider/auth.dart';
import 'package:retroshare/provider/identity.dart';
import 'package:retroshare_api_wrapper/retroshare.dart' as rs;

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.isLoading = false,
    this.statusText = '',
    this.spinner = false,
  });

  final bool isLoading;
  final bool spinner;
  final String statusText;

  @override
  SplashState createState() => SplashState();
}

class SplashState extends State<SplashScreen> {
  bool _spinner = false;
  String _statusText = '';
  bool _init = true;

  @override
  void didChangeDependencies() {
    if (_init) {
      if (!widget.isLoading) {
        _statusText = 'Loading...';
        _spinner = true;
        _initializeBackend();
      } else {
        _statusText = widget.statusText;
        _spinner = widget.spinner;
      }
    }
    _init = false;
    super.didChangeDependencies();
  }

  void _updateStatus(String text, {bool showSpinner = true}) {
    if (mounted) {
      setState(() {
        _statusText = text;
        _spinner = showSpinner;
      });
    }
  }

  Future<void> _initializeBackend() async {
    var retroshareStarted = false;
    while (!retroshareStarted) {
      try {
        _updateStatus('Starting Retroshare service...');
        await Future.delayed(const Duration(seconds: 2));
        await RsServiceControl.startRetroshare();
        retroshareStarted = await rs.isRetroshareRunning();

        if (retroshareStarted) {
          _updateStatus('Retroshare service started.');
          setControlCallbacks();
          await _checkAuthenticationAndNavigate();
        } else {
          _updateStatus('Retrying to start Retroshare service...');
        }
      } catch (err) {
        _updateStatus(
          'Error starting Retroshare: $err',
          showSpinner: false,
        );
        await Future.delayed(
          const Duration(seconds: 5),
        );
      }
    }
  }

  Future<void> _checkAuthenticationAndNavigate() async {
    if (!mounted) return;
    final auth = Provider.of<AccountCredentials>(context, listen: false);
    final ids = Provider.of<Identities>(context, listen: false);

    try {
      final isTokenValid = await auth.checkIsValidAuthToken();

      if (isTokenValid && auth.loggedinAccount != null) {
        _updateStatus('Logging in...');
        await ids.fetchOwnidenities();
        if (!mounted) return;
        if (ids.ownIdentity.isEmpty) {
          await Navigator.pushReplacementNamed(
            context,
            '/create_identity',
            arguments: true,
          );
        } else {
          await Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        _updateStatus('Fetching accounts...');
        await auth.fetchAuthAccountList();
        if (!mounted) return;
        if (auth.accountList.isEmpty) {
          await Navigator.pushReplacementNamed(context, '/launch_transition');
        } else {
          await Navigator.pushReplacementNamed(context, '/signin');
        }
      }
    } catch (e) {
      _updateStatus(
        'Error during authentication: $e',
        showSpinner: false,
      );
      if (mounted) {
        await errorShowDialog(
          'Authentication Error',
          'An error occurred: $e',
          context,
        );
        await Navigator.pushReplacementNamed(
          context,
          '/signin',
        );
      }
    }
  }

  Widget _buildLogo() {
    return Hero(
      tag: 'logo',
      child: Image.asset('assets/rs-logo.png'),
    );
  }

  Widget _buildStatusText() {
    return Text(
      _statusText,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.grey),
    );
  }

  Widget _buildSpinner() {
    return Visibility(
      visible: _spinner,
      child: const ColorLoader3(
        radius: 15,
        dotRadius: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _buildLogo(),
                const SizedBox(height: 20),
                _buildStatusText(),
                const SizedBox(height: 20),
                _buildSpinner(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

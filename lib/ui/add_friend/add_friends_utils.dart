import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/notifications.dart';
import 'package:retroshare/provider/auth.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class GetInvite extends StatefulWidget {
  const GetInvite({super.key});

  @override
  GetInviteState createState() => GetInviteState();
}

class GetInviteState extends State<GetInvite> with TickerProviderStateMixin {
  bool _isShortInvite = true;
  late final TextEditingController ownCertController;
  late final TabController tabController;

  late final Animation<double> _leftHeaderFadeAnimation;
  late final Animation<double> _leftHeaderScaleAnimation;
  late final Animation<double> _rightHeaderFadeAnimation;
  late final Animation<double> _rightHeaderScaleAnimation;

  @override
  void initState() {
    super.initState();
    _isShortInvite = true;
    ownCertController = TextEditingController();
    tabController = TabController(vsync: this, length: 2);

    _leftHeaderFadeAnimation = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(tabController.animation ?? kAlwaysDismissedAnimation);

    _leftHeaderScaleAnimation = Tween<double>(
      begin: 1,
      end: 0.5,
    ).animate(tabController.animation ?? kAlwaysDismissedAnimation);

    _rightHeaderFadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(tabController.animation ?? kAlwaysDismissedAnimation);

    _rightHeaderScaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1,
    ).animate(tabController.animation ?? kAlwaysDismissedAnimation);
  }

  @override
  void dispose() {
    ownCertController.dispose();
    tabController.dispose();
    super.dispose();
  }

  Future<String> _getCert() async {
    String ownCert;
    final authToken =
        Provider.of<AccountCredentials>(context, listen: false).authtoken;
    if (authToken == null) {
      throw 'authToken null';
    }
    try {
      if (!_isShortInvite) {
        ownCert = (await RsPeers.getOwnCert(authToken)).replaceAll('\n', '');
      } else {
        ownCert = await RsPeers.getShortInvite(authToken);
      }
      return ownCert;
    } catch (e) {
      debugPrint('Error fetching certificate: $e');
      rethrow;
    }
  }

  Widget buildAnimatedHeader() {
    return AnimatedBuilder(
      animation: tabController.animation ?? kAlwaysDismissedAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ScaleTransition(
              scale: _leftHeaderScaleAnimation,
              child: FadeTransition(
                opacity: _leftHeaderFadeAnimation,
                child: Text(
                  'Short Invite',
                  style: GoogleFonts.oxygen(fontSize: 15),
                ),
              ),
            ),
            ScaleTransition(
              scale: _rightHeaderScaleAnimation,
              child: FadeTransition(
                opacity: _rightHeaderFadeAnimation,
                child: Text(
                  'Long Invite',
                  style: GoogleFonts.oxygen(fontSize: 15),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget getinvitelink() {
    return FutureBuilder<String>(
      future: _getCert(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Stack(
            alignment: AlignmentDirectional.center,
            children: [
              Opacity(
                opacity: .2,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error, color: Colors.grey[600], size: 30),
                  const SizedBox(height: 8),
                  const Text(
                    'Could not load invite',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontFamily: 'Oxygen',
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Stack(
            alignment: AlignmentDirectional.center,
            children: [
              Opacity(
                opacity: .2,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 15),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent[100],
                      fontFamily: 'Oxygen',
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        if (snapshot.hasData) {
          final val = snapshot.data!;
          ownCertController.text = val;
          return Stack(
            alignment: AlignmentDirectional.center,
            children: [
              Opacity(
                opacity: .2,
                child: TextFormField(
                  controller: ownCertController,
                  readOnly: true,
                  maxLines: 10,
                  minLines: 10,
                  style: GoogleFonts.oxygen(
                    textStyle:
                        const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 10),
                    filled: true,
                    fillColor: Colors.black.withOpacity(.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () async {
                      if (ownCertController.text.isNotEmpty) {
                        await Clipboard.setData(
                          ClipboardData(text: ownCertController.text),
                        );
                        await showInviteCopyNotification();
                      }
                    },
                    icon: Icon(
                      Icons.copy,
                      color: Colors.blueAccent[200],
                      size: 30,
                    ),
                    tooltip: 'Copy Invite',
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Tap to copy',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Oxygen',
                      fontSize: 12,
                      color: Colors.blueAccent[100],
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text(
          'Retroshare Invite:',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontFamily: 'Oxygen'),
        ),
        const SizedBox(height: 8),
        getinvitelink(),
        const SizedBox(height: 6),
        SwitchListTile(
          value: _isShortInvite,
          title: buildAnimatedHeader(),
          onChanged: (newval) {
            setState(() {
              _isShortInvite = newval;
            });
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          activeColor: Colors.blueAccent,
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

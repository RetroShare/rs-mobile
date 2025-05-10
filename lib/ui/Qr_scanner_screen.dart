import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:oktoast/oktoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:retroshare/common/color_loader_3.dart';
import 'package:retroshare/common/styles.dart';
import 'package:retroshare/provider/auth.dart';
import 'package:retroshare/provider/friend_location.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';
import 'package:share_plus/share_plus.dart';

enum QRoperation { save, refresh, share }

class QRScanner extends StatefulWidget {
  const QRScanner({super.key});

  @override
  QRScannerState createState() => QRScannerState();
}

class QRScannerState extends State<QRScanner>
    with SingleTickerProviderStateMixin {
  bool check = true;
  final GlobalKey _globalkey = GlobalKey();
  TextEditingController ownCertController = TextEditingController();
  late TabController tabController;

  late Animation<double> _leftHeaderFadeAnimation;
  late Animation<double> _leftHeaderScaleAnimation;
  final bool _requestQR = false;
  late Animation<double> _rightHeaderFadeAnimation;
  late Animation<double> _rightHeaderScaleAnimation;

  @override
  void initState() {
    super.initState();
    tabController = TabController(vsync: this, length: 2);

    _leftHeaderFadeAnimation = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(tabController.animation!);

    _leftHeaderScaleAnimation = Tween<double>(
      begin: 1,
      end: 0.5,
    ).animate(tabController.animation!);

    _rightHeaderFadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(tabController.animation!);

    _rightHeaderScaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1,
    ).animate(tabController.animation!);
  }

  Future<String> _getCert() async {
    String ownCert;
    final authToken =
        Provider.of<AccountCredentials>(context, listen: false).authtoken;
    if (authToken == null) {
      return '';
    }
    if (!check) {
      ownCert = (await RsPeers.getOwnCert(authToken)).replaceAll('\n', '');
    } else {
      ownCert = await RsPeers.getShortInvite(
        authToken,
        sslId: Provider.of<AccountCredentials>(context)
            .lastAccountUsed!
            .locationId,
      );
    }
    await Future.delayed(const Duration(milliseconds: 60));
    return ownCert;
  }

  /// WIP : Permisssion for Camera
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;
    // Check if permission is neither granted nor permanently denied
    if (!status.isGranted && !status.isPermanentlyDenied) {
      final newStatus = await Permission.camera.request();
      // Return true only if the new status is granted
      return newStatus.isGranted;
    }
    // Return true if already granted
    return status.isGranted;
  }

  void checkServiceStatus(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Access Denied!'),
      ),
    );
  }

  Widget getHeaderBuilder() {
    return SizedBox(
      child: Stack(
        children: <Widget>[
          ScaleTransition(
            scale: _leftHeaderScaleAnimation,
            child: FadeTransition(
              opacity: _leftHeaderFadeAnimation,
              child: const Text(
                'Short Invite',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          ScaleTransition(
            scale: _rightHeaderScaleAnimation,
            child: FadeTransition(
              opacity: _rightHeaderFadeAnimation,
              child: const SizedBox(
                child: Text(
                  'Long Invite',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showQRScanner() async {
    final cameraPermission = await requestCameraPermission();
    if (!cameraPermission) {
      checkServiceStatus(context);
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: MobileScanner(
            onDetect: (capture) {
              final String? code = capture.barcodes.isNotEmpty
                  ? capture.barcodes.first.rawValue
                  : null;
              if (code != null) {
                Navigator.of(context).pop();
                // Delay to ensure the modal is closed before showing toast or updating state
                Future.microtask(() async {
                  try {
                    await Provider.of<FriendLocations>(context, listen: false)
                        .addFriendLocation(code);
                    showToast(
                      'Friend has successfully added',
                      position: ToastPosition.bottom,
                    );
                  } catch (e) {
                    showToast(
                      'An error occurred while adding your friend.',
                      position: ToastPosition.bottom,
                    );
                  }
                });
              }
            },
          ),
        );
      },
    );
  }

  PopupMenuItem popupchildWidget(String text, IconData icon, QRoperation val) {
    return PopupMenuItem(
      value: val,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
          ),
          const SizedBox(
            width: 7,
          ),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> onChanged(QRoperation val) async {
    if (val == QRoperation.save) {
      try {
        final RenderRepaintBoundary boundary = _globalkey.currentContext!
            .findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final ByteData? byteData =
            await image.toByteData(format: ImageByteFormat.png);
        if (byteData == null) {
          showToast(
            'Could not convert QR code to image data.',
            position: ToastPosition.bottom,
          );
          return;
        }
        final pngBytes = byteData.buffer.asUint8List();
        final appDir = await getApplicationDocumentsDirectory();
        await ImageGallerySaver.saveImage(Uint8List.fromList(pngBytes));
        await File('${appDir.path}/retroshare_qr_code.png').create();
        showToast(
          'Hey there! QR Image has successfully saved.',
          position: ToastPosition.bottom,
        );
      } catch (e) {
        showToast(
          'Oops! something went wrong.',
          position: ToastPosition.bottom,
        );
      }
    } else if (val == QRoperation.share) {
      final appDir = await getApplicationDocumentsDirectory();
      final filePath = '${appDir.path}/retroshare_qr_code.png';
      if (await File(filePath).exists()) {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'RetroShare invite',
        );
      } else {
        showToast(
          'QR code image not found. Save it first.',
          position: ToastPosition.bottom,
        );
      }
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.only(top: 40, left: 8, right: 8),
        child: Stack(
          children: [
            Column(
              children: <Widget>[
                SizedBox(
                  height: appBarHeight,
                  child: Row(
                    children: <Widget>[
                      Visibility(
                        child: SizedBox(
                          width: personDelegateHeight,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              size: 25,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'QR Scanner',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const Spacer(),
                      PopupMenuButton(
                        onSelected: (val) => onChanged(val),
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (BuildContext context) {
                          return [
                            popupchildWidget(
                              'Save',
                              Icons.save,
                              QRoperation.save,
                            ),
                            popupchildWidget(
                              'Refresh',
                              Icons.refresh,
                              QRoperation.refresh,
                            ),
                            popupchildWidget(
                              'Share',
                              Icons.share_rounded,
                              QRoperation.share,
                            ),
                          ];
                        },
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    child: Column(
                      children: <Widget>[
                        const SizedBox(
                          height: 20,
                        ),
                        Card(
                          elevation: 20,
                          child: Container(
                            padding: const EdgeInsets.all(25),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.all(
                                Radius.circular(
                                  20,
                                ), //         <--- border radius here
                              ),
                            ),
                            child: FutureBuilder(
                              future: _getCert(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                        ConnectionState.done &&
                                    snapshot.hasData) {
                                  return RepaintBoundary(
                                    key: _globalkey,
                                    child: QrImageView(
                                      data: snapshot.data ?? '',
                                      size: 240,
                                      errorStateBuilder: (context, error) {
                                        print('QR Error: $error');
                                        return const Center(
                                          child: Text(
                                            'Uh oh! Something went wrong.',
                                            textAlign: TextAlign.center,
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                }
                                return SizedBox(
                                  width: 240,
                                  height: 240,
                                  child: Center(
                                    child: snapshot.connectionState ==
                                            ConnectionState.waiting
                                        ? SizedBox(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  onPressed: () async {},
                                                  icon:
                                                      const Icon(Icons.refresh),
                                                ),
                                                const Text(
                                                  'Loading',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blueAccent,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : SizedBox(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  onPressed: () async {},
                                                  icon: const Icon(
                                                    Icons.error,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                                const Text(
                                                  'something went wrong !',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: SwitchListTile(
                            value: check,
                            title: getHeaderBuilder(),
                            onChanged: (newval) {
                              setState(() {
                                check = newval;
                              });
                              if (check) {
                                tabController.animateTo(0);
                              } else {
                                tabController.animateTo(1);
                              }
                            },
                          ),
                        ),
                        Qrinfo(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Visibility(
              visible: _requestQR,
              child: const Center(
                child: ColorLoader3(
                  radius: 15,
                  dotRadius: 6,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _showQRScanner();
        },
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Center(
            child: Icon(Icons.document_scanner),
          ),
        ),
      ),
    );
  }
}

Widget Qrinfo() {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 13),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Note :',
          style: GoogleFonts.oxygen(
            textStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '''
Use Long invite when you want to connect with computers running a retroshare version <0.6.6. Otherwise you can use Short invite''',
          style: GoogleFonts.oxygen(),
        ),
      ],
    ),
  );
}

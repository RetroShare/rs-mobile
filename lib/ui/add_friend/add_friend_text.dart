import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/color_loader_3.dart';
import 'package:retroshare/common/show_dialog.dart';
import 'package:retroshare/model/http_exception.dart';
import 'package:retroshare/provider/friend_location.dart';

import 'package:retroshare/ui/qr_scanner_screen.dart';

class GetAddfriend extends StatefulWidget {
  const GetAddfriend({super.key});

  @override
  GetAddfriendState createState() => GetAddfriendState();
}

class GetAddfriendState extends State<GetAddfriend> {
  TextEditingController ownCertController = TextEditingController();

  bool _requestAddCert = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            TextFormField(
              maxLines: 10,
              minLines: 6,
              controller: ownCertController,
              style: const TextStyle(
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                prefix: const SizedBox(
                  width: 10,
                ),
                hintStyle: const TextStyle(fontSize: 16, fontFamily: 'Oxygen'),
                labelStyle: const TextStyle(fontSize: 12),
                hintText: "Paste your friend's invite here",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _requestAddCert = true;
                });
                try {
                  await Provider.of<FriendLocations>(context, listen: false)
                      .addFriendLocation(ownCertController.text)
                      .then((value) {
                    setState(() {
                      _requestAddCert = false;
                    });
                    Fluttertoast.cancel();
                    showFlutterToast('Friend has been added', Colors.red);
                  });
                  await Navigator.of(context)
                      .pushReplacementNamed('/friends_locations');
                } on HttpException catch (_) {
                  setState(() {
                    _requestAddCert = false;
                  });
                  await Fluttertoast.cancel();
                  await showFlutterToast('Invalid certi', Colors.red);
                } catch (e) {
                  setState(() {
                    _requestAddCert = false;
                  });
                  await Fluttertoast.cancel();
                  await showFlutterToast('something went wrong', Colors.red);
                }
              },
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: <Color>[
                        Color(0xFF00FFFF),
                        Color(0xFF29ABE2),
                      ],
                      begin: Alignment(-1, -4),
                      end: Alignment(1, 4),
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: const Text(
                    'Add Friend',
                    style: TextStyle(fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const Align(
              child: Text(
                'OR',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const QRScanner()));
              },
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: <Color>[Colors.purple, Colors.purpleAccent],
                      begin: Alignment(-1, -4),
                      end: Alignment(1, 4),
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: const Text(
                    'Add Friend via QR',
                    style: TextStyle(fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
        Center(
          child: Visibility(
            visible: _requestAddCert,
            child: const ColorLoader3(
              radius: 15,
              dotRadius: 6,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:cooler_alerts/cooler_alerts.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/styles.dart';
import 'package:retroshare/model/http_exception.dart';
import 'package:retroshare/provider/identity.dart';

Future errorShowDialog(String title, String text, BuildContext context) {
  return CoolerAlerts.show(
    context: context,
    type: CoolAlertType.error,
    onConfirmBtnTap: (context) {
      if (Navigator.canPop(context)) Navigator.of(context).pop();
      if (Navigator.canPop(context)) Navigator.of(context).pop();
    },
    title: title,
    text: text,
  );
}

Future loading(BuildContext context) {
  return CoolerAlerts.show(context: context, type: CoolAlertType.loading);
}

Future successShowDialog(String title, String text, BuildContext context) {
  return CoolerAlerts.show(
    context: context,
    type: CoolAlertType.success,
    onConfirmBtnTap: (context) {
      if (Navigator.canPop(context)) Navigator.of(context).pop();
      if (Navigator.canPop(context)) Navigator.of(context).pop();
    },
    title: title,
    text: text,
  );
}

Future warningShowDialog(String title, String text, BuildContext context) {
  return CoolerAlerts.show(
    context: context,
    type: CoolAlertType.warning,
    onConfirmBtnTap: (context) {
      if (Navigator.canPop(context)) Navigator.of(context).pop();
      if (Navigator.canPop(context)) Navigator.of(context).pop();
    },
    title: title,
    text: text,
  );
}

Future<bool?> showFlutterToast(String title, Color color) {
  return Fluttertoast.showToast(
    msg: title,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    backgroundColor: color,
    textColor: Colors.white,
    fontSize: 16,
  );
}

Stack contentBox(BuildContext context) {
  return Stack(
    children: <Widget>[
      Container(
        padding: const EdgeInsets.only(
          left: Constants.padding,
          top: Constants.avatarRadius,
          right: Constants.padding,
          bottom: Constants.padding,
        ),
        margin: const EdgeInsets.only(top: Constants.avatarRadius),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Constants.padding),
          boxShadow: const [
            BoxShadow(offset: Offset(0, 10), blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'something went Wrong!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(
              height: 15,
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'OK',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
      const Positioned(
        left: Constants.padding,
        right: Constants.padding,
        child: CircleAvatar(
          backgroundColor: Colors.transparent,
          radius: Constants.avatarRadius,
          child: ClipRRect(
            borderRadius:
                BorderRadius.all(Radius.circular(Constants.avatarRadius)),
            child: Image(
              image: AssetImage('assets/rs-logo.png'),
            ),
          ),
        ),
      ),
    ],
  );
}

// delete dialog Box

void showdeleteDialog(BuildContext context) {
  final name =
      Provider.of<Identities>(context, listen: false).currentIdentity?.name;
  final ownIdsList =
      Provider.of<Identities>(context, listen: false).ownIdentity;

  if (ownIdsList.length > 1) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete '${name ?? 'Unknown'}'?"),
          content: const Text(
            'The deletion of identity cannot be undone. Are you sure you want to continue?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await Provider.of<Identities>(context, listen: false)
                      .deleteIdentity()
                      .then((value) {
                    Navigator.of(context).pop();
                  });
                } on HttpException catch (_) {
                  await warningShowDialog(
                    'Retro Service is Down',
                    'Please ensure retroshare service is not down',
                    context,
                  );
                } catch (e) {
                  await warningShowDialog(
                    'Try Again',
                    'Something wrong happens!',
                    context,
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  } else {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Too few identities'),
          content: const Text(
            'You must have at least one more identity to be able to delete this one.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Ok'),
            ),
          ],
        );
      },
    );
  }
}

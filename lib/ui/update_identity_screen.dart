import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/bottom_bar.dart';
import 'package:retroshare/common/color_loader_3.dart';
import 'package:retroshare/common/image_picker_dialog.dart';
import 'package:retroshare/common/show_dialog.dart';
import 'package:retroshare/common/styles.dart';
import 'package:retroshare/provider/identity.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class UpdateIdentityScreen extends StatefulWidget {
  const UpdateIdentityScreen({super.key, this.curr});
  final dynamic curr;

  @override
  UpdateIdentityScreenState createState() => UpdateIdentityScreenState();
}

class UpdateIdentityScreenState extends State<UpdateIdentityScreen> {
  TextEditingController nameController = TextEditingController();
  RsGxsImage _image = RsGxsImage();
  bool _showError = false;
  bool _requestCreateIdentity = false;
  @override
  void initState() {
    super.initState();
    final curr = widget.curr;
    nameController = TextEditingController(text: curr?.name ?? '');
    if (curr != null && curr.avatar != null) {
      _image = RsGxsImage(mData: base64.decode(curr.avatar));
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _setImage(File? image) async {
    Navigator.pop(context);
    setState(() {
      _image = RsGxsImage(mData: image?.readAsBytesSync());
    });
  }

  // Validate the Name
  bool _validate(text) {
    return nameController.text.length >= 3;
  }

  @override
  Widget build(BuildContext context) {
    Future<void> _updateIdentity() async {
      try {
        final curr = widget.curr;
        await Provider.of<Identities>(context, listen: false)
            .updateIdentity(
          Identity(
            mId: curr?.mId ?? '',
            signed: curr?.signed ?? false,
            isContact: curr?.isContact ?? false,
            name: nameController.text,
            avatar: _image.base64String,
          ),
          _image,
        )
            .then((value) {
          Navigator.pop(context);
        });
      } catch (e) {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Constants.padding),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: contentBox(context),
            );
          },
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
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
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.zero,
                      child: Text(
                        'Update identity',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton(
                    onSelected: (val) {
                      showdeleteDialog(context);
                    },
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (BuildContext context) {
                      return [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete,
                                size: 20,
                              ),
                              SizedBox(
                                width: 7,
                              ),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder:
                    (BuildContext context, BoxConstraints viewportConstraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: viewportConstraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Center(
                          child: SizedBox(
                            width: 300,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const SizedBox(
                                  height: 20,
                                ),
                                GestureDetector(
                                  onTap: () {
                                    imagePickerDialog(context, _setImage);
                                  },
                                  child: Container(
                                    height: 300 * 0.7,
                                    width: 300 * 0.7,
                                    decoration: _image.mData == null
                                        ? null
                                        : BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              300 * 0.7 * 0.33,
                                            ),
                                            image: DecorationImage(
                                              fit: BoxFit.fill,
                                              image: MemoryImage(_image.mData!),
                                            ),
                                          ),
                                    child: Visibility(
                                      visible: _image.mData == null ||
                                          _image.mData!.isEmpty,
                                      child: const Center(
                                        child: Icon(
                                          Icons.person,
                                          size: 300 * 0.7,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  height: 50,
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      color: const Color(0xFFF5F5F5),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                    ),
                                    height: 40,
                                    child: TextField(
                                      controller: nameController,
                                      enabled: !_requestCreateIdentity,
                                      onChanged: (text) {
                                        setState(() {
                                          _showError = !_validate(text);
                                        });
                                      },
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        icon: Icon(
                                          Icons.person_outline,
                                          color: Color(0xFF9E9E9E),
                                          size: 22,
                                        ),
                                        hintText: 'Name',
                                      ),
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ),
                                ),
                                Visibility(
                                  visible: _showError,
                                  child: const SizedBox(
                                    width: double.infinity,
                                    child: Row(
                                      children: <Widget>[
                                        SizedBox(
                                          width: 52,
                                        ),
                                        SizedBox(
                                          height: 25,
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              'Name too short',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  height: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Visibility(
              visible: !_requestCreateIdentity,
              child: BottomBar(
                child: Center(
                  child: SizedBox(
                    height: 2 * appBarHeight / 3,
                    child: Builder(
                      builder: (context) => ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            _showError = !_validate(nameController.text);
                          });
                          if (!_showError) {
                            setState(() {
                              _requestCreateIdentity = true;
                            });

                            await _updateIdentity();
                          }
                        },
                        child: SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
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
                            child: Text(
                              'Update Identity',
                              style: Theme.of(context).textTheme.labelLarge,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Visibility(
              visible: _requestCreateIdentity,
              child: const ColorLoader3(
                radius: 15,
                dotRadius: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

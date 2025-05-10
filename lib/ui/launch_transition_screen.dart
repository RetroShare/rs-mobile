import 'package:flutter/material.dart';

class LaunchTransitionScreen extends StatefulWidget {
  const LaunchTransitionScreen({super.key});

  @override
  LaunchTransitionScreenState createState() => LaunchTransitionScreenState();
}

class LaunchTransitionScreenState extends State<LaunchTransitionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints viewportConstraints) {
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
                        Expanded(
                          flex: 7,
                          child: Hero(
                            tag: 'logo',
                            child: Image.asset(
                              'assets/rs-logo.png',
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: <Widget>[
                              ElevatedButton(
                                onPressed: () async {
                                  await Navigator.pushNamed(context, '/signup');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: const GradientButton(
                                  text: 'Create account',
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
          text,
          style: const TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/** WIP Import Identity Feature
  

Future<bool> importAccountFunc(BuildContext context) async {
    FilePickerResult result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File pgpFile = File(result.files.single.path);
      try {
        final file = pgpFile;
        final contents = await file.readAsString();
        await importIdentity(contents);
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
  }*/

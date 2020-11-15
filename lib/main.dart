import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'dart:ui' as ui;
//import 'package:image_picker/image_picker.dart';

//void main() => runApp(MyApp());

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

enum Status { Uninitialized, Authenticated, Authenticating, Unauthenticated }
FirebaseFirestore firestore = FirebaseFirestore.instance;
final List<WordPair> _suggestions = <WordPair>[];
final TextStyle _biggerFont = const TextStyle(fontSize: 18);
final _saved = Set<WordPair>(); // NEW
String _userEmail = "temp";

bool isEnabled = true;
var _status = Status.Uninitialized;
var _validate = false;
String _image = null;

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Text(snapshot.error.toString(),
                      textDirection: TextDirection.ltr)));
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return MyApp();
        }
        return Center(child: CircularProgressIndicator());
      },
    );
  }
}

class Auth with ChangeNotifier {
  final _auth = FirebaseAuth.instance;

  void notValid() {
    _validate = true;
    notifyListeners();
  }

  void Valididate() {
    _validate = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.signOut();
    _status = Status.Unauthenticated;
    _saved.clear();
    notifyListeners();
  }

  Future<void> addUser(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      _userEmail = email;
      firestore.collection('users').doc(email).set({});
    } on FirebaseAuthException catch (e) {}
    _status = Status.Authenticated;
    _userEmail = email;
    firestore
        .collection('users')
        .doc(_userEmail)
        .set({}, SetOptions(merge: true));
    _saved.forEach((element) {
      addItem(element);
    });
    DocumentSnapshot querySnapshot =
        await firestore.collection("users").doc(_userEmail).get();
    querySnapshot.data().forEach((key, value) {
      String prefix = key.split(' ')[0].toString();
      String last = key.split(' ')[1].toString();
      var word = WordPair(prefix, last);
      addItem(word);
    });
    try {
      _image = await FirebaseStorage.instance
          .ref('uploads')
          .child("default.jpg")
          .getDownloadURL();
    } catch (e) {
      _image = null;
    }
    notifyListeners();
  }

  Future<void> removeItem(WordPair pair) async {
    _saved.remove(pair);
    if (_status == Status.Authenticated) {
      firestore
          .collection("users")
          .doc(_userEmail)
          .update({pair.first + ' ' + pair.second: FieldValue.delete()});
    }
    notifyListeners();
  }

  void addItem(WordPair pair) {
    _saved.add(pair);
    if (_status == Status.Authenticated) {
      firestore
          .collection("users")
          .doc(_userEmail)
          .update({pair.first + ' ' + pair.second: pair.toString()});
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _status = Status.Authenticated;
      _userEmail = email;
      firestore
          .collection('users')
          .doc(_userEmail)
          .set({}, SetOptions(merge: true));
      _saved.forEach((element) {
        addItem(element);
      });
      DocumentSnapshot querySnapshot =
          await firestore.collection("users").doc(_userEmail).get();
      querySnapshot.data().forEach((key, value) {
        String prefix = key.split(' ')[0].toString();
        String last = key.split(' ')[1].toString();
        var word = WordPair(prefix, last);
        addItem(word);
      });
      //_image=null;
      try {
        _image = await FirebaseStorage.instance
            .ref('uploads')
            .child(_userEmail)
            .getDownloadURL();
      } catch (e) {
        _image = null;
      }
      if (_image == null) {
        try {
          _image = await FirebaseStorage.instance
              .ref('uploads')
              .child("default.jpg")
              .getDownloadURL();
        } catch (e) {
          _image = null;
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      return false;
    }
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (_) => Auth(),
        child: MaterialApp(
          title: 'Startup Name Generator',
          theme: ThemeData(
            // Add the 3 lines from here...
            primaryColor: Colors.red,
          ),
          home: RandomWords(),
        ));
  }
}

class RandomWords extends StatefulWidget {
  @override
  _RandomWordsState createState() => _RandomWordsState();
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController2 = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    _validate = false;
    _emailController.clear();
    _passwordController.clear();
    _passwordController2.clear();
    // NEW lines from here...
    final welcomTest = Container(
      // padding: EdgeInsets.only(bottom: 20.0),
      child: Text(
        'Welcome to Startup Names Generator, please log in below',
        style: TextStyle(fontSize: 17),
      ),
    );

    final emailField = Container(
      //  padding: EdgeInsets.only(bottom: 20.0),
      child: TextField(
        controller: _emailController,
        decoration: InputDecoration(
          labelText: 'Email',
          labelStyle: TextStyle(fontSize: 20),
          //contentPadding: EdgeInsets.only(top: 40.0),
        ),
      ),
    );

    final passwordField = Container(
      //   padding: EdgeInsets.only(bottom: 30.0),
      child: TextField(
        controller: _passwordController,
        obscureText: true,
        decoration: InputDecoration(
          labelText: 'Password',
          labelStyle: TextStyle(fontSize: 20),
        //  contentPadding: EdgeInsets.only(top: 40.0),
        ),
      ),
    );

    final passwordField2 = Container(
      //  padding: EdgeInsets.only(bottom: 30.0),
      child: Consumer<Auth>(
        builder: (context, auth, _) => TextField(
          obscureText: true,
          controller: _passwordController2,
          decoration: InputDecoration(
            errorText: _validate ? 'Passwords must match' : null,
            labelText: 'Password',
            labelStyle: TextStyle(fontSize: 15),
            contentPadding: EdgeInsets.only(top: 40.0),
          ),
        ),
      ),
    );

    final _loginButton = Container(
      width: 60.0,
      height: 40.0,
      child: Consumer<Auth>(
        builder: (context, auth, _) => RaisedButton(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: Colors.red)),
          onPressed: _status != Status.Authenticating
              ? () async {
                  if (await auth.signIn(
                      _emailController.text, _passwordController.text)) {
                    Navigator.pop(context);
                  } else {
                    final snackBar = SnackBar(
                      content: Text('There was an error logging into the app'),
                      action: SnackBarAction(
                        label: '',
                        onPressed: () {},
                      ),
                    );
                    Scaffold.of(context).showSnackBar(snackBar);
                  }
                }
              : null,
          color: Colors.red,
          textColor: Colors.white,
          child: Text("Log in".toUpperCase(), style: TextStyle(fontSize: 14)),
        ),
      ),
    );

    final _regButton = Container(
      width: 60.0,
      height: 40.0,
      child: Consumer<Auth>(
        builder: (context, auth, _) => RaisedButton(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: Colors.teal)),
          onPressed: () {
            //setState(() {
            // _passwordController2.clear();
            // });
            _passwordController2.text = "";
            auth.Valididate();
            showModalBottomSheet(
              backgroundColor: Colors.white,
              context: context,
              isScrollControlled: true,
              builder: (context) => SingleChildScrollView(
                child: Container(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom),
                    child: Container(
                      height: 180.0,
                      child: ListView(
                        children: [
                          SizedBox(height: 10),
                          Center(
                              child:
                                  Text("Please confirm your password below")),
                          passwordField2,
                          SizedBox(height: 10),
                          Center(
                              child: RaisedButton(
                                  color: Colors.teal,
                                  textColor: Colors.white,
                                  child: Text("Confirm".toUpperCase(),
                                      style: TextStyle(fontSize: 14)),
                                  onPressed: () async {
                                    if (_passwordController.text ==
                                        _passwordController2.text) {
                                      await auth.addUser(_emailController.text,
                                          _passwordController.text);
                                      Navigator.pop(context);
                                      Navigator.pop(context);
                                    } else {
                                      auth.notValid();
                                    }
                                  }))
                        ],
                      ),
                      color: Colors.white,
                    )),
              ),
            );
          },
          color: Colors.teal,
          textColor: Colors.white,
          child: Text("New user? Click to sign up",
              style: TextStyle(fontSize: 14)),
        ),
      ),
    );

    return Scaffold(
        appBar: AppBar(
          title: Text('Login'),
          centerTitle: true,
        ),
        body: Builder(
          builder: (context) => ListView(//padding: EdgeInsets.only(top: 40),
              children: [
            SizedBox(height: 30),
            welcomTest,
            SizedBox(height: 10),
            emailField,
            passwordField,
            SizedBox(height: 20),
            _loginButton,
            SizedBox(height: 10),
            _regButton
          ]),
        )); // ...to here.
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordController2.dispose();
    super.dispose();
  }
}

class _RandomWordsState extends State<RandomWords>
    with SingleTickerProviderStateMixin {
  final globalKey = GlobalKey<ScaffoldState>();
  final globalKey2 = GlobalKey<ScaffoldState>();
  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // NEW lines from here...
        builder: (BuildContext context) {
          return Scaffold(
            key: globalKey,
            appBar: AppBar(
              title: Text('Saved Suggestions'),
            ),
            body: Consumer<Auth>(
              builder: (context, auth, _) {
                final tiles = _saved.map(
                  (WordPair pair) {
                    return ListTile(
                      title: Text(
                        pair.asPascalCase,
                        style: _biggerFont,
                      ),
                      trailing: GestureDetector(
                          onTap: () {
                            auth.removeItem(pair);
                          },
                          child: Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          )),
                    );
                  },
                );
                final divided = ListTile.divideTiles(
                  context: context,
                  tiles: tiles,
                ).toList();

                return ListView(children: divided);
              },
            ),
          );
        }, // ...to here.
      ),
    );
  }

  Future<bool> chooseFile() async {
    File result = await FilePicker.getFile();
    if (result != null) {
      var ret = await FirebaseStorage.instance
          .ref('uploads')
          .child(_userEmail)
          .putFile(result)
          .then((snapshot) => snapshot.ref.getDownloadURL());
      setState(() {
        _image = ret;
      });
      return true;
    }
    return false;
  }

  Future findImage() async {
    FirebaseStorage.instance.ref('uploads/' + _userEmail);
    //   .writeToFile(_image);
  }

  var _controller = SnappingSheetController();
  String _uploadedFileURL;
  double _moveAmount = 0.0;
  //final picker = ImagePicker();
  @override
  Widget build(BuildContext context) {
    return Consumer<Auth>(builder: (context, auth, _) {
      var iconSee;
      double hig = 200;
      var downSheet = Container(
        width: 20.0,
        height: 20.0,
        child: ListView(children: [
          SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 10),
              _image != null
                  ? Container(
                      width: 60.0,
                      height: 60.0,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                              fit: BoxFit.fill, image: NetworkImage(_image))))
                  : Container(
                      width: 60.0,
                      height: 60.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.teal,
                      )),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_userEmail, style: TextStyle(fontSize: 15.0)),
                  FlatButton(
                    onPressed: () async {
                      if (!await chooseFile()) {
                        final snackBar = SnackBar(
                          content: Text('No image selected'),
                          action: SnackBarAction(
                            label: '',
                            onPressed: () {},
                          ),
                        );
                        globalKey2.currentState.showSnackBar(snackBar);
                      }
                      // findImage();
                    },
                    color: Colors.teal,
                    child: Text("Change Avatar"),
                    textColor: Colors.white,
                  ),
                ],
              )
            ],
          ),
        ]),
        color: Colors.white,
      );
      if (_status == Status.Authenticated) {
        iconSee =
            IconButton(icon: Icon(Icons.exit_to_app), onPressed: auth.logout);
      } else {
        iconSee = IconButton(
            icon: Icon(Icons.login),
            onPressed: // _pushLogin
                () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            });
      }
      return Scaffold(
        key: globalKey2,
        appBar: AppBar(
          title: Text('Startup Name Generator'),
          actions: [
            IconButton(icon: Icon(Icons.favorite), onPressed: _pushSaved),
            iconSee,
          ],
        ),
        body: _status != Status.Authenticated
            ? _buildSuggestions()
            : SnappingSheet(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _buildSuggestions(),
                    _moveAmount < 1
                        ? SizedBox()
                        : BackdropFilter(
                            filter: ui.ImageFilter.blur(
                              sigmaX: _moveAmount / 100,
                              sigmaY: _moveAmount / 100,
                            ),
                            child: Container(
                              color: Colors.transparent,
                            ),
                          )
                  ],
                ),
                //  sheetAbove: SnappingSheetContent(child: _buildSuggestions()),
                onMove: (moveAmount) {
                  setState(() {
                    _moveAmount = moveAmount;
                  });
                },
                snappingSheetController: _controller,
                snapPositions: const [
                  SnapPosition(
                      positionPixel: 0.0,
                      snappingCurve: Curves.elasticOut,
                      snappingDuration: Duration(milliseconds: 750)),
                  SnapPosition(positionFactor: 0.2),
                  SnapPosition(positionFactor: 0.2),
                ],
                grabbingHeight: 50,
                grabbing: InkWell(
                  child: Container(
                      color: Colors.grey,
                      child: ListTile(
                        title: Text("welcome back, " + _userEmail,
                            style: TextStyle(fontSize: 15.0)),
                        trailing: Icon(Icons.arrow_drop_up),
                      )),
                  onTap: () {
                    if (_controller.snapPositions.last !=
                        _controller.currentSnapPosition) {
                      _controller
                          .snapToPosition(_controller.snapPositions.last);
                    } else {
                      _controller
                          .snapToPosition(_controller.snapPositions.first);
                    }
                  },
                ),
                sheetBelow: SnappingSheetContent(
                  child: downSheet,
                  heightBehavior: SnappingSheetHeight.fit(),
                ),
              ),
      );
    });
  }
  //  );

  Widget _buildRow(WordPair pair) {
    return Consumer<Auth>(
      builder: (context, auth, _) {
        final alreadySaved = _saved.contains(pair);
        return ListTile(
          title: Text(
            pair.asPascalCase,
            style: _biggerFont,
          ),
          trailing: Icon(
            alreadySaved ? Icons.favorite : Icons.favorite_border,
            color: alreadySaved ? Colors.red : null,
          ),
          onTap: () {
            // NEW lines from here...
            //    setState(() {
            if (alreadySaved) {
              auth.removeItem(pair);
            } else {
              auth.addItem(pair);
            }
            //  });
          }, // ... to here.
        ); //
      },
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        // The itemBuilder callback is called once per suggested
        // word pairing, and places each suggestion into a ListTile
        // row. For even rows, the function adds a ListTile row for
        // the word pairing. For odd rows, the function adds a
        // Divider widget to visually separate the entries. Note that
        // the divider may be difficult to see on smaller devices.
        itemBuilder: (BuildContext _context, int i) {
          // Add a one-pixel-high divider widget before each row
          // in the ListView.
          if (i.isOdd) {
            return Divider();
          }

          // The syntax "i ~/ 2" divides i by 2 and returns an
          // integer result.
          // For example: 1, 2, 3, 4, 5 becomes 0, 1, 1, 2, 2.
          // This calculates the actual number of word pairings
          // in the ListView,minus the divider widgets.
          final int index = i ~/ 2;
          // If you've reached the end of the available word
          // pairings...
          if (index >= _suggestions.length) {
            // ...then generate 10 more and add them to the
            // suggestions list.
            _suggestions.addAll(generateWordPairs().take(10));
          }
          return _buildRow(_suggestions[index]);
        });
  }
}

/*
  void _pushLogin() {
    _validate = false;
    _emailController.clear();
    _passwordController.clear();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // NEW lines from here...
        builder: (BuildContext context) {
          final welcomTest = Container(
            padding: EdgeInsets.only(bottom: 20.0),
            child: Text(
              'Welcome to Startup Names Generator, please log in below',
              style: TextStyle(fontSize: 17),
            ),
          );

          final emailField = Container(
            padding: EdgeInsets.only(bottom: 20.0),
            child: TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(fontSize: 20),
                contentPadding: EdgeInsets.only(top: 40.0),
              ),
            ),
          );

          final passwordField = Container(
            padding: EdgeInsets.only(bottom: 30.0),
            child: TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(fontSize: 20),
                contentPadding: EdgeInsets.only(top: 40.0),
              ),
            ),
          );

          final passwordField2 = Container(
            padding: EdgeInsets.only(bottom: 30.0),
            child: Consumer<Auth>(
              builder: (context, auth, _) =>TextField(
              obscureText: true,
              controller: _passwordController2,
              decoration: InputDecoration(
                errorText: _validate ? 'Passwords must match' : null,
                labelText: 'Password',
                labelStyle: TextStyle(fontSize: 15),
                contentPadding: EdgeInsets.only(top: 40.0),
              ),
            ),
            ),
          );

          final _loginButton = Container(
            width: 60.0,
            height: 40.0,
            child: Consumer<Auth>(
              builder: (context, auth, _) => RaisedButton(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: Colors.red)),
                onPressed: _status != Status.Authenticating
                    ? () async {
                        if (await auth.signIn(
                            _emailController.text, _passwordController.text)) {
                          Navigator.pop(context);
                        } else {
                          final snackBar = SnackBar(
                            content:
                                Text('There was an error logging into the app'),
                            action: SnackBarAction(
                              label: '',
                              onPressed: () {},
                            ),
                          );
                          Scaffold.of(context).showSnackBar(snackBar);
                        }
                      }
                    : null,
                color: Colors.red,
                textColor: Colors.white,
                child: Text("Log in".toUpperCase(),
                    style: TextStyle(fontSize: 14)),
              ),
            ),
          );

          final _regButton = Container(
            width: 60.0,
            height: 40.0,
            child: Consumer<Auth>(
              builder: (context, auth, _) => RaisedButton(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: Colors.teal)),
                onPressed: () {
                  showModalBottomSheet(
                    backgroundColor: Colors.white,
                    context: context,
                    isScrollControlled: true,
                    builder: (context) =>SingleChildScrollView(
                      child: Container(
                        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                        child: Container(
                          height: 200.0,
                      child:ListView(
                        children: [
                          SizedBox(height: 10),
                          Center(
                              child:
                                  Text("Please confirm your password below")),
                          passwordField2,
                          Center(
                              child: RaisedButton(
                                  color: Colors.teal,
                                  textColor: Colors.white,
                                  child: Text("Confirm".toUpperCase(),
                                      style: TextStyle(fontSize: 14)),
                                  onPressed:
                                  _passwordController2.text == _passwordController.text
                                      ? ()  async {await auth.addUser(
                                              _emailController.text,
                                              _passwordController.text);
                                            _validate = true;
                                          Navigator.pop(context);
                                          Navigator.pop(context);
                                        }
                                      : () {
                                    auth.notValid();
                                  }
                                      )
                          )
                        ],
                      ),
                      color: Colors.white,
                    )),
                    ),
                  );
                },
                color: Colors.teal,
                textColor: Colors.white,
                child: Text("New user? Click to sign up",
                    style: TextStyle(fontSize: 14)),
              ),
            ),
          );

          return Scaffold(
              appBar: AppBar(
                title: Text('Login'),
                centerTitle: true,
              ),
              body: Builder(
                builder: (context) =>
                    ListView(padding: EdgeInsets.only(top: 40), children: [
                  welcomTest,
                  emailField,
                  passwordField,
                  _loginButton,
                  SizedBox(height: 10),
                  _regButton
                ]),
              ));
        }, // ...to here.
      ),
    );
  }
*/

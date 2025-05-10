import 'package:flutter/material.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/person_delegate.dart';
import 'package:retroshare/common/show_dialog.dart';
import 'package:retroshare/common/styles.dart';
import 'package:retroshare/provider/friend_location.dart';
import 'package:retroshare/provider/identity.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare/provider/subscribed.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  CreateRoomScreenState createState() => CreateRoomScreenState();
}

class CreateRoomScreenState extends State<CreateRoomScreen>
    with TickerProviderStateMixin {
  final TextEditingController _inviteFriendsController =
      TextEditingController();
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _roomTopicController = TextEditingController();
  bool isPublic = true;
  bool isAnonymous = true;

  bool _isRoomCreation = false;
  bool _blockCreation = false; //Used to prevent double click on room creation
  late Animation<double> _fadeAnimation;
  late Animation<double> _heightAnimation;
  late Animation<double> _buttonHeightAnimation;
  late Animation<double> _buttonFadeAnimation;
  late AnimationController _animationController;

  late Animation<Color?> _doneButtonColor;
  late AnimationController _doneButtonController;

  late List<Identity> _friendsList;
  late List<Identity> _suggestionsList;
  late List<Location> _locationsList;
  late List<Location> _selectedLocations;
  bool _init = true;
  @override
  void initState() {
    super.initState();
    _init = true;
    _isRoomCreation = false;
    isPublic = true;
    isAnonymous = true;
    _blockCreation = false;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _doneButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _roomNameController.addListener(() {
      if (_isRoomCreation && _roomNameController.text.length > 2) {
        _doneButtonController.forward();
      } else {
        _doneButtonController.reverse();
      }
    });

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0.5,
          1,
          curve: Curves.easeInOut,
        ),
      ),
    );

    _heightAnimation = Tween<double>(
      begin: 40,
      end: 5 * 40.0 + 3 * 8.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _buttonHeightAnimation = Tween<double>(
      begin: personDelegateHeight - 15,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _buttonFadeAnimation = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(
          0,
          0.75,
          curve: Curves.easeInOut,
        ),
      ),
    );

    _doneButtonColor =
        ColorTween(begin: const Color(0xFF9E9E9E), end: Colors.black).animate(
      CurvedAnimation(
        parent: _doneButtonController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) {
      Provider.of<FriendLocations>(context, listen: false)
          .fetchfriendLocation();
      final identities = Provider.of<RoomChatLobby>(context, listen: false);
      final locations = Provider.of<FriendLocations>(context, listen: false);
      _friendsList = identities.friendsSignedIdsList;
      _suggestionsList = identities.friendsSignedIdsList;
      _locationsList = locations.friendlist;
      _selectedLocations = <Location>[];
    }
    _init = false;
  }

  @override
  void dispose() {
    _inviteFriendsController.dispose();
    _roomNameController.dispose();
    _roomTopicController.dispose();
    _animationController.dispose();
    _doneButtonController.dispose();

    super.dispose();
  }

  void _onGoBack() {
    if (_isRoomCreation) {
      _animationController.reverse();
      setState(() {
        _isRoomCreation = false;
      });
    } else {
      Navigator.pop(context, true);
    }
  }

  Future<void> _createChat() async {
    if (_isRoomCreation && !_blockCreation) {
      _blockCreation = true;
      await _doneButtonController.reverse();
      final currentIdentity =
          Provider.of<Identities>(context, listen: false).currentIdentity;
      if (currentIdentity == null) return;
      final id = currentIdentity.mId;
      try {
        await Provider.of<ChatLobby>(context, listen: false)
            .createChatlobby(
          _roomNameController.text,
          id,
          _roomTopicController.text,
          inviteList: _selectedLocations,
          anonymous: isAnonymous,
          public: isPublic,
        )
            .then((value) {
          Navigator.of(context).pop();
        });
      } catch (e) {
        await errorShowDialog('Error', 'Try to retart the app!', context);
      }

      await _doneButtonController.forward();
      _blockCreation = false;
    }
  }

  void _updateSuggestions(filteredList) {
    setState(() {
      _suggestionsList = filteredList;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) {
          return;
        }
        _onGoBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      height: appBarHeight,
                      width: personDelegateHeight,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          size: 25,
                        ),
                        onPressed: _onGoBack,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: AnimatedBuilder(
                          animation: _animationController,
                          builder: (BuildContext context, Widget? child) {
                            return SizedBox(
                              height: _heightAnimation.value + 10,
                              child: Stack(
                                children: <Widget>[
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: SizedBox(
                                      height: 4 * 40.0 + 3 * 8,
                                      width: double.infinity,
                                      child: FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: <Widget>[
                                            const SizedBox(
                                              height: 8,
                                            ),
                                            Visibility(
                                              visible: _heightAnimation.value >=
                                                  4 * 40.0 + 3 * 8,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  color:
                                                      const Color(0xFFF5F5F5),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 15,
                                                ),
                                                height: 40,
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Row(
                                                    children: <Widget>[
                                                      Expanded(
                                                        child: TextField(
                                                          controller:
                                                              _roomNameController,
                                                          decoration:
                                                              const InputDecoration(
                                                            border: InputBorder
                                                                .none,
                                                            hintText:
                                                                'Room name',
                                                          ),
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodyLarge,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 8,
                                            ),
                                            Visibility(
                                              visible: _heightAnimation.value >=
                                                  3 * 40.0 + 3 * 8,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  color:
                                                      const Color(0xFFF5F5F5),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 15,
                                                ),
                                                height: 40,
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Row(
                                                    children: <Widget>[
                                                      Expanded(
                                                        child: TextField(
                                                          controller:
                                                              _roomTopicController,
                                                          decoration:
                                                              const InputDecoration(
                                                            border: InputBorder
                                                                .none,
                                                            hintText:
                                                                'Room topic',
                                                          ),
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodyLarge,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 8,
                                            ),
                                            SizedBox(
                                              width: double.infinity,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    isPublic = !isPublic;
                                                  });
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      15,
                                                    ),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 2),
                                                  height: 40,
                                                  child: Row(
                                                    children: <Widget>[
                                                      Checkbox(
                                                        value: isPublic,
                                                        onChanged:
                                                            (bool? value) {
                                                          setState(() {
                                                            isPublic =
                                                                value ?? true;
                                                          });
                                                        },
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        'Public',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyLarge,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: double.infinity,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    isAnonymous = !isAnonymous;
                                                  });
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      15,
                                                    ),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 2),
                                                  height: 40,
                                                  child: Row(
                                                    children: <Widget>[
                                                      Checkbox(
                                                        value: isAnonymous,
                                                        onChanged:
                                                            (bool? value) {
                                                          setState(() {
                                                            isAnonymous =
                                                                value ?? true;
                                                          });
                                                        },
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        'Accessible to anonymous',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyLarge,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  MultiSelectDialogField<Location>(
                                    items: _locationsList
                                        .map(
                                          (loc) => MultiSelectItem<Location>(
                                            loc,
                                            loc.accountName,
                                          ),
                                        )
                                        .toList(),
                                    initialValue: _selectedLocations,
                                    searchable: true,
                                    title: const Text('Invite friends'),
                                    buttonText: Text(
                                      _isRoomCreation
                                          ? 'Invite friends'
                                          : 'Search',
                                    ),
                                    listType: MultiSelectListType.CHIP,
                                    onConfirm: (values) {
                                      setState(() {
                                        _selectedLocations =
                                            List<Location>.from(values);
                                      });
                                    },
                                    chipDisplay: MultiSelectChipDisplay(
                                      onTap: (value) {
                                        setState(() {
                                          _selectedLocations.remove(value);
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      height: appBarHeight,
                      child: AnimatedBuilder(
                        animation: _doneButtonController,
                        builder: (BuildContext context, Widget? child) {
                          return IconButton(
                            icon: const Icon(
                              Icons.done,
                              size: 25,
                            ),
                            color: _doneButtonColor.value ?? Colors.grey,
                            onPressed: _createChat,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // ***********  Start of Discover public chats button ***********
              AnimatedBuilder(
                animation: _animationController,
                builder: (BuildContext context, Widget? child) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushNamed('/discover_chats');
                    },
                    child: Container(
                      padding: const EdgeInsets.only(
                        left: 8,
                        right: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                      ),
//                      height: _buttonHeightAnimation.value,
                      child: FadeTransition(
                        opacity: _buttonFadeAnimation,
                        child: Row(
                          children: <Widget>[
                            SizedBox(
                              height: _buttonHeightAnimation.value,
                              width: personDelegateHeight,
                              child: Center(
                                child: Icon(
                                  Icons.language,
                                  color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color ??
                                      Colors.black,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  'Discover public chats',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              // *********** Start of Create new room +
              //friends signed list button ***********
              Expanded(
                child: Stack(
                  children: <Widget>[
                    ListView.builder(
                      padding:
                          const EdgeInsets.only(left: 8, right: 16, bottom: 8),
//                            itemCount: friendsSignedIdsList.length + 1,
                      itemCount: (_suggestionsList == null)
                          ? 1
                          : _suggestionsList.length + 1,
                      itemBuilder: (BuildContext context, int index) {
                        if (index == 0) {
                          return AnimatedBuilder(
                            animation: _animationController,
                            builder: (BuildContext context, Widget? child) {
                              return GestureDetector(
                                onTap: () {
                                  _animationController.forward();
                                  setState(() {
                                    _isRoomCreation = true;
                                  });
                                },
                                child: Container(
                                  color: Colors.white,
                                  height: _buttonHeightAnimation.value,
                                  child: FadeTransition(
                                    opacity: _buttonFadeAnimation,
                                    child: Row(
                                      children: <Widget>[
                                        SizedBox(
                                          height: _buttonHeightAnimation.value,
                                          width: personDelegateHeight,
                                          child: Center(
                                            child: Icon(
                                              Icons.add,
                                              color: Theme.of(context)
                                                      .textTheme
                                                      .bodyLarge
                                                      ?.color ??
                                                  Colors.black,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: Text(
                                              'Create new room',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }
                        index -= 1;
                        // Todo: DRY
                        return PersonDelegate(
                          data: PersonDelegateData.identityData(
                            _suggestionsList[index],
                            context,
                          ),
                          onPressed: () async {
                            final curr =
                                Provider.of<Identities>(context, listen: false)
                                    .currentIdentity;
                            if (curr == null) return;
                            await Navigator.pushNamed(
                              context,
                              '/room',
                              arguments: {
                                'isRoom': false,
                                'chatData': Provider.of<RoomChatLobby>(
                                  context,
                                  listen: false,
                                ).getChat(curr, _suggestionsList[index]),
                              },
                            );
                          },
                        );
                      },
                    ),
                    Visibility(
                      visible: _friendsList.isEmpty,
                      child: Center(
                        child: SingleChildScrollView(
                          child: SizedBox(
                            width: 200,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Image.asset(
                                  'assets/icons8/list-is-empty-3.png',
                                ),
                                const SizedBox(
                                  height: 20,
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 5),
                                  child: Text(
                                    'Looks like an empty space',
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 5),
                                  child: Text(
                                    'You can add friends in the menu',
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

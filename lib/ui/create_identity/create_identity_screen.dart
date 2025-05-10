import 'package:flutter/material.dart';
import 'package:retroshare/ui/create_identity/generic_identity_tab.dart';

class CreateIdentityScreen extends StatefulWidget {
  const CreateIdentityScreen({super.key, this.isFirstId = false});
  final bool isFirstId;

  @override
  CreateIdentityScreenState createState() => CreateIdentityScreenState();
}

class CreateIdentityScreenState extends State<CreateIdentityScreen>
    with SingleTickerProviderStateMixin {
  late final Animation<Color?> _leftTabIconColor;
  late final Animation<Color?> _rightTabIconColor;
  late final TabController _tabController;
  static const double _appBarHeight = kToolbarHeight;
  static const double _tabVerticalPadding = 20;
  static const double _tabBottomOffset = (_appBarHeight - 40) / 2;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(vsync: this, length: widget.isFirstId ? 1 : 2);
    _leftTabIconColor =
        ColorTween(begin: const Color(0xFFF5F5F5), end: Colors.white)
            .animate(_tabController.animation!);
    _rightTabIconColor =
        ColorTween(begin: Colors.white, end: const Color(0xFFF5F5F5))
            .animate(_tabController.animation!);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Identity'),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            SizedBox(
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: _tabBottomOffset,
                  top: _tabVerticalPadding,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    AnimatedTabIndicator(
                      animation: _leftTabIconColor,
                      label: 'Signed Identity',
                      onTap: () => _tabController.animateTo(0),
                      appBarHeight: _appBarHeight,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    if (!widget.isFirstId)
                      AnimatedTabIndicator(
                        animation: _rightTabIconColor,
                        label: 'Pseudo Identity',
                        onTap: () => _tabController.animateTo(1),
                        appBarHeight: _appBarHeight,
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  GenericIdentityTab(
                    isFirstId: widget.isFirstId,
                    isSignedIdentity: true,
                    buttonText: 'Create Identity',
                  ),
                  if (!widget.isFirstId)
                    GenericIdentityTab(
                      isFirstId: widget.isFirstId,
                      isSignedIdentity: false,
                      buttonText: 'Create Pseudo Identity',
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedTabIndicator extends StatelessWidget {
  const AnimatedTabIndicator({
    super.key,
    required this.animation,
    required this.label,
    required this.onTap,
    required this.appBarHeight,
  });

  final Animation<Color?> animation;
  final String label;
  final VoidCallback onTap;
  final double appBarHeight;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 2 * appBarHeight,
            decoration: BoxDecoration(
              color: animation.value ?? Colors.grey[200],
              borderRadius: BorderRadius.circular(appBarHeight / 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

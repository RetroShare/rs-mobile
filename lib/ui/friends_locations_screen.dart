import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/person_delegate.dart';
import 'package:retroshare/common/shimmer.dart';
import 'package:retroshare/provider/friend_location.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

enum LocationSortOption { name, status }

class FriendsLocationsScreen extends StatefulWidget {
  const FriendsLocationsScreen({super.key});

  @override
  FriendsLocationsScreenState createState() => FriendsLocationsScreenState();
}

class FriendsLocationsScreenState extends State<FriendsLocationsScreen> {
  LocationSortOption _sortOption = LocationSortOption.status;

  @override
  void initState() {
    super.initState();
    if (mounted) _getFriendsAccounts();
  }

  Future<void> _getFriendsAccounts() async {
    await Provider.of<FriendLocations>(context, listen: false)
        .fetchfriendLocation();
  }

  List<Location> _sortedLocations(List<Location> locations) {
    final sorted = List<Location>.from(locations);
    if (_sortOption == LocationSortOption.name) {
      sorted.sort((a, b) => a.accountName
          .toLowerCase()
          .compareTo(b.accountName.toLowerCase()),);
    } else if (_sortOption == LocationSortOption.status) {
      sorted.sort((a, b) {
        // Online first, then away, busy, inactive, offline last
        int getWeight(Location loc) {
          if (loc.isOnline) {
            switch (loc.status) {
              case 3:
                return 0; // Online
              case 1:
                return 1; // Away
              case 2:
                return 2; // Busy
              case 4:
                return 3; // Inactive
              default:
                return 0; // Connected but unknown status → treat as online
            }
          }
          return 4; // Offline
        }

        final weightA = getWeight(a);
        final weightB = getWeight(b);
        if (weightA != weightB) return weightA.compareTo(weightB);
        return a.accountName
            .toLowerCase()
            .compareTo(b.accountName.toLowerCase());
      });
    }
    return sorted;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shadowColor: Colors.transparent,
        title: Text(
          'Friend Location',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14.5,
          ),
        ),
        leading: BackButton(
          color: Theme.of(context).colorScheme.onSurface,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          PopupMenuButton<LocationSortOption>(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onSelected: (LocationSortOption result) {
              setState(() {
                _sortOption = result;
              });
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<LocationSortOption>>[
              PopupMenuItem<LocationSortOption>(
                value: LocationSortOption.name,
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha,
                      size: 20,
                      color: _sortOption == LocationSortOption.name
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Sort by name',
                      style: TextStyle(
                        fontWeight: _sortOption == LocationSortOption.name
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<LocationSortOption>(
                value: LocationSortOption.status,
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 20,
                      color: _sortOption == LocationSortOption.status
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Sort by status',
                      style: TextStyle(
                        fontWeight: _sortOption == LocationSortOption.status
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: _getFriendsAccounts(),
          builder: (context, snapshot) {
            return snapshot.connectionState == ConnectionState.done
                ? Consumer<FriendLocations>(
                    builder: (ctx, idsTuple, _) {
                      if (idsTuple.friendlist.isEmpty) {
                        return Center(
                          child: SingleChildScrollView(
                            child: SizedBox(
                              width: 250,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Image.asset(
                                    'assets/icons8/pluto-children-parent-relationships-petting-animal.png',
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'woof woof',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
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
                        );
                      }

                      final sorted =
                          _sortedLocations(idsTuple.friendlist);

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: sorted.length,
                        itemBuilder: (BuildContext context, int index) {
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: PersonDelegate(
                              data: PersonDelegateData.locationData(
                                sorted[index],
                              ),
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/friend_location_detail',
                                  arguments: {
                                    'location': sorted[index],
                                  },
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  )
                : friendLocationShimmer();
          },
        ),
      ),
    );
  }
}

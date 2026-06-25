import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/drawer.dart';
import 'package:retroshare/common/identicon.dart';
import 'package:retroshare/provider/auth.dart';
import 'package:retroshare/provider/identity.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.curr});

  final Identity curr;

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final identitiesProvider = Provider.of<Identities>(context, listen: false);
    final isOwnIdentity = identitiesProvider.ownIdentity.any((id) => id.mId == widget.curr.mId);
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: appBar(isOwnIdentity ? 'My Identity' : 'Identity Details', context),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 10),
            Center(
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: widget.curr.avatar != null && widget.curr.avatar!.isNotEmpty
                      ? Image.memory(
                          base64.decode(widget.curr.avatar!),
                          fit: BoxFit.cover,
                        )
                      : Identicon(
                          id: widget.curr.mId,
                          size: 80,
                          borderRadius: 15,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _infoTile(context, 'Name', widget.curr.name ?? 'Unknown', Icons.person),
                  _infoTile(context, 'Identity ID (mId)', widget.curr.mId, Icons.fingerprint),
                  if (widget.curr.pgpId != null && widget.curr.pgpId != '0000000000000000')
                    _infoTile(context, 'PGP ID', widget.curr.pgpId!, Icons.security),
                  _infoTile(
                    context, 
                    'Type', 
                    widget.curr.signed ? 'Signed Identity' : 'Pseudonymous Identity', 
                    widget.curr.signed ? Icons.verified : Icons.visibility_off
                  ),
                  const SizedBox(height: 15),
                  if (isOwnIdentity)
                    _buildGradientButton(
                      context,
                      'Edit Identity',
                      Icons.edit,
                      () => Navigator.of(context).pushNamed(
                        '/updateIdentity',
                        arguments: {'id': widget.curr},
                      ),
                    )
                  else ...[
                    _buildGradientButton(
                      context,
                      widget.curr.isContact ? 'Remove from Contacts' : 'Add to Contacts',
                      widget.curr.isContact ? Icons.person_remove : Icons.person_add,
                      () async {
                        await Provider.of<RoomChatLobby>(context, listen: false)
                            .toggleContacts(widget.curr.mId, !widget.curr.isContact);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildGradientButton(
                      context,
                      'Open Chat',
                      Icons.chat,
                      () async {
                        final curr = identitiesProvider.currentIdentity;
                        if (curr == null) return;
                        final chatData = await Provider.of<RoomChatLobby>(context, listen: false)
                            .getChat(curr, widget.curr);
                        if (!context.mounted) return;
                        Navigator.pushNamed(
                          context,
                          '/room',
                          arguments: {
                            'isRoom': false,
                            'chatData': chatData,
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(BuildContext context, String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontFamily: 'Oxygen',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              // Todo: Implement copy to clipboard
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton(BuildContext context, String text, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 45,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            colors: [Color(0xFF00FFFF), Color(0xFF29ABE2)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF29ABE2).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Vollkorn',
              ),
            ),
          ],
        ),
      ),
    );
  }
}


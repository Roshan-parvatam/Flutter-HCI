import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageTile extends StatefulWidget {
  final String message;
  final bool sentByMe;
  final String time;
  final String senderId;
  final String messageID;
  final String groupID;
  final String fileUrl;
  final String messageType;

  const MessageTile({
    super.key,
    required this.message,
    required this.sentByMe,
    required this.time,
    required this.senderId,
    required this.messageID,
    required this.groupID,
    this.fileUrl = '',
    required this.messageType,
  });

  @override
  State<MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends State<MessageTile> {
  String profileImageUrl = '';
  String senderName = ''; // Added for sender name
  bool isEdited = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileImageUrl();
    _fetchSenderName(); // Fetch sender name
    _checkIfEdited();
  }

  Future<void> _fetchProfileImageUrl() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.senderId)
          .collection('client')
          .doc('details')
          .get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data();
        if (userData != null) {
          final imageUrl = userData['imageURL'] as String?;
          setState(() {
            profileImageUrl = imageUrl ?? '';
          });
        }
      }
    } catch (error) {
      print('Error fetching profile data: $error');
    }
  }

  Future<void> _fetchSenderName() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.senderId).collection('client').doc('details')
          .get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data();
        if (userData != null) {
          final name = userData['displayName'] as String?;
          setState(() {
            senderName = name ?? 'Unknown';
          });
        }
      }
    } catch (error) {
      print('Error fetching sender name: $error');
    }
  }

  Future<void> _checkIfEdited() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection("groups")
          .doc(widget.groupID)
          .collection("messages")
          .doc(widget.messageID)
          .get();

      if (docSnapshot.exists) {
        final messageData = docSnapshot.data();
        if (messageData != null) {
          final edited = messageData['edited'] as bool? ?? false;
          setState(() {
            isEdited = edited;
          });
        }
      }
    } catch (error) {
      print('Error checking if message is edited: $error');
    }
  }

  Widget _buildMessageContent() {
    if (widget.messageType == "image") {
      return GestureDetector(
        onTap: () => _showImagePreview(context, widget.fileUrl),
        child: widget.fileUrl.isNotEmpty
            ? Image.network(
                widget.fileUrl,
                fit: BoxFit.cover,
                height: 200,
                width: 200,
              )
            : const Text(
                "Image not available",
                style: TextStyle(color: Colors.white),
              ),
      );
    } else if (widget.messageType == "file") {
      return widget.fileUrl.isNotEmpty
          ? GestureDetector(
              onTap: () => _launchURL(widget.fileUrl),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.attach_file, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    "Download File",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          : const Text(
              "File not available",
              style: TextStyle(color: Colors.white),
            );
    } else {
      return Text(
        widget.message,
        textAlign: TextAlign.start,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final textScaleFactor = mediaQuery.textScaleFactor;

    return GestureDetector(
      onLongPress: widget.sentByMe ? () => _showOptions(context) : null,
      child: Container(
        padding: EdgeInsets.only(
          top: 4*textScaleFactor,
          bottom: 4*textScaleFactor,
          left: widget.sentByMe ? 0*textScaleFactor : 24*textScaleFactor,
          right: widget.sentByMe ? 24 *textScaleFactor: 0*textScaleFactor
        ),
        alignment: widget.sentByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.sentByMe)
              Column(
                children: [
                  SizedBox(height: 40,),
                  CircleAvatar(
                    backgroundImage: profileImageUrl.isNotEmpty
                        ? NetworkImage(profileImageUrl)
                        : null,
                    backgroundColor: Colors.grey[700],
                    child: profileImageUrl.isEmpty
                        ? const Icon(Icons.account_circle, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                margin: widget.sentByMe
                    ? EdgeInsets.only(left: 200 * textScaleFactor)
                    : EdgeInsets.only(right: 200* textScaleFactor),
                padding: EdgeInsets.symmetric(
                  vertical: 8*textScaleFactor,
                  horizontal: 10*textScaleFactor,
                ),
                decoration: BoxDecoration(
                  borderRadius: widget.sentByMe
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(15),
                          topRight: Radius.circular(15),
                          bottomLeft: Radius.circular(15),
                        )
                      : const BorderRadius.only(
                          topLeft: Radius.circular(15),
                          topRight: Radius.circular(15),
                          bottomRight: Radius.circular(15),
                        ),
                  color: widget.sentByMe
                      ? Colors.blueAccent
                      : Colors.grey[700],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderName.toUpperCase(),
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: 12 * textScaleFactor,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildMessageContent(),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.time,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11 * textScaleFactor,
                            ),
                          ),
                          if (isEdited)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(
                                'Edited',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11 * textScaleFactor,
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
          ],
        ),
      ),
    );
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Image.network(imageUrl),
        );
      },
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Message'),
              onTap: () {
                Navigator.of(context).pop();
                _editMessage(context, widget.messageID);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Message'),
              onTap: () {
                Navigator.of(context).pop();
                _deleteMessage(context, widget.messageID);
              },
            ),
          ],
        );
      },
    );
  }

  void _editMessage(BuildContext context, String messageID) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController messageController =
            TextEditingController(text: widget.message);

        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextField(
            controller: messageController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Edit your message...',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                final updatedMessage = messageController.text;
                Navigator.of(context).pop();
                if (updatedMessage.isNotEmpty) {
                  FirebaseFirestore.instance
                      .collection("groups")
                      .doc(widget.groupID)
                      .collection("messages")
                      .doc(messageID)
                      .update({
                    "message": updatedMessage,
                    "edited": true,
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteMessage(BuildContext context, String messageID) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                FirebaseFirestore.instance
                    .collection("groups")
                    .doc(widget.groupID)
                    .collection("messages")
                    .doc(messageID)
                    .delete();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }
}

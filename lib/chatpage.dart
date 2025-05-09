import 'package:collab_prog/message_tile.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

final user = FirebaseAuth.instance.currentUser;

class ChatPage extends StatefulWidget {
  final String userName;
  final String groupID;
  final String groupName;

  const ChatPage({
    super.key,
    required this.groupID,
    required this.groupName,
    required this.userName,
  });

  @override
  State<ChatPage> createState() {
    return _ChatPageState();
  }
}

class _ChatPageState extends State<ChatPage> {
  TextEditingController messageController = TextEditingController();
  String adminName = "";
  Stream<QuerySnapshot>? chats;
  final groupsCollection = FirebaseFirestore.instance.collection('groups');
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    getChatsAdmin();
  }

  Stream<QuerySnapshot> getChats(String groupId) {
    return groupsCollection
        .doc(groupId)
        .collection("messages")
        .orderBy("time")
        .snapshots();
  }

  Future<String> getAdmin(String groupId) async {
    DocumentReference d = groupsCollection.doc(groupId);
    DocumentSnapshot documentSnapshot = await d.get();
    return documentSnapshot['admin'];
  }

  void getChatsAdmin() {
    setState(() {
      chats = getChats(widget.groupID);
    });
    getAdmin(widget.groupID).then((val) {
      String getAdminName(String res) {
        return res.substring(res.indexOf("_") + 1);
      }

      setState(() {
        adminName = getAdminName(val);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final textScaleFactor = mediaQuery.textScaleFactor;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.blue.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: chatMessages(),
                  ),
                  Container(
                    alignment: Alignment.bottomCenter,
                    width: MediaQuery.of(context).size.width,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      width: MediaQuery.of(context).size.width,
                      color: Colors.grey[700],
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.attach_file, color: Colors.white),
                            onPressed: _pickAndSendFile,
                          ),
                          IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.white),
                            onPressed: () {
                              _pickAndSendImage(ImageSource.camera);
                            },
                          ),
                          // Select from Gallery Icon
                          IconButton(
                            icon: const Icon(Icons.photo_library, color: Colors.white),
                            onPressed: () {
                              _pickAndSendImage(ImageSource.gallery);
                            },
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: messageController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "Send a message",
                                hintStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16 * textScaleFactor),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: sendMessage,
                            child: Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.blue.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
                              child: const Center(
                                child: Icon(
                                  Icons.send,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_isUploading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget chatMessages() {
    return StreamBuilder<QuerySnapshot>(
      stream: chats,
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text('No messages'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var messageData = snapshot.data!.docs[index];
            String formattedTime = DateFormat('hh:mm a').format(
              DateTime.fromMicrosecondsSinceEpoch(
                messageData['time'],
              ),
            );

            return MessageTile(
              message: messageData['message'] ?? '',
             
              sentByMe: user!.uid == messageData['senderId'],
              time: formattedTime,
              senderId: messageData['senderId'] ?? '',
              messageID: messageData.id,
              groupID: widget.groupID,
              fileUrl: messageData['messageType'] == 'text' ? '' : messageData['fileUrl'] ?? '',
              messageType: messageData['messageType'] ?? 'text',
            );
          },
        );
      },
    );
  }

  void sendMessages(String groupID, Map<String, dynamic> chatMessagesData) {
    final groupCollection = FirebaseFirestore.instance.collection('groups');
    groupCollection
        .doc(groupID)
        .collection("messages")
        .add(chatMessagesData)
        .then((docRef) {
      groupCollection.doc(groupID).update({
        "recentMessage": chatMessagesData["message"],
        "recentMessageSender": chatMessagesData["senderId"],
        "recentMessageTime": chatMessagesData["time"].toString(),
      });
    });
  }

  void sendMessage() {
    if (messageController.text.isNotEmpty) {
      Map<String, dynamic> chatMessagesMap = {
        "message": messageController.text,
        "sender": widget.userName,
        "senderId": user!.uid,
        "time": DateTime.now().microsecondsSinceEpoch,
        "messageType": "text", 
      };
      sendMessages(widget.groupID, chatMessagesMap);

      setState(() {
        messageController.clear();
      });
    }
  }

  Future<void> _pickAndSendFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);
      String fileName = result.files.single.name;

      setState(() {
        _isUploading = true;
      });

      try {
        String downloadURL = await _uploadFile(file, fileName);
        if (downloadURL.isNotEmpty) {
          Map<String, dynamic> fileMessageMap = {
            "message": "File: $fileName",
            "fileUrl": downloadURL,
            "sender": widget.userName,
            "senderId": user!.uid,
            "time": DateTime.now().microsecondsSinceEpoch,
            "messageType": "file", 
          };
          sendMessages(widget.groupID, fileMessageMap);
        }
      } catch (e) {
        print('Error uploading file: $e');
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      File file = File(pickedFile.path);
      File resizedFile = await _resizeImage(file);
      String fileName = pickedFile.name;

      setState(() {
        _isUploading = true;
      });

      try {
        String downloadURL = await _uploadFile(resizedFile, fileName);
        if (downloadURL.isNotEmpty) {
          Map<String, dynamic> imageMessageMap = {
            "message": "Image: $fileName",
            "fileUrl": downloadURL,
            "sender": widget.userName,
            "senderId": user!.uid,
            "time": DateTime.now().microsecondsSinceEpoch,
            "messageType": "image", 
          };
          sendMessages(widget.groupID, imageMessageMap);
        }
      } catch (e) {
        print('Error uploading image: $e');
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<File> _resizeImage(File file) async {
    final image = img.decodeImage(file.readAsBytesSync())!;
    final resizedImage = img.copyResize(image, width: 800); 
    final resizedFile = File(file.path)
      ..writeAsBytesSync(img.encodeJpg(resizedImage, quality: 85)); 
    return resizedFile;
  }

  Future<String> _uploadFile(File file, String fileName) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('chat_files').child(widget.groupID).child(fileName);
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadURL = await snapshot.ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print('Error uploading file: $e');
      return '';
    }
  }
}

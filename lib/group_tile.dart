import "package:flutter/material.dart";
import 'tab.dart';

class GroupTile extends StatefulWidget {
  String groupID;
  String groupName;
  String userName;
  GroupTile({super.key,
    
    required this.groupID,
    required this.groupName,
    required this.userName,
    
  });
  @override
  State<GroupTile> createState() {
    return _GroupTileState();
  }
}

class _GroupTileState extends State<GroupTile> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskManagerScreen(
                groupID: widget.groupID,
                groupName: widget.groupName,
                userName: widget.userName),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
        child: ListTile(
          leading: CircleAvatar(
            radius: 30,
            backgroundColor: const Color.fromARGB(255, 234, 134, 123),
            child: Text(
              widget.groupName.substring(0, 1).toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
          title: Text(
            widget.groupName,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black),
          ),
          subtitle: const Text(
            "Welcome to the conversation ",
            style: TextStyle(fontSize: 13, color: Colors.black),
          ),
        ),
      ),
    );
  }
}

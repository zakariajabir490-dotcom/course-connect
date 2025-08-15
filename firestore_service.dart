// lib/services/firestore_service.dart
import 'dart:io';
import 'package:course_connect/user_model.dart';
import 'package:flutter/foundation.dart'; // NEW import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ---------- UPDATED: Unified image upload method for all platforms ----------
  Future<String> uploadImage(String path, dynamic image) async {
    final ref = _storage.ref().child(path);
    final UploadTask uploadTask;

    if (image is File) {
      uploadTask = ref.putFile(image);
    } else if (image is Uint8List) {
      uploadTask = ref.putData(image);
    } else {
      throw Exception('Invalid image type');
    }

    final snapshot = await uploadTask.whenComplete(() {});
    return await snapshot.ref.getDownloadURL();
  }
  // ---------------------------------------------------------------------

  Future<void> addPost(String content, String authorEmail, {String? imageUrl}) async {
    await _firestore.collection('posts').add({
      'content': content,
      'authorEmail': authorEmail,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': 0,
      'imageUrl': imageUrl,
    });
  }

  Future<void> updatePost(String postId, String newContent) async {
    await _firestore.collection('posts').doc(postId).update({
      'content': newContent,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> likePost(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'likes': FieldValue.increment(1),
    });
  }

  Future<void> deletePost(String postId) async {
    await _firestore.collection('posts').doc(postId).delete();
  }

  Future<void> addComment(String postId, String content, String authorEmail) async {
    await _firestore.collection('posts').doc(postId).collection('comments').add({
      'content': content,
      'authorEmail': authorEmail,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getComments(String postId) {
    return _firestore.collection('posts').doc(postId).collection('comments').orderBy('timestamp', descending: true).snapshots();
  }

  Stream<QuerySnapshot> getPosts() {
    return _firestore.collection('posts').orderBy('timestamp', descending: true).snapshots();
  }

  Future<void> createUserProfile(String uid, String name, String email) async {
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'email': email,
    });
  }
  
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final docSnapshot = await _firestore.collection('users').doc(uid).get();
    if (docSnapshot.exists) {
      return UserModel.fromMap(docSnapshot.data()!, uid);
    }
    return null;
  }
}
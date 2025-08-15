// main.dart
import 'dart:io';
import 'package:course_connect/firestore_service.dart';
import 'package:course_connect/user_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:firebase_storage/firebase_storage.dart';


import 'signup.dart';
import 'login.dart';
import 'firebase_options.dart';
// ------------------- main function and App Setup -------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        Provider<FirestoreService>(create: (context) => FirestoreService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Course Connect',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthChecker()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Loading...',
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        if (!userProvider.isAuthenticated) {
          return const LoginPage();
        }
        return const HomePage();
      },
    );
  }
}

// ------------------- User Provider (State Management with Firebase Auth) -------------------
class UserProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  User? _user;
  UserModel? _userModel;

  UserProvider() {
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        _userModel = await _firestoreService.getUserProfile(user.uid);
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isAuthenticated => _user != null;

  Future<String?> signUp(String email, String password, String name) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (userCredential.user != null) {
        await _firestoreService.createUserProfile(userCredential.user!.uid, name, email);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> refreshUserProfile() async {
    if (_user != null) {
      _userModel = await _firestoreService.getUserProfile(_user!.uid);
      notifyListeners();
    }
  }
}

// ------------------- Authenticated Pages -------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _postController = TextEditingController();
  File? _selectedImage;
  Uint8List? _selectedImageBytes;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImage = null;
        });
      } else {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _selectedImageBytes = null;
        });
      }
    }
  }

  void _addPost(BuildContext context) async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final user = Provider.of<UserProvider>(context, listen: false).user;
    
    if ((_postController.text.isNotEmpty || _selectedImage != null || _selectedImageBytes != null) && user != null) {
      String? imageUrl;
      
      try {
        if (_selectedImage != null) {
          imageUrl = await firestoreService.uploadImage(
            'user_posts/${user.uid}/${DateTime.now().toIso8601String()}.png',
            _selectedImage!,
          );
        } else if (_selectedImageBytes != null) {
          imageUrl = await firestoreService.uploadImage(
            'user_posts/${user.uid}/${DateTime.now().toIso8601String()}.png',
            _selectedImageBytes!,
          );
        }

        await firestoreService.addPost(_postController.text, user.email!, imageUrl: imageUrl);

        _postController.clear();
        setState(() {
          _selectedImage = null;
          _selectedImageBytes = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post added successfully!')),
        );
      } catch (e) {
        print('Error adding post: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add post: $e')),
        );
      }
    }
  }

  void _logout(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    final userModel = userProvider.userModel;
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ProfilePage()));
            },
            tooltip: 'Profile',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Welcome, ${userModel?.name ?? user?.email ?? 'User'}!',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _postController,
                        decoration: const InputDecoration(
                          labelText: "What's on your mind?",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.image),
                      onPressed: _pickImage,
                      tooltip: 'Select an image',
                    ),
                  ],
                ),
                if (_selectedImage != null || _selectedImageBytes != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: kIsWeb
                        ? Image.memory(_selectedImageBytes!, height: 150)
                        : Image.file(_selectedImage!, height: 150),
                  ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _addPost(context),
                  child: const Text('Add Post'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestoreService.getPosts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No posts yet!'));
                }
                
                final posts = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final data = post.data() as Map<String, dynamic>;
                    final content = data['content'] ?? 'No content';
                    final authorEmail = data['authorEmail'] ?? 'Unknown';
                    final timestamp = data['timestamp'] as Timestamp?;
                    final postId = post.id;
                    final likes = data['likes'] ?? 0;
                    final imageUrl = data['imageUrl'] as String?;
                    
                    final isCurrentUserPost = user?.email == authorEmail;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageUrl != null && imageUrl.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Image.network(imageUrl),
                            ),
                          ListTile(
                            title: Text(content),
                            subtitle: Text('By $authorEmail${timestamp != null ? ' at ${timestamp.toDate().toString().split('.')[0]}' : ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCurrentUserPost)
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => PostEditPage(
                                            postId: postId,
                                            initialContent: content,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => CommentsPage(postId: postId),
                                      ),
                                    );
                                  },
                                ),
                                Text('$likes'),
                                IconButton(
                                  icon: const Icon(Icons.favorite_border),
                                  onPressed: () {
                                    firestoreService.likePost(postId);
                                  },
                                ),
                                if (isCurrentUserPost)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final bool confirmDelete = await showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Confirm Deletion'),
                                          content: const Text('Are you sure you want to delete this post?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      ) ?? false;
                                      
                                      if (confirmDelete) {
                                        await firestoreService.deletePost(postId);
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    final userModel = userProvider.userModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        actions: [
          if (userModel != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProfileEditPage(userModel: userModel),
                  ),
                );
              },
              tooltip: 'Edit Profile',
            ),
        ],
      ),
      body: Center(
        child: userModel == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.account_circle,
                      size: 100,
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      userModel.name,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user?.email ?? 'Loading Email...',
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }
}

class ProfileEditPage extends StatefulWidget {
  final UserModel userModel;
  const ProfileEditPage({super.key, required this.userModel});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userModel.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      final updatedData = {
        'name': _nameController.text.trim(),
      };

      try {
        await firestoreService.updateUserProfile(widget.userModel.uid, updatedData);
        await userProvider.refreshUserProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveProfile,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommentsPage extends StatefulWidget {
  final String postId;
  const CommentsPage({super.key, required this.postId});

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestoreService.getComments(widget.postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No comments yet! Be the first.'));
                }

                final comments = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final data = comment.data() as Map<String, dynamic>;
                    final content = data['content'] ?? 'No content';
                    final authorEmail = data['authorEmail'] ?? 'Unknown';
                    final timestamp = data['timestamp'] as Timestamp?;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: ListTile(
                        title: Text(content),
                        subtitle: Text('By $authorEmail${timestamp != null ? ' at ${timestamp.toDate().toString().split('.')[0]}' : ''}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    if (_commentController.text.isNotEmpty && userProvider.user != null) {
                      await firestoreService.addComment(
                        widget.postId,
                        _commentController.text.trim(),
                        userProvider.user!.email!,
                      );
                      _commentController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PostEditPage extends StatefulWidget {
  final String postId;
  final String initialContent;
  const PostEditPage({super.key, required this.postId, required this.initialContent});

  @override
  State<PostEditPage> createState() => _PostEditPageState();
}

class _PostEditPageState extends State<PostEditPage> {
  late TextEditingController _contentController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _savePost() async {
    if (_formKey.currentState!.validate()) {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      try {
        await firestoreService.updatePost(widget.postId, _contentController.text.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated successfully!')),
        );
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update post: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: "Edit your post",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Post cannot be empty';
                  }
                  return null;
                },
                maxLines: null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _savePost,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
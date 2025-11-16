# Firebase Chat Integration Guide

This guide will help you integrate Firebase Firestore for real-time messaging in the Chat Screen.

## Prerequisites

- Firebase project already set up (you're already using Firebase Auth)
- Flutter project with Firebase Core configured
- Access to Firebase Console

## Step 1: Add Firestore Dependency

Add the following dependency to your `pubspec.yaml`:

```yaml
dependencies:
  cloud_firestore: ^5.4.0
```

Then run:
```bash
flutter pub get
```

## Step 2: Enable Firestore in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Firestore Database** in the left sidebar
4. Click **Create database**
5. Choose **Start in test mode** (for development)
6. Select your preferred region
7. Click **Enable**

## Step 3: Database Structure

The chat system uses the following Firestore structure:

```
chats/
  └── {userId}_caregiver/
      └── messages/
          └── {messageId}
              ├── text: String
              ├── senderId: String
              ├── senderName: String
              ├── timestamp: Timestamp
              └── read: Boolean
```

### Example Document:
```json
{
  "text": "Hello, I need assistance",
  "senderId": "user123",
  "senderName": "user@example.com",
  "timestamp": "2024-01-15T10:30:00Z",
  "read": false
}
```

## Step 4: Configure Security Rules

In Firebase Console, go to **Firestore Database** > **Rules** and add:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Chat messages
    match /chats/{chatId} {
      match /messages/{messageId} {
        // Allow read/write if user is authenticated and is part of the chat
        allow read, write: if request.auth != null && 
          (request.auth.uid == resource.data.senderId || 
           chatId.contains(request.auth.uid));
      }
    }
  }
}
```

Click **Publish** to save the rules.

## Step 5: Update Chat Screen Code

In `lib/pages/chat_screen/chat_screen.dart`:

1. **Uncomment the Firestore import:**
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
```

2. **Uncomment the Firestore instance:**
```dart
final FirebaseFirestore _firestore = FirebaseFirestore.instance;
```

3. **Replace the `_buildMessageList()` method** with the StreamBuilder implementation (already provided in comments)

4. **Replace the `_sendMessage()` method** with the Firestore implementation (already provided in comments)

## Step 6: Test the Integration

1. Run your app
2. Navigate to the SOS Alert screen
3. Click "Caregiver Responded" button
4. The chat screen should open
5. Send a test message
6. Check Firebase Console > Firestore Database to see the message appear

## Step 7: Advanced Features (Optional)

### Read Receipts

To mark messages as read when viewed:

```dart
// In _buildMessageList(), after displaying messages:
if (!isSent && !messageData['read']) {
  _firestore
      .collection('chats')
      .doc('${_currentUser?.uid}_caregiver')
      .collection('messages')
      .doc(messages[index].id)
      .update({'read': true});
}
```

### Typing Indicators

Add a typing indicator:

```dart
// When user starts typing
_firestore
    .collection('chats')
    .doc('${_currentUser?.uid}_caregiver')
    .set({'typing': true}, SetOptions(merge: true));

// When user stops typing
_firestore
    .collection('chats')
    .doc('${_currentUser?.uid}_caregiver')
    .set({'typing': false}, SetOptions(merge: true));
```

### Message Status (Sent/Delivered/Read)

Add status tracking to messages:

```dart
// When sending
await _firestore
    .collection('chats')
    .doc(chatId)
    .collection('messages')
    .add({
  // ... existing fields
  'status': 'sent', // or 'delivered', 'read'
});
```

## Troubleshooting

### Messages not appearing
- Check Firestore security rules
- Verify user is authenticated
- Check Firebase Console for errors
- Ensure Firestore is enabled in Firebase Console

### Permission denied errors
- Review security rules
- Ensure user is logged in
- Check chatId format matches security rules

### Real-time updates not working
- Verify StreamBuilder is properly implemented
- Check network connectivity
- Ensure Firestore is enabled

## Production Considerations

1. **Update Security Rules**: Replace test mode rules with production rules
2. **Indexes**: Create composite indexes for complex queries
3. **Offline Support**: Firestore automatically caches data offline
4. **Message Limits**: Consider pagination for large chat histories
5. **File Attachments**: Use Firebase Storage for images/files

## Example Production Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /chats/{chatId} {
      // Allow users to read their own chats
      allow read: if request.auth != null && 
        chatId.contains(request.auth.uid);
      
      match /messages/{messageId} {
        // Allow users to send messages in their chats
        allow create: if request.auth != null && 
          request.resource.data.senderId == request.auth.uid &&
          chatId.contains(request.auth.uid);
        
        // Allow users to read messages in their chats
        allow read: if request.auth != null && 
          chatId.contains(request.auth.uid);
        
        // Allow users to update their own messages (for read receipts)
        allow update: if request.auth != null && 
          chatId.contains(request.auth.uid) &&
          request.resource.data.diff(resource.data).affectedKeys()
            .hasOnly(['read']);
      }
    }
  }
}
```

## Additional Resources

- [Firestore Documentation](https://firebase.google.com/docs/firestore)
- [FlutterFire Documentation](https://firebase.flutter.dev/docs/firestore/overview)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)


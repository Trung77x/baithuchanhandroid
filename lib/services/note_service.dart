import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_model.dart';

class NoteService {
  static const String _notesKey = 'notes';
  SharedPreferences? _prefs;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get the Firestore collection reference for current user's notes
  CollectionReference<Map<String, dynamic>>? get _notesCollection {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid).collection('notes');
  }

  /// Ensure preferences are initialized
  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get all notes (from Firestore if logged in, otherwise local)
  Future<List<Note>> getNotes() async {
    try {
      final collection = _notesCollection;
      if (collection != null) {
        final snapshot = await collection
            .orderBy('updatedAt', descending: true)
            .get();
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Note.fromJson(data);
        }).toList();
      }
      // Fallback to local
      return _getLocalNotes();
    } catch (e) {
      debugPrint('Error getting notes from Firestore: $e');
      return _getLocalNotes();
    }
  }

  Future<List<Note>> _getLocalNotes() async {
    await _ensurePrefs();
    final String? notesJson = _prefs!.getString(_notesKey);
    if (notesJson == null) return [];
    return decodeNotes(notesJson);
  }

  /// Save a single note (to Firestore + local)
  Future<void> saveNote(Note note) async {
    try {
      // Save to Firestore
      final collection = _notesCollection;
      if (collection != null) {
        await collection.doc(note.id).set(note.toJson());
      }
      // Also save locally as cache
      await _saveNoteLocal(note);
    } catch (e) {
      debugPrint('Error saving note to Firestore: $e');
      // Fallback: save locally
      await _saveNoteLocal(note);
    }
  }

  Future<void> _saveNoteLocal(Note note) async {
    await _ensurePrefs();
    final List<Note> notes = await _getLocalNotes();
    final int indexOfExisting = notes.indexWhere((n) => n.id == note.id);
    if (indexOfExisting != -1) {
      notes[indexOfExisting] = note;
    } else {
      notes.add(note);
    }
    final String notesJson = encodeNotes(notes);
    await _prefs!.setString(_notesKey, notesJson);
  }

  /// Delete a note by ID
  Future<void> deleteNote(String noteId) async {
    try {
      // Delete from Firestore
      final collection = _notesCollection;
      if (collection != null) {
        await collection.doc(noteId).delete();
      }
      // Delete locally
      await _deleteNoteLocal(noteId);
    } catch (e) {
      debugPrint('Error deleting note from Firestore: $e');
      await _deleteNoteLocal(noteId);
    }
  }

  Future<void> _deleteNoteLocal(String noteId) async {
    await _ensurePrefs();
    final List<Note> notes = await _getLocalNotes();
    notes.removeWhere((note) => note.id == noteId);
    final String notesJson = encodeNotes(notes);
    await _prefs!.setString(_notesKey, notesJson);
  }

  /// Get a specific note by ID
  Future<Note?> getNote(String noteId) async {
    try {
      final collection = _notesCollection;
      if (collection != null) {
        final doc = await collection.doc(noteId).get();
        if (doc.exists) {
          final data = doc.data()!;
          data['id'] = doc.id;
          return Note.fromJson(data);
        }
      }
      // Fallback to local
      final notes = await _getLocalNotes();
      final idx = notes.indexWhere((n) => n.id == noteId);
      return idx != -1 ? notes[idx] : null;
    } catch (e) {
      debugPrint('Error getting note: $e');
      return null;
    }
  }

  /// Search notes by title
  Future<List<Note>> searchNotes(String query) async {
    try {
      final List<Note> notes = await getNotes();
      if (query.isEmpty) return notes;
      return notes
          .where(
            (note) => note.title.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    } catch (e) {
      debugPrint('Error searching notes: $e');
      return [];
    }
  }

  /// Clear all notes (for testing purpose)
  Future<void> clearAllNotes() async {
    try {
      await _ensurePrefs();
      await _prefs!.remove(_notesKey);
    } catch (e) {
      debugPrint('Error clearing notes: $e');
    }
  }
}

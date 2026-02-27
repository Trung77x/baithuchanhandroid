import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_model.dart';

class NoteService {
  static const String _notesKey = 'notes';
  SharedPreferences? _prefs;

  /// Ensure preferences are initialized
  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get all notes
  Future<List<Note>> getNotes() async {
    try {
      await _ensurePrefs();
      final String? notesJson = _prefs!.getString(_notesKey);
      if (notesJson == null) {
        return [];
      }
      return decodeNotes(notesJson);
    } catch (e) {
      debugPrint('Error getting notes: $e');
      return [];
    }
  }

  /// Save a single note
  Future<void> saveNote(Note note) async {
    try {
      await _ensurePrefs();
      final List<Note> notes = await getNotes();

      // Check if note exists, if so update it, else add it
      final int indexOfExisting = notes.indexWhere((n) => n.id == note.id);

      if (indexOfExisting != -1) {
        notes[indexOfExisting] = note;
      } else {
        notes.add(note);
      }

      final String notesJson = encodeNotes(notes);
      await _prefs!.setString(_notesKey, notesJson);
      // Debug: print saved JSON so we can verify persistence
      debugPrint('Saved notes JSON: $notesJson');
    } catch (e) {
      debugPrint('Error saving note: $e');
    }
  }

  /// Delete a note by ID
  Future<void> deleteNote(String noteId) async {
    try {
      await _ensurePrefs();
      final List<Note> notes = await getNotes();
      notes.removeWhere((note) => note.id == noteId);

      final String notesJson = encodeNotes(notes);
      await _prefs!.setString(_notesKey, notesJson);
    } catch (e) {
      debugPrint('Error deleting note: $e');
    }
  }

  /// Get a specific note by ID
  Future<Note?> getNote(String noteId) async {
    try {
      final List<Note> notes = await getNotes();
      final int indexOfNote = notes.indexWhere((n) => n.id == noteId);

      if (indexOfNote != -1) {
        return notes[indexOfNote];
      }
      return null;
    } catch (e) {
      debugPrint('Error getting note: $e');
      return null;
    }
  }

  /// Search notes by title
  Future<List<Note>> searchNotes(String query) async {
    try {
      final List<Note> notes = await getNotes();
      if (query.isEmpty) {
        return notes;
      }

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

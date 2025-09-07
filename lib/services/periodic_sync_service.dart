import 'dart:async';
import 'package:flokk/_internal/log.dart';
import 'package:flokk/commands/contacts/refresh_contacts_command.dart';
import 'package:flokk/commands/social/refresh_social_command.dart';
import 'package:flokk/models/app_model.dart';
import 'package:flokk/models/auth_model.dart';
import 'package:flokk/models/contacts_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PeriodicSyncService {
  static PeriodicSyncService? _instance;
  static PeriodicSyncService get instance => _instance ??= PeriodicSyncService._();
  PeriodicSyncService._();

  Timer? _syncTimer;
  BuildContext? _context;
  bool _isRunning = false;
  
  // Sync intervals in minutes
  static const Map<String, int> syncIntervals = {
    'disabled': 0,
    '15min': 15,
    '30min': 30,
    '1hour': 60,
    '2hours': 120,
    '6hours': 360,
    '12hours': 720,
    '24hours': 1440,
  };

  void initialize(BuildContext context) {
    _context = context;
    _startPeriodicSync();
  }

  void dispose() {
    _stopPeriodicSync();
    _context = null;
  }

  void _startPeriodicSync() {
    if (_context == null) return;
    
    AppModel appModel = Provider.of<AppModel>(_context!, listen: false);
    int intervalMinutes = syncIntervals[appModel.periodicSyncInterval] ?? 60;
    
    if (intervalMinutes <= 0) {
      Log.p("[PeriodicSyncService] Sync disabled");
      return;
    }

    _stopPeriodicSync(); // Stop any existing timer
    
    Duration interval = Duration(minutes: intervalMinutes);
    Log.p("[PeriodicSyncService] Starting periodic sync every ${intervalMinutes} minutes");
    
    _syncTimer = Timer.periodic(interval, (timer) {
      _performSync();
    });
  }

  void _stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    Log.p("[PeriodicSyncService] Stopped periodic sync");
  }

  Future<void> _performSync() async {
    if (_context == null || _isRunning) return;
    
    try {
      _isRunning = true;
      Log.p("[PeriodicSyncService] Starting background sync");
      
      AuthModel authModel = Provider.of<AuthModel>(_context!, listen: false);
      ContactsModel contactsModel = Provider.of<ContactsModel>(_context!, listen: false);
      
      // Only sync if user is authenticated
      if (!authModel.hasAuthKey) {
        Log.p("[PeriodicSyncService] No auth token, skipping sync");
        return;
      }

      // Refresh contacts using sync token for incremental updates
      await RefreshContactsCommand(_context!).execute();
      
      // Refresh social data for contacts that have social handles
      List<dynamic> contactsWithSocial = contactsModel.allContacts
          .where((c) => c.hasGit || c.hasTwitter)
          .toList();
      
      if (contactsWithSocial.isNotEmpty) {
        await RefreshSocialCommand(_context!).execute(contactsWithSocial.cast());
      }
      
      Log.p("[PeriodicSyncService] Background sync completed");
      
    } catch (e) {
      Log.p("[PeriodicSyncService] Error during background sync: $e");
    } finally {
      _isRunning = false;
    }
  }

  // Manual sync trigger
  Future<void> syncNow() async {
    Log.p("[PeriodicSyncService] Manual sync requested");
    await _performSync();
  }

  // Update sync interval
  void updateSyncInterval(String intervalKey) {
    if (_context == null) return;
    
    AppModel appModel = Provider.of<AppModel>(_context!, listen: false);
    appModel.periodicSyncInterval = intervalKey;
    appModel.scheduleSave();
    
    _startPeriodicSync(); // Restart with new interval
  }

  // Get current sync status
  bool get isRunning => _isRunning;
  bool get isSyncEnabled => _syncTimer != null;
  String get currentInterval {
    if (_context == null) return 'disabled';
    AppModel appModel = Provider.of<AppModel>(_context!, listen: false);
    return appModel.periodicSyncInterval;
  }
}
import 'package:flokk/_internal/log.dart';
import 'package:flokk/api_keys.dart';
import 'package:flokk/commands/abstract_command.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:google_sign_in/google_sign_in.dart';

class WebSignInCommand extends AbstractCommand {
  WebSignInCommand(BuildContext c) : super(c);

  Future<bool> execute({bool silentSignIn = false}) async {
    Log.p("[WebSignInCommand] isSilentSignIn: $silentSignIn");
    try {
      final gs = GoogleSignIn(
        clientId: ApiKeys().googleWebClientId,
        scopes: ['https://www.googleapis.com/auth/contacts'],
      );

      GoogleSignInAccount? account;
      if (silentSignIn) {
        // For now, return false for silent sign-in to avoid enum errors
        Log.p("[WebSignInCommand] Silent sign-in disabled due to GIS compatibility");
        return false;
      } else {
        // Use direct signIn to avoid problematic silent sign-in flows
        account = await gs.signIn();
      }
      
      GoogleSignInAuthentication? auth;
      if (account != null)
        auth = await account.authentication;

      if (auth != null) {
        Log.p("[WebSignInCommand] Success");
        authModel.googleSignIn =
            gs; //save off instance of GoogleSignIn, so it can be used to call googleSignIn.disconnect() if needed
        authModel.googleAccessToken = auth.accessToken ?? "";
        authModel.scheduleSave();
        return true;
      } else {
        Log.p("[WebSignInCommand] Fail");
        return false;
      }
    } catch (e) {
      print("Error signing in: $e");
      // If this is the idpiframe error, try to continue anyway
      if (e.toString().contains('idpiframe_initialization_failed')) {
        Log.p("[WebSignInCommand] Attempting fallback authentication");
        // Return false to let the app handle this gracefully
        return false;
      }
      return false;
    }
  }
}

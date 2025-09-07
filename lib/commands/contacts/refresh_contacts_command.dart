import 'package:flokk/_internal/log.dart';
import 'package:flokk/commands/abstract_command.dart';
import 'package:flokk/commands/groups/refresh_contact_groups_command.dart';
import 'package:flokk/data/contact_data.dart';
import 'package:flokk/services/google_rest/google_rest_contacts_service.dart';
import 'package:flokk/services/service_result.dart';
import 'package:flutter/src/widgets/framework.dart';

class RefreshContactsCommand extends AbstractCommand with AuthorizedServiceCommandMixin {
  RefreshContactsCommand(BuildContext c) : super(c);

  Future<ServiceResult> execute({bool skipGroups = false}) async {
    Log.p("[RefreshContactsCommand]");

    ServiceResult<GetContactsResult> result = await executeAuthServiceCmd(() async {
      // Check if we have a sync token...
      String syncToken = authModel.googleSyncToken ?? "";
      if (contactsModel.allContacts.isEmpty) {
        syncToken = "";
      }
      Log.p("[RefreshContactsCommand] Starting contacts fetch with syncToken: ${syncToken.isNotEmpty ? 'present' : 'empty'}");
      ServiceResult<GetContactsResult> result =
          await googleRestService.contacts.getAll(authModel.googleAccessToken, syncToken);
      // Now do we have a sync token?
      syncToken = result.content?.syncToken ?? "";
      List<ContactData> contacts = result.content?.contacts ?? [];
      Log.p("[RefreshContactsCommand] Received ${contacts.length} contacts from API");
      
      if (result.success) {
        authModel.googleSyncToken = syncToken;
        int updatedCount = 0;
        int newCount = 0;
        
        //Iterate through returned contacts and either update existing contact or append
        for (ContactData n in contacts) {
          if (contactsModel.allContacts.any((x) => x.id == n.id)) {
            contactsModel.swapContactById(n);
            updatedCount++;
          } else {
            contactsModel.addContact(n);
            newCount++;
          }
        }
        contactsModel.allContacts.removeWhere((ContactData c) => c.isDeleted);
        contactsModel.notify();
        contactsModel.scheduleSave();
        
        Log.p("[RefreshContactsCommand] Processing complete. Updated: $updatedCount, New: $newCount, Total in app: ${contactsModel.allContacts.length}");
      }
      //Update the groups?
      if (!skipGroups) {
        await RefreshContactGroupsCommand(context).execute();
      }
      Log.p("Contacts loaded = ${contacts.length}");
      return result;
    });
    return result;
  }
}

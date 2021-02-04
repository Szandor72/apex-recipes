public class InboundEmailService implements Messaging.InboundEmailHandler {
    public Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailresult();

        String errorMessage;

        try {
            Contact sender = getContactByEmail(envelope.fromAddress);
            appendAttachmentsToContact(sender.Id, email.binaryAttachments);
            saveEmail(sender, email);
            result.success = true;
        } catch (exception e) {
            result.success = false;
            errorMessage = e.getMessage() + ' ' + e.getStackTraceString();
        }

        if (!result.success) {
            result.message = errorMessage;
        }

        return result;
    }

    private void appendAttachmentsToContact(
        Id contactId,
        List<Messaging.InboundEmail.BinaryAttachment> attachments
    ) {
        if (attachments == null || String.isBlank(contactId)) {
            return;
        }

        List<String> fileNames = new List<String>();
        List<Blob> fileContents = new List<Blob>();
        for (
            Messaging.InboundEmail.BinaryAttachment emailAttachment : attachments
        ) {
            fileNames.add(emailAttachment.fileName);
            fileContents.add(emailAttachment.body);
        }
        createFilesAttachedToRecord(fileNames, fileContents, contactId);
    }

    private void saveEmail(Contact contact, Messaging.InboundEmail email) {
        if (String.isBlank(contact.Id)) {
            return;
        }

        // in the old days, we inserted a task instead
        // which was weird for an incoming mail bc it appeared as outgoing

        /*        
        Task emailTask = new Task(
            WhoId = contact.Id,
            WhatId = contact.AccountId,
            Subject = 'Email: ' + email.subject,
            Description = email.plainTextBody,
            ActivityDate = System.today(),
            TaskSubtype = 'Email'
        );
        insert emailTask;
        */

        // in Lightning Experience / with Enhanced Email we
        // need to create two records - one that stores the email and one that relates it to whoId/whatId

        EmailMessage emailMsg = new EmailMessage(
            TextBody = email.plainTextBody,
            HtmlBody = email.htmlBody,
            Headers = String.valueOf(email.headers),
            Subject = email.subject,
            FromName = email.fromName,
            FromAddress = email.fromAddress,
            ToAddress = String.join(email.toAddresses, ','), // could contain many addresses
            toIds = new List<String>{ UserInfo.getUserId() }, // should identify user(s) via query
            Incoming = true,
            Status = '0',
            MessageDate = System.now(),
            RelatedToId = contact.AccountId
        );

        insert emailMsg;

        insert new EmailMessageRelation(
            EmailMessageId = emailMsg.Id,
            RelationId = contact.Id,
            RelationType = 'FromAddress',
            RelationAddress = contact.Email
        );
    }

    private Contact getContactByEmail(String emailAddress) {
        List<Contact> contactsRelatedToEmail = [
            SELECT Id, AccountId, Email
            FROM Contact
            WHERE Email = :emailAddress
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return contactsRelatedToEmail.size() > 0
            ? contactsRelatedToEmail[0]
            : new Contact(Email = emailAddress);
    }

    private static void createFilesAttachedToRecord(
        List<String> fileNames,
        List<Blob> files,
        Id attachedTo
    ) {
        if (fileNames.size() != files.size()) {
            return;
        }
        List<ContentVersion> filesToUpload = new List<ContentVersion>();

        for (Integer i = 0; i < files.size(); i++) {
            ContentVersion fileToUpload = new ContentVersion();
            // S = Salesforce. The other options are: 'E' (external)
            // and 'L' (social customer service)
            fileToUpload.ContentLocation = 'S';
            fileToUpload.PathOnClient = fileNames[i];
            fileToUpload.Title = fileNames[i];
            fileToUpload.VersionData = files[i];
            fileToUpload.FirstPublishLocationId = attachedTo;

            filesToUpload.add(fileToUpload);
        }

        try {
            // what about crud checks?
            Database.insert(filesToUpload);
        } catch (DmlException DMLE) {
            System.debug(
                LoggingLevel.INFO,
                'Failed to insert fileToUpload, error is: ' + DMLE.getMessage()
            );
        }
    }
}

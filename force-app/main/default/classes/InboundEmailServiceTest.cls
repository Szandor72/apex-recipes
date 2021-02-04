@isTest
private with sharing class InboundEmailServiceTest {
    private static final String contactEmailAddress = 'Testuser@test.example.com.invalid';

    @TestSetup
    static void createContact() {
        insert new Contact(
            Email = contactEmailAddress,
            LastName = 'Soeren',
            FirstName = 'Kierkegaard'
        );
    }

    @IsTest
    static void handleInboundEmail_SUCCESS() {
        System.assertEquals(
            0,
            [SELECT COUNT() FROM EmailMessageRelation],
            'Nothing to start with?'
        );
        List<Messaging.InboundEmail.BinaryAttachment> attachments = new List<Messaging.InboundEmail.BinaryAttachment>();
        String fileName = 'fileName';
        Blob fileBody = Blob.valueOf('fileContent');

        Messaging.InboundEmail.BinaryAttachment file1 = new Messaging.InboundEmail.BinaryAttachment();
        file1.fileName = fileName;
        file1.body = fileBody;

        Messaging.InboundEmail.BinaryAttachment file2 = new Messaging.InboundEmail.BinaryAttachment();
        file2.fileName = fileName;
        file2.body = fileBody;

        Messaging.InboundEmail.BinaryAttachment file3 = new Messaging.InboundEmail.BinaryAttachment();
        file3.fileName = fileName;
        file3.body = fileBody;

        attachments.add(file1);
        attachments.add(file2);
        attachments.add(file3);

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        envelope.fromAddress = contactEmailAddress;
        email.toAddresses = new List<String>{ 'sender@invalid.test' };
        email.subject = 'Email Subject';
        email.plainTextBody = 'PlainText';
        email.binaryAttachments = attachments;
        Test.startTest();
        Messaging.InboundEmailResult result = new InboundEmailService()
            .handleInboundEmail(email, envelope);
        Test.stopTest();
        System.assertEquals(
            true,
            result.success,
            'Handler throws no errors ' + result.message
        );
        System.assertEquals(
            1,
            [SELECT COUNT() FROM EmailMessage],
            'One email successfully stored'
        );
        System.assertEquals(
            2,
            [SELECT COUNT() FROM EmailMessageRelation],
            'Two email relations (sender / receiver) successfully stored'
        );
        System.assertEquals(
            3,
            [SELECT COUNT() FROM ContentVersion],
            'One file per attachment created'
        );
    }
}

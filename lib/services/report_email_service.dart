import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:io';

class ReportEmailService {
  // SMTP server configuration
  final String _smtpServer = 'smtp.gmail.com';
  final int _smtpPort = 465;
  final String _username = 'ai@tecnvi-ai.com';
  final String _password = 'ljpqeudkwhqzaseo';

  Future<void> sendReportEmail({
    required String recipientEmail,
    required String areaName,
    required File reportFile,
    required String reportName,
    String? emailBody,
  }) async {
    try {
      print('Preparing to send email to: $recipientEmail');

      // Create the email message
      final message =
          Message()
            ..from = Address(_username, 'Tecnvi AI')
            ..recipients.add(recipientEmail)
            ..subject = 'Area Report: $areaName - $reportName'
            ..text =
                emailBody ??
                'Please find attached the report for area: $areaName'
            ..attachments = [
              FileAttachment(reportFile)
                ..location = Location.attachment
                ..cid = '<report>',
            ];

      print('Email message created successfully');

      // Create SMTP server configuration
      final smtpServer = SmtpServer(
        _smtpServer,
        port: _smtpPort,
        username: _username,
        password: _password,
        ssl: true,
        allowInsecure: false,
      );

      print('Attempting to send email...');

      // Send the email
      final sendReport = await send(message, smtpServer);
      print('Send report response: $sendReport');

      // Check if the response contains success indicators
      if (sendReport.toString().contains('Message successfully sent') ||
          sendReport.toString().contains('OK')) {
        print('Report email sent successfully');
        return; // Successfully sent, no need to throw exception
      }

      // If we get here, something went wrong
      print('Failed to send email. Response: $sendReport');
      throw Exception('Failed to send report email');
    } catch (e) {
      print('Error in sendReportEmail: $e');
      if (e is SocketException) {
        throw Exception('Network error while sending email: $e');
      } else if (e is MailerException) {
        throw Exception('Email sending failed: ${e.message}');
      } else {
        throw Exception('Error sending report email: $e');
      }
    }
  }
}

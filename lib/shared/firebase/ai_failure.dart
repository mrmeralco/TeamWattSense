import 'ai_request_budget.dart';
import 'package:firebase_ai/firebase_ai.dart';

String firebaseAiFailureMessage(Object error) {
  if (error is AiRequestLimit) return error.message;
  if (error is ServiceApiNotEnabled) {
    return 'Enable Firebase AI Logic in iseeapp-ddf3a using the Google Cloud Vertex AI backend.';
  }
  if (error is InvalidApiKey) {
    return 'Firebase rejected this app configuration. Register WattWise in iseeapp-ddf3a and regenerate its Firebase options.';
  }
  if (error is QuotaExceeded) {
    return 'AI has reached the Firebase AI quota. Try again later or check the project quota.';
  }
  final message = error.toString().toLowerCase();
  if (message.contains('api has not been used') ||
      message.contains('service_disabled')) {
    return 'Enable Vertex AI and Firebase AI Logic in Google Cloud project iseeapp-ddf3a.';
  }
  if (message.contains('billing') ||
      message.contains('credits') ||
      message.contains('prepayment')) {
    return 'Google Cloud rejected the AI billing request. Check billing and available credits for iseeapp-ddf3a.';
  }
  if (message.contains('app check') ||
      message.contains('appcheck') ||
      message.contains('attestation')) {
    return 'Firebase could not verify WattWise with App Check. Configure App Check for the WattWise Android app in iseeapp-ddf3a.';
  }
  if (message.contains('403') ||
      message.contains('permission') ||
      message.contains('unauthenticated')) {
    return 'Firebase denied this request. Check WattWise registration, App Check and API restrictions in iseeapp-ddf3a.';
  }
  if (message.contains('404') || message.contains('not found')) {
    return 'The Mira model or Firebase resource was not found. Check the project and MIRA_MODEL setting.';
  }
  if (message.contains('timeout') ||
      message.contains('socket') ||
      message.contains('connection') ||
      message.contains('host lookup')) {
    return 'AI could not connect to Firebase. Check internet access and retry.';
  }
  return 'AI request failed (${error.runtimeType}). Your data remains saved. Connect the phone for diagnostics.';
}

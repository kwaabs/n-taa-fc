/// OAuth client configuration for mobile.
///
/// These are PUBLIC identifiers (safe to commit). Native AppAuth talks to
/// Azure directly with redirect `fieldcollector://auth-callback`, then
/// exchanges the id_token with GoTrue — same flow as the parent FC app.
class OAuthConfig {
  static const azureClientId = 'ea3835a6-9a59-40b0-821c-3ff54d67a313';
  static const azureTenantId = '711b8fff-9db3-42cc-bc27-7a19ced91f39';
  static const googleClientId = 'PASTE_GOOGLE_MOBILE_CLIENT_ID_HERE';

  static const redirectUri = 'fieldcollector://auth-callback';

  static String get azureDiscoveryUrl =>
      'https://login.microsoftonline.com/$azureTenantId/v2.0/.well-known/openid-configuration';

  static const googleDiscoveryUrl =
      'https://accounts.google.com/.well-known/openid-configuration';
}

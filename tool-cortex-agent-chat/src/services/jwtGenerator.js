/**
 * JWT Generator for Snowflake Key-Pair Authentication
 *
 * Generates JWT tokens client-side using RSA private key for authenticating
 * with Snowflake REST APIs. Tokens are signed with RS256 (RSA-SHA256).
 *
 * Per Snowflake docs, the JWT issuer claim must include the public key fingerprint:
 * iss: <account_identifier>.<user>.SHA256:<public_key_fingerprint>
 */

import KJUR from 'jsrsasign';

/**
 * Calculate the SHA256 fingerprint of the public key (required for Snowflake JWT)
 *
 * @param {object} privateKeyObj - RSA private key object from KEYUTIL.getKey
 * @returns {string} Base64-encoded SHA256 fingerprint
 */
const calculatePublicKeyFingerprint = (privateKeyObj) => {
  // Get public key in PKCS#8 PEM format
  const pubKeyPEM = KJUR.KEYUTIL.getPEM(privateKeyObj, 'PKCS8PUB');

  // Convert PEM to DER (binary) format
  const pubKeyHex = KJUR.pemtohex(pubKeyPEM);

  // Calculate SHA256 hash of the DER-encoded public key
  const sha256Hex = KJUR.crypto.Util.hashHex(pubKeyHex, 'sha256');

  // Convert hex to base64
  const fingerprint = KJUR.hextob64(sha256Hex);

  return fingerprint;
};

/**
 * Generate a JWT token for Snowflake REST API authentication
 *
 * @param {string} account - Snowflake account identifier (e.g., "xy12345.us-east-1")
 * @param {string} user - Snowflake username
 * @param {string} privateKey - RSA private key in PEM format
 * @param {number} expiresInSeconds - Token expiration time (default: 3600 = 1 hour)
 * @returns {string} Signed JWT token
 * @throws {Error} If key format is invalid or signing fails
 */
export const generateJWT = (account, user, privateKey, expiresInSeconds = 3600) => {
  try {
    // Validate inputs
    if (!account || !account.trim()) {
      throw new Error('Snowflake account is required');
    }
    if (!user || !user.trim()) {
      throw new Error('Snowflake user is required');
    }
    if (!privateKey || !privateKey.trim()) {
      throw new Error('Private key is required');
    }

    // Normalize account identifier per Snowflake requirements:
    // - Remove .snowflakecomputing.com if present
    // - Replace periods with hyphens (periods in account ID cause JWT to be invalid)
    // - Convert to UPPERCASE
    let accountIdentifier = account.trim()
      .replace('.snowflakecomputing.com', '')
      .replace(/\./g, '-')  // Replace all periods with hyphens
      .toUpperCase();

    const username = user.trim().toUpperCase();

    // Construct qualified username (account.user format)
    const qualifiedUsername = `${accountIdentifier}.${username}`;

    // Parse private key (PKCS#8 format required by Snowflake)
    // Convert escaped \n to actual newlines (React .env files store as literal \n)
    let normalizedKey = privateKey.replace(/\\n/g, '\n').trim();

    // Ensure the key ends with a newline (some parsers expect this)
    if (!normalizedKey.endsWith('\n')) {
      normalizedKey += '\n';
    }

    let privateKeyObj;
    try {
      // jsrsasign KEYUTIL.getKey can handle PEM format directly
      privateKeyObj = KJUR.KEYUTIL.getKey(normalizedKey);

      // Verify we got a valid RSA key object with required components
      if (!privateKeyObj) {
        throw new Error('KEYUTIL.getKey returned null');
      }
      if (typeof privateKeyObj.n === 'undefined' || typeof privateKeyObj.e === 'undefined') {
        throw new Error('Key parsed but missing required RSA components (n, e)');
      }
    } catch (keyError) {
      // Debug output for troubleshooting
      console.error('Private key parsing failed');
      console.error('Error:', keyError.message);
      console.error('Key starts with:', normalizedKey.substring(0, 50));
      console.error('Key ends with:', normalizedKey.substring(normalizedKey.length - 50));
      console.error('Key length:', normalizedKey.length);
      throw new Error(
        `Invalid private key format: ${keyError.message}. Ensure the key is in PEM format and includes valid header/footer lines.`
      );
    }

    // Calculate public key fingerprint (required by Snowflake)
    const fingerprint = calculatePublicKeyFingerprint(privateKeyObj);

    // Current time and expiration
    const now = Math.floor(Date.now() / 1000);
    const exp = now + expiresInSeconds;

    // JWT Header
    const header = {
      alg: 'RS256',
      typ: 'JWT'
    };

    // JWT Payload per Snowflake requirements:
    // - iss: <account>.<user>.SHA256:<fingerprint>
    // - sub: <account>.<user>
    const payload = {
      iss: `${qualifiedUsername}.SHA256:${fingerprint}`,  // Issuer with fingerprint
      sub: qualifiedUsername,                              // Subject (qualified username)
      iat: now,                                            // Issued at
      exp: exp                                             // Expiration time
    };

    // Sign the JWT with the private key
    const sHeader = JSON.stringify(header);
    const sPayload = JSON.stringify(payload);

    // Generate JWT token
    const token = KJUR.jws.JWS.sign('RS256', sHeader, sPayload, privateKeyObj);

    return token;
  } catch (error) {
    throw new Error(`JWT generation failed: ${error.message}`);
  }
};

/**
 * Validate if a JWT token is expired or about to expire
 *
 * @param {string} token - JWT token to validate
 * @param {number} bufferSeconds - Consider expired if expiring within this buffer (default: 300 = 5 minutes)
 * @returns {boolean} True if token is expired or about to expire
 */
export const isTokenExpired = (token, bufferSeconds = 300) => {
  try {
    if (!token || !token.trim()) {
      return true;
    }

    // Decode the JWT payload
    const parts = token.split('.');
    if (parts.length !== 3) {
      return true;
    }

    const payload = JSON.parse(atob(parts[1]));
    const exp = payload.exp;

    if (!exp) {
      return true;
    }

    const now = Math.floor(Date.now() / 1000);
    return exp <= (now + bufferSeconds);
  } catch (error) {
    return true;
  }
};

/**
 * JWT Token Manager - Handles token generation and caching
 */
export class JWTTokenManager {
  constructor(account, user, privateKey) {
    this.account = account;
    this.user = user;
    this.privateKey = privateKey;
    this.cachedToken = null;
  }

  /**
   * Get a valid JWT token (generates new if expired or missing)
   *
   * @returns {string} Valid JWT token
   */
  getToken() {
    if (!this.cachedToken || isTokenExpired(this.cachedToken)) {
      this.cachedToken = generateJWT(this.account, this.user, this.privateKey);
    }
    return this.cachedToken;
  }

  /**
   * Force refresh the token
   *
   * @returns {string} New JWT token
   */
  refreshToken() {
    this.cachedToken = generateJWT(this.account, this.user, this.privateKey);
    return this.cachedToken;
  }

  /**
   * Clear cached token
   */
  clearToken() {
    this.cachedToken = null;
  }
}

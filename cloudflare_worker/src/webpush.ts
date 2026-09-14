// Lightweight, fully-native Web Push (RFC 8291 / RFC 8292) implementation for Cloudflare Workers
// Uses Web Crypto API (crypto.subtle) without any native external dependencies.

export interface PushSubscriptionKeys {
  p256dh: string;
  auth: string;
}

export interface PushSubscription {
  endpoint: string;
  keys: PushSubscriptionKeys;
}

export interface VapidKeys {
  publicKey: string;
  privateKey: string;
  subject: string;
}

export interface PushPayload {
  title: string;
  body: string;
  icon?: string;
  badge?: string;
  tag?: string;
  data?: Record<string, unknown>;
}

// Helper: Base64URL encode / decode
function base64UrlToUint8Array(base64Url: string): Uint8Array {
  const padding = '='.repeat((4 - (base64Url.length % 4)) % 4);
  const base64 = (base64Url + padding).replace(/-/g, '+').replace(/_/g, '/');
  const rawData = atob(base64);
  const outputArray = new Uint8Array(rawData.length);
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

function uint8ArrayToBase64Url(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function stringToUint8Array(str: string): Uint8Array {
  return new TextEncoder().encode(str);
}

function concatUint8Arrays(...arrays: Uint8Array[]): Uint8Array {
  const totalLength = arrays.reduce((acc, val) => acc + val.length, 0);
  const result = new Uint8Array(totalLength);
  let offset = 0;
  for (const arr of arrays) {
    result.set(arr, offset);
    offset += arr.length;
  }
  return result;
}

// Convert raw 32-byte private key scalar to PKCS#8 DER for crypto.subtle.importKey
function rawP256PrivateKeyToPkcs8(privateKeyRaw: Uint8Array): Uint8Array {
  const pkcs8Header = new Uint8Array([
    0x30, 0x41, // SEQUENCE (65 bytes)
    0x02, 0x01, 0x00, // INTEGER 0 (version)
    0x30, 0x13, // SEQUENCE (19 bytes)
    0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, // OID id-ecPublicKey
    0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, // OID secp256r1
    0x04, 0x27, // OCTET STRING (39 bytes)
    0x30, 0x25, // SEQUENCE (37 bytes)
    0x02, 0x01, 0x01, // INTEGER 1
    0x04, 0x20 // OCTET STRING (32 bytes)
  ]);

  return concatUint8Arrays(pkcs8Header, privateKeyRaw);
}

// Generate VAPID Authorization JWT
async function createVapidJwt(endpoint: string, vapid: VapidKeys): Promise<string> {
  const url = new URL(endpoint);
  const audience = `${url.protocol}//${url.host}`;
  const now = Math.floor(Date.now() / 1000);
  const exp = now + 12 * 3600; // 12 hours

  const header = {
    typ: 'JWT',
    alg: 'ES256'
  };

  const payload = {
    aud: audience,
    exp: exp,
    sub: vapid.subject
  };

  const encodedHeader = uint8ArrayToBase64Url(stringToUint8Array(JSON.stringify(header)));
  const encodedPayload = uint8ArrayToBase64Url(stringToUint8Array(JSON.stringify(payload)));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  const privateKeyBytes = base64UrlToUint8Array(vapid.privateKey);
  const pkcs8Bytes = rawP256PrivateKeyToPkcs8(privateKeyBytes);

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    pkcs8Bytes.buffer as ArrayBuffer,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  );

  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    cryptoKey,
    stringToUint8Array(unsignedToken)
  );

  const signatureBytes = new Uint8Array(signature);
  const encodedSignature = uint8ArrayToBase64Url(signatureBytes);

  return `${unsignedToken}.${encodedSignature}`;
}

// HKDF-Extract using HMAC-SHA-256
async function hkdfExtract(salt: Uint8Array, ikm: Uint8Array): Promise<ArrayBuffer> {
  const key = await crypto.subtle.importKey(
    'raw',
    salt.buffer as ArrayBuffer,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  return await crypto.subtle.sign('HMAC', key, ikm);
}

// HKDF-Expand using HMAC-SHA-256
async function hkdfExpand(prk: ArrayBuffer, info: Uint8Array, length: number): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey('raw', prk, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const infoWithCounter = concatUint8Arrays(info, new Uint8Array([0x01]));
  const fullSignature = await crypto.subtle.sign('HMAC', key, infoWithCounter);
  return new Uint8Array(fullSignature.slice(0, length));
}

// Encrypt payload according to RFC 8291 (aes128gcm)
async function encryptPayload(
  payloadText: string,
  clientP256dhBase64Url: string,
  clientAuthBase64Url: string
): Promise<Uint8Array> {
  const clientPublicKeyBytes = base64UrlToUint8Array(clientP256dhBase64Url);
  const clientAuthBytes = base64UrlToUint8Array(clientAuthBase64Url);
  const payloadBytes = stringToUint8Array(payloadText);

  // 1. Generate local ephemeral ECDH key pair
  const localKeyPair = (await crypto.subtle.generateKey(
    { name: 'ECDH', namedCurve: 'P-256' },
    true,
    ['deriveBits']
  )) as CryptoKeyPair;

  const localPublicKeyBuffer = (await crypto.subtle.exportKey('raw', localKeyPair.publicKey)) as ArrayBuffer;
  const localPublicKeyBytes = new Uint8Array(localPublicKeyBuffer);

  // 2. Import client public key
  const clientPublicKey = await crypto.subtle.importKey(
    'raw',
    clientPublicKeyBytes.buffer as ArrayBuffer,
    { name: 'ECDH', namedCurve: 'P-256' },
    false,
    []
  );

  // 3. Derive ECDH shared secret (32 bytes)
  const sharedSecretBuffer = await crypto.subtle.deriveBits(
    { name: 'ECDH', public: clientPublicKey } as any,
    localKeyPair.privateKey,
    256
  );
  const sharedSecret = new Uint8Array(sharedSecretBuffer);

  // 4. Generate 16-byte random salt
  const salt = new Uint8Array(16);
  crypto.getRandomValues(salt);

  // 5. Derive PRK_key and IKM according to RFC 8291
  const authInfo = concatUint8Arrays(
    stringToUint8Array('WebPush: info\0'),
    clientPublicKeyBytes,
    localPublicKeyBytes
  );
  const prkKey = await hkdfExtract(clientAuthBytes, sharedSecret);
  const ikm = await hkdfExpand(prkKey, authInfo, 32);

  // 6. Derive CEK (Content Encryption Key: 16 bytes) and Nonce (12 bytes)
  const prk = await hkdfExtract(salt, ikm);
  const cek = await hkdfExpand(prk, stringToUint8Array('Content-Encoding: aes128gcm\0'), 16);
  const nonce = await hkdfExpand(prk, stringToUint8Array('Content-Encoding: nonce\0'), 12);

  // 7. Pad the payload: payload || 0x02 (delimiter)
  const paddedPayload = concatUint8Arrays(payloadBytes, new Uint8Array([0x02]));

  // 8. Encrypt using AES-128-GCM
  const aesKey = await crypto.subtle.importKey('raw', cek.buffer as ArrayBuffer, 'AES-GCM', false, ['encrypt']);
  const ciphertextBuffer = (await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv: nonce.buffer as ArrayBuffer, tagLength: 128 },
    aesKey,
    paddedPayload
  )) as ArrayBuffer;
  const ciphertext = new Uint8Array(ciphertextBuffer);

  // 9. Format body: salt (16 bytes) || rs (4 bytes) || idlen (1 byte) || key (65 bytes) || ciphertext
  const rs = new Uint8Array([0x00, 0x00, 0x10, 0x00]); // 4096 bytes record size
  const idlen = new Uint8Array([localPublicKeyBytes.length]); // 65 (0x41)

  return concatUint8Arrays(salt, rs, idlen, localPublicKeyBytes, ciphertext);
}

// Send Web Push notification
export async function sendWebPush(
  subscription: PushSubscription,
  payload: PushPayload,
  vapid: VapidKeys
): Promise<{ status: number; ok: boolean; error?: string }> {
  try {
    const payloadString = JSON.stringify(payload);
    const encryptedBody = await encryptPayload(
      payloadString,
      subscription.keys.p256dh,
      subscription.keys.auth
    );

    const jwt = await createVapidJwt(subscription.endpoint, vapid);

    const headers = {
      'Content-Type': 'application/octet-stream',
      'Content-Encoding': 'aes128gcm',
      'TTL': '1800', // 30 minutes
      'Urgency': 'high',
      'Authorization': `vapid t=${jwt}, k=${vapid.publicKey}`
    };

    const response = await fetch(subscription.endpoint, {
      method: 'POST',
      headers: headers,
      body: encryptedBody.buffer as ArrayBuffer
    });

    if (response.status === 201 || response.status === 200 || response.status === 202) {
      return { status: response.status, ok: true };
    }

    const text = await response.text();
    return {
      status: response.status,
      ok: false,
      error: `Push gateway error (${response.status}): ${text}`
    };
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return { status: 500, ok: false, error: errorMsg };
  }
}

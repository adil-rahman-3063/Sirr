import crypto from 'node:crypto';

function base64UrlEncode(buffer) {
  return buffer.toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function generateVapidKeys() {
  const ecdh = crypto.createECDH('prime256v1');
  ecdh.generateKeys();

  const publicKey = base64UrlEncode(ecdh.getPublicKey());
  const privateKey = base64UrlEncode(ecdh.getPrivateKey());

  console.log('='.repeat(60));
  console.log('✅ Generated VAPID Keys for Sirr Push Notifications:');
  console.log('='.repeat(60));
  console.log('\n[VAPID Public Key] (Put this in your Flutter App & wrangler.toml):');
  console.log(publicKey);
  console.log('\n[VAPID Private Key] (Keep this secret! Store in Cloudflare Worker secret):');
  console.log(privateKey);
  console.log('\n' + '='.repeat(60));
  console.log('Commands to set Cloudflare Worker secret:');
  console.log(`npx wrangler secret put VAPID_PRIVATE_KEY`);
  console.log(`(When prompted, paste the private key: ${privateKey})`);
  console.log('='.repeat(60) + '\n');

  return { publicKey, privateKey };
}

generateVapidKeys();

import { createRemoteJWKSet, jwtVerify } from 'jose';

export interface VerifiedAppleIdentity {
  appleSub: string;
  email: string | null;
}

const appleJWKS = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

export class AppleIdentityVerifier {
  private readonly audience: string;

  constructor(audience: string) {
    this.audience = audience;
  }

  async verify(identityToken: string, expectedNonce: string): Promise<VerifiedAppleIdentity> {
    const result = await jwtVerify(identityToken, appleJWKS, {
      issuer: 'https://appleid.apple.com',
      audience: this.audience,
    });
    if (typeof result.payload.sub !== 'string' || result.payload.sub.length === 0) {
      throw new Error('Apple identity token is missing sub');
    }
    if (typeof result.payload.nonce !== 'string' || result.payload.nonce !== expectedNonce) {
      throw new Error('Apple identity token nonce mismatch');
    }
    return {
      appleSub: result.payload.sub,
      email: typeof result.payload.email === 'string' ? result.payload.email : null,
    };
  }
}

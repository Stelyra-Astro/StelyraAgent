export interface AppleTokenExchangeResult {
  refreshToken: string | null;
}

export class AppleTokenExchange {
  private readonly clientId: string;
  private readonly clientSecret: string | null;
  private readonly fetchImpl: typeof fetch;

  constructor(clientId: string, clientSecret?: string, fetchImpl: typeof fetch = fetch) {
    this.clientId = clientId;
    this.clientSecret = clientSecret ?? null;
    this.fetchImpl = fetchImpl;
  }

  async exchange(authorizationCode: string): Promise<AppleTokenExchangeResult> {
    if (!this.clientSecret) return { refreshToken: null };
    const body = new URLSearchParams({
      client_id: this.clientId,
      client_secret: this.clientSecret,
      code: authorizationCode,
      grant_type: 'authorization_code',
    });
    const response = await this.fetchImpl('https://appleid.apple.com/auth/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body,
    });
    if (!response.ok) throw new Error(`Apple token exchange failed: ${response.status}`);
    const data = await response.json() as { refresh_token?: string };
    return { refreshToken: data.refresh_token ?? null };
  }

  async revoke(refreshToken: string): Promise<void> {
    if (!this.clientSecret) throw new Error('Apple client secret is not configured');
    const body = new URLSearchParams({
      client_id: this.clientId,
      client_secret: this.clientSecret,
      token: refreshToken,
      token_type_hint: 'refresh_token',
    });
    const response = await this.fetchImpl('https://appleid.apple.com/auth/revoke', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body,
    });
    if (!response.ok) throw new Error(`Apple token revoke failed: ${response.status}`);
  }
}

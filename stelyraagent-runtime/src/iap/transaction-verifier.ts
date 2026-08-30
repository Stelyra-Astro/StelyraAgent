import { readFileSync } from 'node:fs';

export interface VerifiedStoreTransaction {
  transactionId: string;
  appAccountToken: string;
  productId: string;
  credits: number;
}

export interface StoreTransactionVerifier {
  verify(signedTransaction: string): Promise<VerifiedStoreTransaction>;
}

export interface DecodedAppleTransaction {
  transactionId?: string;
  appAccountToken?: string;
  productId?: string;
}

export type AppleTransactionDecoder = (signedTransaction: string) => Promise<DecodedAppleTransaction>;

export class AppleStoreTransactionVerifier implements StoreTransactionVerifier {
  private readonly decode: AppleTransactionDecoder;
  private readonly productCredits: Readonly<Record<string, number>>;

  constructor(decode: AppleTransactionDecoder, productCredits: Readonly<Record<string, number>>) {
    this.decode = decode;
    this.productCredits = productCredits;
  }

  async verify(signedTransaction: string): Promise<VerifiedStoreTransaction> {
    const decoded = await this.decode(signedTransaction);
    if (!decoded.transactionId) throw new Error('Verified transaction is missing transactionId');
    if (!decoded.appAccountToken) throw new Error('Verified transaction is missing appAccountToken');
    if (!decoded.productId) throw new Error('Verified transaction is missing productId');
    const credits = this.productCredits[decoded.productId];
    if (!Number.isInteger(credits) || credits <= 0) {
      throw new Error(`Product ${decoded.productId} is not configured for credits`);
    }
    return {
      transactionId: decoded.transactionId,
      appAccountToken: decoded.appAccountToken,
      productId: decoded.productId,
      credits,
    };
  }
}

export interface AppleStoreVerifierConfig {
  environment: 'Sandbox' | 'Production' | 'Xcode';
  bundleId: string;
  appAppleId?: number;
  enableOnlineChecks: boolean;
  rootCertificatePaths: string[];
  productCredits: Record<string, number>;
}

export async function createAppleStoreTransactionVerifier(
  config: AppleStoreVerifierConfig,
): Promise<AppleStoreTransactionVerifier> {
  if (!config.bundleId) throw new Error('APP_STORE_BUNDLE_ID is required');
  if (config.rootCertificatePaths.length === 0) throw new Error('APPLE_ROOT_CA_PATHS is required');
  if (Object.keys(config.productCredits).length === 0) throw new Error('IAP_PRODUCT_CREDITS_JSON is required');

  const appleLibrary = await import('@apple/app-store-server-library');
  const environment = config.environment === 'Production'
    ? appleLibrary.Environment.PRODUCTION
    : config.environment === 'Xcode'
      ? appleLibrary.Environment.XCODE
      : appleLibrary.Environment.SANDBOX;
  if (config.environment === 'Production' && !config.appAppleId) {
    throw new Error('APP_STORE_APP_APPLE_ID is required in Production');
  }

  const roots = config.rootCertificatePaths.map((path) => readFileSync(path));
  const verifier = new appleLibrary.SignedDataVerifier(
    roots,
    config.enableOnlineChecks,
    environment,
    config.bundleId,
    config.appAppleId,
  );

  return new AppleStoreTransactionVerifier(
    async (signedTransaction) => verifier.verifyAndDecodeTransaction(signedTransaction),
    config.productCredits,
  );
}

export function loadAppleStoreVerifierConfig(env: NodeJS.ProcessEnv): AppleStoreVerifierConfig | null {
  const bundleId = env.APP_STORE_BUNDLE_ID?.trim();
  const rootPaths = env.APPLE_ROOT_CA_PATHS
    ?.split(',')
    .map((value) => value.trim())
    .filter(Boolean) ?? [];
  const productJSON = env.IAP_PRODUCT_CREDITS_JSON?.trim();
  if (!bundleId || rootPaths.length === 0 || !productJSON) return null;

  let rawProducts: unknown;
  try {
    rawProducts = JSON.parse(productJSON);
  } catch {
    throw new Error('IAP_PRODUCT_CREDITS_JSON must be valid JSON');
  }
  if (!rawProducts || typeof rawProducts !== 'object' || Array.isArray(rawProducts)) {
    throw new Error('IAP_PRODUCT_CREDITS_JSON must be a JSON object');
  }
  const productCredits: Record<string, number> = {};
  for (const [productId, value] of Object.entries(rawProducts as Record<string, unknown>)) {
    const credits = Number(value);
    if (!productId || !Number.isInteger(credits) || credits <= 0) {
      throw new Error(`Invalid credit mapping for ${productId || '<empty product>'}`);
    }
    productCredits[productId] = credits;
  }

  const environmentRaw = env.APP_STORE_ENVIRONMENT?.trim().toLowerCase() ?? 'sandbox';
  const environment: AppleStoreVerifierConfig['environment'] = environmentRaw === 'production'
    ? 'Production'
    : environmentRaw === 'xcode'
      ? 'Xcode'
      : 'Sandbox';
  const appAppleId = env.APP_STORE_APP_APPLE_ID ? Number(env.APP_STORE_APP_APPLE_ID) : undefined;

  return {
    environment,
    bundleId,
    appAppleId: Number.isFinite(appAppleId) ? appAppleId : undefined,
    enableOnlineChecks: env.APP_STORE_ENABLE_ONLINE_CHECKS !== 'false',
    rootCertificatePaths: rootPaths,
    productCredits,
  };
}

export class RejectingStoreTransactionVerifier implements StoreTransactionVerifier {
  async verify(): Promise<VerifiedStoreTransaction> {
    throw new Error('App Store server-side transaction verification is not configured');
  }
}

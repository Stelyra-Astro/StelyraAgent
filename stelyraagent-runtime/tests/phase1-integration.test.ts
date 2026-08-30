import test from 'node:test';
import assert from 'node:assert/strict';
import { createTestDatabase } from '../src/db/sqlite-database.ts';
import { SqliteAccountRepository } from '../src/repositories/sqlite-account-repository.ts';
import { SqliteCreditRepository } from '../src/repositories/sqlite-credit-repository.ts';
import { SqliteIAPRepository } from '../src/repositories/sqlite-iap-repository.ts';
import { SqliteRunRepository } from '../src/repositories/sqlite-run-repository.ts';
import { AccountService } from '../src/account/account-service.ts';
import { IAPService } from '../src/iap/iap-service.ts';
import { RunService } from '../src/run/run-service.ts';
import { AstrologyAgentRuntime } from '../src/agent/astrology-agent-runtime.ts';
import type { ModelProvider, ModelProviderRequest, ProviderDecision } from '../src/providers/model-provider.ts';

class IntegrationProvider implements ModelProvider {
  readonly name = 'integration-provider';
  readonly model = 'integration-model';
  private decisions: ProviderDecision[] = [
    {
      kind: 'astrology_tool',
      requests: [{ capability: 'you.transit', subjects: ['primary'] }],
      reason: 'Use the explicitly selected local transit chart.',
    },
    {
      kind: 'final',
      text: 'The supplied local transit evidence is sufficient for this Phase 1 integration run.',
      title: 'Transit Integration',
    },
  ];

  async generate(_request: ModelProviderRequest): Promise<ProviderDecision> {
    const decision = this.decisions.shift();
    if (!decision) throw new Error('No integration decision left');
    return decision;
  }
}

test('account -> IAP -> reserved run -> local action -> final -> ACK preserves metadata and spends one credit', async () => {
  const db = createTestDatabase();
  const accounts = new SqliteAccountRepository(db);
  const credits = new SqliteCreditRepository(db);
  const iap = new SqliteIAPRepository(db);
  const runs = new SqliteRunRepository(db);
  const accountService = new AccountService(accounts, credits);
  const iapService = new IAPService(iap, credits);
  const runService = new RunService(runs, credits);
  const provider = new IntegrationProvider();
  const agent = new AstrologyAgentRuntime(runService, provider, { maxToolRounds: 2 });

  const bundle = accountService.signInOrCreate('phase1_apple_sub');
  iapService.reconcileVerified({
    transactionId: 'phase1_tx',
    walletId: bundle.wallet.walletId,
    appAccountToken: bundle.wallet.appAccountToken,
    productId: 'credits.1',
    credits: 1,
  });

  runService.createRun({
    runId: 'phase1_run',
    walletId: bundle.wallet.walletId,
    creditsRequired: 1,
    payload: {
      question: 'What is changing now?',
      clientCapabilities: ['you.natal', 'you.transit', 'you.secondary'],
      draftContext: [{ kind: 'chart', value: 'you.transit', title: 'Chart · Transit' }],
    },
  });
  runService.startReasoning('phase1_run');

  const paused = await agent.advance('phase1_run');
  assert.equal(paused.status, 'requires_action');
  assert.equal(runService.getRun('phase1_run').provider, 'integration-provider');
  assert.equal(runService.getRun('phase1_run').model, 'integration-model');
  assert.equal(credits.getWallet(bundle.wallet.walletId)?.availableBalance, 0);
  assert.equal(credits.getWallet(bundle.wallet.walletId)?.reservedBalance, 1);

  const action = runService.getRun('phase1_run').pendingAction!;
  runService.submitAction('phase1_run', action.id, {
    chart_asset_ids: ['asset_1'],
    facts: [{ source_chart: 'you.transit', fact_type: 'activation' }],
  });
  const completed = await agent.advance('phase1_run');
  assert.equal(completed.status, 'completed');
  assert.equal(credits.getWallet(bundle.wallet.walletId)?.reservedBalance, 1);
  assert.match(JSON.stringify(runService.getRun('phase1_run').payload), /Transit Integration/);

  runService.acknowledge('phase1_run');
  const acknowledged = runService.getRun('phase1_run');
  assert.equal(acknowledged.status, 'acknowledged');
  assert.equal(acknowledged.payload, null);
  assert.equal(acknowledged.provider, 'integration-provider');
  assert.equal(acknowledged.model, 'integration-model');
  assert.equal(credits.getWallet(bundle.wallet.walletId)?.reservedBalance, 0);
  assert.equal(credits.getWallet(bundle.wallet.walletId)?.spentBalance, 1);
});

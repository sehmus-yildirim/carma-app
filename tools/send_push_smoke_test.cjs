#!/usr/bin/env node

'use strict';

const { applicationDefault, initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

const projectId = 'carma-a84e4';
const supportedStates = new Set(['foreground', 'background', 'terminated']);
const state = process.argv
  .find((argument) => argument.startsWith('--state='))
  ?.slice('--state='.length);

if (!supportedStates.has(state)) {
  console.error(
    'Usage: node tools/send_push_smoke_test.cjs --state=foreground|background|terminated',
  );
  process.exit(2);
}

const stateLabels = {
  foreground: 'Vordergrund',
  background: 'Hintergrund',
  terminated: 'App geschlossen',
};

function updatedAtMillis(document) {
  const value = document.get('updatedAt');
  if (value && typeof value.toMillis === 'function') return value.toMillis();
  return 0;
}

async function newestAndroidToken() {
  const snapshot = await getFirestore().collectionGroup('push_tokens').get();
  const candidates = snapshot.docs
    .filter((document) => {
      const token = document.get('token');
      const platform = document.get('platform');
      return platform === 'android' && typeof token === 'string' && token.trim();
    })
    .sort((left, right) => updatedAtMillis(right) - updatedAtMillis(left));

  if (candidates.length === 0) {
    throw new Error('No registered Android push token was found.');
  }
  return candidates[0];
}

async function main() {
  initializeApp({ credential: applicationDefault(), projectId });

  const tokenDocument = await newestAndroidToken();
  const runId = `${Date.now()}`;
  const messageId = await getMessaging().send({
    token: tokenDocument.get('token').trim(),
    notification: {
      title: `plaqa Push-Test: ${stateLabels[state]}`,
      body: `Echte FCM-Testnachricht fuer ${stateLabels[state]}.`,
    },
    data: {
      type: 'chat',
      resourceId: `push-smoke-${state}-${runId}`,
      pushSmokeState: state,
      pushSmokeRunId: runId,
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'plaqa_messages',
        sound: 'default',
        tag: `plaqa-push-smoke-${state}`,
      },
    },
  });

  console.log(
    JSON.stringify({
      deliveredToFcm: true,
      state,
      messageId,
      tokenAgeSeconds: Math.max(
        0,
        Math.round((Date.now() - updatedAtMillis(tokenDocument)) / 1000),
      ),
    }),
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});

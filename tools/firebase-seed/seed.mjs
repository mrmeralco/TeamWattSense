import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const projectId = process.env.WATTWISE_FIREBASE_PROJECT_ID || 'iseeapp-ddf3a';
const catalogPath = resolve('assets/data/appliance_catalog.json');
const items = JSON.parse(await readFile(catalogPath, 'utf8'));

initializeApp({
  credential: applicationDefault(),
  projectId,
});

const db = getFirestore();
for (let start = 0; start < items.length; start += 450) {
  const batch = db.batch();
  for (const item of items.slice(start, start + 450)) {
    const { id, ...data } = item;
    batch.set(db.collection('appliance_catalog').doc(id), data);
  }
  await batch.commit();
}

console.log(`Seeded ${items.length} appliance catalog entries to ${projectId}.`);

// Prints the newest Firebase Hosting releases of the live site (version id and time),
// using the firebase CLI's stored sign-in. Never prints a token.
// Usage: node tool/web/live_release.mjs [count]
// If it prints "HTTP 401", run any firebase command first (for example
// "firebase hosting:channel:list --project pcu-workflow") to refresh the sign-in.
import fs from 'node:fs';
import os from 'node:os';

const config = JSON.parse(fs.readFileSync(os.homedir() + '/.config/configstore/firebase-tools.json', 'utf8'));
const count = Number(process.argv[2] || 2);
const res = await fetch(
  `https://firebasehosting.googleapis.com/v1beta1/sites/pcu-workflow/channels/live/releases?pageSize=${count}`,
  { headers: { Authorization: 'Bearer ' + config.tokens.access_token } },
);
const body = await res.json();
if (!body.releases) {
  console.log('HTTP', res.status);
  process.exit(1);
}
for (const r of body.releases) console.log(r.version.name.split('/').pop(), r.releaseTime);

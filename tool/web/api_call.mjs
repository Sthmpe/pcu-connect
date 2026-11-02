// Calls the test Apps Script API and prints the time and the response.
// Usage: node tool/web/api_call.mjs '{"action":"me","idToken":"<Firebase ID token>"}'
// The deployed script accepts only real Firebase ID tokens: a mock_token gets
// UNAUTHENTICATED (that is how to check the security live).
const EXEC = process.env.PCU_EXEC_URL ||
  'https://script.google.com/macros/s/AKfycby0H6Sk-V1mCGJNtst4KzvraWplYqMn6exWDlLCybiINoGlXnSCUNdkNaJ8D4o0tC3u/exec';
const started = Date.now();
const res = await fetch(EXEC, { method: 'POST', headers: { 'Content-Type': 'text/plain' }, body: process.argv[2] });
const text = await res.text();
console.log(((Date.now() - started) / 1000).toFixed(1) + 's', text.slice(0, Number(process.argv[3]) || 1500));

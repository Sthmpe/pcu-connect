// Calls the test Apps Script API and prints the time and the response.
// Usage: node tool/web/api_call.mjs '{"action":"me","idToken":"mock_token_<email>"}'
// Mock tokens only work while the TEST sheet has ALLOW_MOCK_TOKENS=true.
const EXEC = process.env.PCU_EXEC_URL ||
  'https://script.google.com/macros/s/AKfycby0H6Sk-V1mCGJNtst4KzvraWplYqMn6exWDlLCybiINoGlXnSCUNdkNaJ8D4o0tC3u/exec';
const started = Date.now();
const res = await fetch(EXEC, { method: 'POST', headers: { 'Content-Type': 'text/plain' }, body: process.argv[2] });
const text = await res.text();
console.log(((Date.now() - started) / 1000).toFixed(1) + 's', text.slice(0, Number(process.argv[3]) || 1500));

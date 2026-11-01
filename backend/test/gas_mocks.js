// Shared mocks of the Apps Script Sheet and CacheService APIs used by the backend.
// Sheet semantics follow Google Sheets: getLastRow/getLastColumn ignore empty
// cells, getDataRange stops at the last row and column with content.

function isEmpty(v) { return v === '' || v === null || v === undefined; }

function makeSheet(rows, name) {
  const sheet = { name, rows, appended: [], sets: [], reads: [],
    getLastRow() {
      for (let r = sheet.rows.length; r > 0; r--) if ((sheet.rows[r - 1] || []).some(v => !isEmpty(v))) return r;
      return 0;
    },
    getLastColumn() {
      let last = 0;
      sheet.rows.forEach(row => (row || []).forEach((v, c) => { if (!isEmpty(v)) last = Math.max(last, c + 1); }));
      return last;
    },
    getDataRange() { return sheet.getRange(1, 1, Math.max(1, sheet.getLastRow()), Math.max(1, sheet.getLastColumn())); },
    appendRow(r) { sheet.rows.splice(sheet.getLastRow(), 0, r.slice()); sheet.appended.push(r); },
    getRange(r, c, nr = 1, nc = 1) {
      if (r < 1 || c < 1 || nr < 1 || nc < 1) throw new Error(`bad range ${r},${c},${nr},${nc}`);
      return {
        getValues() {
          sheet.reads.push([r, c, nr, nc]);
          const out = [];
          for (let i = 0; i < nr; i++) {
            const row = sheet.rows[r - 1 + i] || [];
            const line = [];
            for (let j = 0; j < nc; j++) { const v = row[c - 1 + j]; line.push(isEmpty(v) ? '' : v); }
            out.push(line);
          }
          return out;
        },
        setValue(v) {
          while (sheet.rows.length < r) sheet.rows.push([]);
          sheet.rows[r - 1][c - 1] = v; sheet.sets.push([r, c, v]);
        },
        createTextFinder(text) {
          const opts = { regex: false, matchCase: false, entire: false };
          const finder = {
            useRegularExpression(b) { opts.regex = b; return finder; },
            matchCase(b) { opts.matchCase = b; return finder; },
            matchEntireCell(b) { opts.entire = b; return finder; },
            findAll() {
              const source = opts.regex ? text : text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
              const re = new RegExp(opts.entire ? `^(?:${source})$` : source, opts.matchCase ? '' : 'i');
              const hits = [];
              for (let i = 0; i < nr; i++) for (let j = 0; j < nc; j++) {
                const v = (sheet.rows[r - 1 + i] || [])[c - 1 + j];
                if (!isEmpty(v) && re.test(String(v))) hits.push({ getRow: () => r + i, getColumn: () => c + j });
              }
              return hits;
            },
            findNext() { return finder.findAll()[0] || null; },
          };
          return finder;
        },
      };
    },
  };
  return sheet;
}

function makeCache() {
  const store = {};
  return {
    store,
    get: k => (k in store ? store[k] : null),
    getAll: keys => Object.fromEntries(keys.filter(k => k in store).map(k => [k, store[k]])),
    put: (k, v) => { if (String(v).length > 100000) throw new Error('cache value too large'); store[k] = String(v); },
    remove: k => { delete store[k]; },
    clear: () => Object.keys(store).forEach(k => delete store[k]),
  };
}

module.exports = { makeSheet, makeCache };

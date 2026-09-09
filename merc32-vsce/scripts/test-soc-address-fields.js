const assert = require('assert');
const fs = require('fs');
const path = require('path');
const soc = require('../out/soc');
const { buildSocDocumentUpdates, buildSocEditorViewModel } = require('../out/socEditorProvider');
const { buildJsonReplacement } = require('../out/socJsonEdits');
const catalog = soc.loadCatalog(path.resolve(__dirname, '../resources'));
const file = path.join(__dirname, 'fixtures/soc/multi-peripheral.merc32.json');
let text = fs.readFileSync(file, 'utf8');
function config() {
    const result = soc.parseSocConfig(text, file, catalog);
    assert.ok(result.config, JSON.stringify(result.diagnostics));
    return result.config;
}
function edit(field, value) {
    const updates = buildSocDocumentUpdates(config(), catalog, {
        type: value === undefined ? 'unsetValue' : 'setValue', documentVersion: 1,
        path: ['externalInterfaces', 0, field], ...(value === undefined ? {} : { value }),
    });
    assert.ok(updates, `Cannot edit ${field}`);
    const replacement = buildJsonReplacement(text, updates);
    text = text.slice(0, replacement.offset) + replacement.text + text.slice(replacement.offset + replacement.length);
    return config().externalInterfaces[0];
}
// Editing a legacy base must preserve its original end address.
let endpoint = edit('baseAddress', '0x10000000');
assert.strictEqual(endpoint.highAddress, '0x10004fff');
assert.strictEqual(endpoint.windowSize, 20480);
endpoint = edit('highAddress', '0x10005fff');
assert.strictEqual(endpoint.highAddress, '0x10005fff');
assert.strictEqual(endpoint.windowSize, 24576);
endpoint = edit('highAddress', '0x0fffffff');
assert.strictEqual(endpoint.highAddress, '0x0fffffff');
assert.ok(soc.validateSocConfig(config(), catalog).some(d => d.path.at(-1) === 'highAddress'));
endpoint = edit('highAddress', undefined);
assert.strictEqual(endpoint.highAddress, undefined);
assert.strictEqual(endpoint.windowSize, undefined);
assert.strictEqual(buildSocEditorViewModel(text, file, 1, catalog).externalInterfacePresentation[0].highAddress, undefined);
edit('baseAddress', undefined);
endpoint = edit('highAddress', '0x10004fff');
assert.strictEqual(endpoint.highAddress, '0x10004fff');
assert.strictEqual(endpoint.baseAddress, undefined);
endpoint = edit('baseAddress', '0x10004000');
assert.strictEqual(endpoint.windowSize, 4096);

// Explicit addresses win over a stale or malformed legacy cache, in UI and generation.
const stale = config();
stale.externalInterfaces[0].windowSize = 'invalid';
text = JSON.stringify(stale);
assert.ok(config());
const plan = soc.planSoc(config(), catalog);
assert.ok(plan.plan, JSON.stringify(plan.diagnostics));
assert.strictEqual(plan.plan.externalInterfaces.find(p => p.name === 'apb_ext0').endAddress, 0x10004fffn);
delete stale.externalInterfaces[0].highAddress;
text = JSON.stringify(stale);
const view = buildSocEditorViewModel(text, file, 1, catalog);
assert.strictEqual(view.readOnly, false, 'Malformed legacy size must not lock address editing');
edit('highAddress', '0x10004fff');
assert.strictEqual(config().externalInterfaces[0].windowSize, 4096);
console.log('SoC independent address field regressions passed.');

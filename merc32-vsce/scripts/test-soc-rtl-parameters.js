const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { withOwnedTempRoot } = require('./test-owned-temp');
const soc = require('../out/soc');
const { parseRtlInterface } = require('../out/soc/rtlInterface');

const header = parseRtlInterface(`
    // module demo #(parameter FAKE = 99)();
    module other #(parameter IGNORE = 2)(); endmodule
    module demo #(
        parameter integer COUNT = 1_024,
        parameter [63:0] MASK = 64'h00_ff,
        parameter BINARY = 'b1010,
        parameter LABEL = "a,b // label"
    )(input wire [COUNT-1:0] data);
        localparam HIDDEN = 3;
    endmodule`, 'demo');
assert.deepStrictEqual(Object.keys(header.parameters), ['COUNT', 'MASK', 'BINARY', 'LABEL']);
assert.deepStrictEqual(Object.values(header.parameters).map(p => p.default), [1024, 255, 10, 'a,b // label']);
assert.throws(() => parseRtlInterface('module demo #(parameter COUNT = 1 << 4)(); endmodule', 'demo'),
    /Unsupported RTL default.*demo.COUNT/);
assert.throws(() => parseRtlInterface('module demo #(parameter COUNT = 64\'hffffffffffffffff)(); endmodule', 'demo'),
    /safe integer/);

withOwnedTempRoot('merc32-rtl-parameters-', root => {
    fs.cpSync(path.resolve(__dirname, '../resources/catalog'), path.join(root, 'catalog'), { recursive: true });
    fs.cpSync(path.resolve(__dirname, '../../rtl'), path.join(root, 'rtl'), { recursive: true });
    const uart = path.join(root, 'rtl/apb_uart/apb_uart.v');
    fs.writeFileSync(uart, fs.readFileSync(uart, 'utf8')
        .replace('50_000_000', "32'd24_000_000")
        .replace('parameter FIFO_DEPTH   = 8', 'parameter FIFO_DEPTH = 32, parameter NEW_SETTING = 7'));
    const qspi = path.join(root, 'rtl/apb_qspi/apb_qspi.v');
    fs.writeFileSync(qspi, fs.readFileSync(qspi, 'utf8').replace(/CS_COUNT/g, 'CHIP_SELECT_COUNT'));
    const catalog = soc.loadCatalog(root);
    assert.strictEqual(catalog.modules.get('apb_uart').parameters.SYS_CLK_FREQ.default, 24000000);
    assert.strictEqual(catalog.modules.get('apb_uart').parameters.FIFO_DEPTH.default, 32);
    assert.strictEqual(catalog.modules.get('apb_uart').parameters.NEW_SETTING.default, 7);
    assert.strictEqual(catalog.modules.get('apb_gpio').parameters.GPIO_WIDTH.default, 32);
    assert.strictEqual(catalog.modules.get('apb_sdio').parameters.BUS_WIDTH.default, 8);
    assert.strictEqual(catalog.modules.get('apb_qspi').parameters.CS_COUNT, undefined);
    assert.strictEqual(catalog.modules.get('apb_qspi').parameters.CHIP_SELECT_COUNT.default, 4);
    assert.deepStrictEqual(catalog.modules.get('apb_qspi').ports.find(p => p.name === 'qspi_cs_n').width,
        { parameter: 'CHIP_SELECT_COUNT' });
    const config = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/soc/minimal.merc32.json'), 'utf8'));
    config.peripherals = [
        { type: 'apb_uart', name: 'uart0', baseAddress: '0x10000000' },
        { type: 'apb_gpio', name: 'gpio0', baseAddress: '0x10001000', parameters: { GPIO_WIDTH: 12 } },
        { type: 'apb_sdio', name: 'sd0', baseAddress: '0x10002000', parameters: { BUS_WIDTH: 4 } },
    ];
    const parsed = soc.parseSocConfig(JSON.stringify(config), 'rtl-parameters.merc32.json', catalog);
    assert.ok(parsed.config, JSON.stringify(parsed.diagnostics));
    const planned = soc.planSoc(parsed.config, catalog);
    assert.ok(planned.plan, JSON.stringify(planned.diagnostics));
    const top = soc.renderSocTop(planned.plan);
    assert.match(top, /\.SYS_CLK_FREQ\s*\(24000000\)/);
    assert.match(top, /\.NEW_SETTING\s*\(7\)/);
    assert.deepStrictEqual(planned.plan.peripherals.find(p => p.name === 'gpio0').ports
        .filter(p => p.name.startsWith('gpio')).map(p => p.width), [12, 12, 12]);
    assert.deepStrictEqual(planned.plan.peripherals.find(p => p.name === 'sd0').ports
        .filter(p => p.name.includes('sd_dat')).map(p => p.width), [4, 4, 4]);
});
console.log('SoC RTL parameter regressions passed.');

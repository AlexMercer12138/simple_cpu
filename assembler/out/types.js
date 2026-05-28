"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DEFAULT_COMPILE_MODE = exports.COMPILE_MODES = exports.DEFAULT_OUTPUT_FORMAT = exports.OUTPUT_FORMATS = void 0;
exports.isOutputFormat = isOutputFormat;
exports.OUTPUT_FORMATS = ['verilog', 'coe', 'mif', 'hex', 'bin'];
exports.DEFAULT_OUTPUT_FORMAT = 'verilog';
exports.COMPILE_MODES = ['normal', 'print', 'debug'];
exports.DEFAULT_COMPILE_MODE = 'normal';
function isOutputFormat(value) {
    return Boolean(value && exports.OUTPUT_FORMATS.includes(value));
}
//# sourceMappingURL=types.js.map
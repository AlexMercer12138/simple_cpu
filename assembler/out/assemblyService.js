"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.assembleFile = assembleFile;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const assembler_1 = require("./assembler");
const outputFormatters_1 = require("./outputFormatters");
function assembleFile(sourceCode, sourceFileName, format, mode, outputDir) {
    const assembler = new assembler_1.SimpleCPUAssembler();
    const result = assembler.assemble(sourceCode);
    const baseName = path.basename(sourceFileName, path.extname(sourceFileName));
    const output = (0, outputFormatters_1.formatAssemblyOutput)(result.machineCodes, format, baseName);
    if (mode === 'print') {
        return {
            output: (0, outputFormatters_1.formatPrintOutput)(output, format),
            debugInfo: result,
        };
    }
    const dir = outputDir || path.dirname(sourceFileName);
    fs.mkdirSync(dir, { recursive: true });
    const outputFile = path.join(dir, `${baseName}${outputFormatters_1.OUTPUT_EXTENSIONS[format]}`);
    writeOutputFile(outputFile, output, format);
    if (mode === 'debug') {
        const sourceBase = path.join(dir, baseName);
        fs.writeFileSync(`${sourceBase}_label_table.txt`, result.debugSymbols, 'utf-8');
        fs.writeFileSync(`${sourceBase}_replaced.asm`, result.replacedCode, 'utf-8');
        return { output, outputFile, debugInfo: result };
    }
    return { output, outputFile };
}
function writeOutputFile(outputFile, output, format) {
    if (format === 'bin') {
        fs.writeFileSync(outputFile, output);
        return;
    }
    fs.writeFileSync(outputFile, output.toString(), 'utf-8');
}
//# sourceMappingURL=assemblyService.js.map
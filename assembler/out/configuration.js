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
exports.getAssemblerSettings = getAssemblerSettings;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const vscode = __importStar(require("vscode"));
const constants_1 = require("./constants");
const types_1 = require("./types");
function getAssemblerSettings(sourceFile) {
    const config = vscode.workspace.getConfiguration(constants_1.EXTENSION_CONFIG_SECTION);
    const rawOutputFormat = config.get('outputFormat', types_1.DEFAULT_OUTPUT_FORMAT);
    const customOutputPath = config.get('outputPath', '');
    return {
        outputFormat: (0, types_1.isOutputFormat)(rawOutputFormat) ? rawOutputFormat : types_1.DEFAULT_OUTPUT_FORMAT,
        outputDir: resolveOutputDir(sourceFile, customOutputPath),
    };
}
function resolveOutputDir(sourceFile, customPath) {
    if (!customPath) {
        return path.dirname(sourceFile);
    }
    const resolved = path.resolve(customPath);
    if (!fs.existsSync(resolved)) {
        fs.mkdirSync(resolved, { recursive: true });
    }
    return resolved;
}
//# sourceMappingURL=configuration.js.map
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
exports.AssemblyRunner = void 0;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const vscode = __importStar(require("vscode"));
const assemblyService_1 = require("./assemblyService");
const constants_1 = require("./constants");
const configuration_1 = require("./configuration");
class AssemblyRunner {
    constructor() {
        this.channel = vscode.window.createOutputChannel(constants_1.OUTPUT_CHANNEL_NAME);
    }
    run(file, mode) {
        try {
            const sourceCode = fs.readFileSync(file, 'utf-8');
            const { outputFormat, outputDir } = (0, configuration_1.getAssemblerSettings)(file);
            const result = (0, assemblyService_1.assembleFile)(sourceCode, file, outputFormat, mode, outputDir);
            this.showSuccess(mode, result);
        }
        catch (error) {
            this.showFailure(error);
        }
    }
    dispose() {
        this.channel.dispose();
    }
    showSuccess(mode, result) {
        if (mode === 'print') {
            this.channel.clear();
            this.channel.appendLine(result.output.toString());
            this.channel.show(true);
            vscode.window.showInformationMessage('汇编完成 (打印模式)');
            return;
        }
        if (mode === 'debug') {
            this.channel.clear();
            if (result.outputFile) {
                this.channel.appendLine(`输出文件: ${result.outputFile}`);
            }
            if (result.debugInfo) {
                this.channel.appendLine('\n=== 标签表 ===');
                this.channel.appendLine(result.debugInfo.debugSymbols);
                this.channel.appendLine('\n=== 替换标签后的代码 ===');
                this.channel.appendLine(result.debugInfo.replacedCode);
            }
            this.channel.show(true);
            vscode.window.showInformationMessage(`汇编完成 (调试模式): ${path.basename(result.outputFile || '')}`);
            return;
        }
        vscode.window.showInformationMessage(`汇编成功: ${path.basename(result.outputFile || '')}`);
    }
    showFailure(error) {
        const message = error instanceof Error ? error.message : String(error);
        vscode.window.showErrorMessage(`汇编失败: ${message}`);
        this.channel.clear();
        this.channel.appendLine(message);
        this.channel.show(true);
    }
}
exports.AssemblyRunner = AssemblyRunner;
//# sourceMappingURL=assemblyRunner.js.map
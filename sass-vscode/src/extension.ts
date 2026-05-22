import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { assembleFile } from './assembler';

let currentMode: 'normal' | 'print' | 'debug' = 'normal';

function getOutputFormat(): 'verilog' | 'coe' | 'mif' | 'hex' | 'bin' {
    const config = vscode.workspace.getConfiguration('sass-asm');
    return config.get('outputFormat', 'verilog');
}

function getOutputDir(sourceFile: string): string {
    const config = vscode.workspace.getConfiguration('sass-asm');
    const customPath = config.get<string>('outputPath', '');
    if (customPath) {
        const resolved = path.resolve(customPath);
        if (!fs.existsSync(resolved)) {
            fs.mkdirSync(resolved, { recursive: true });
        }
        return resolved;
    }
    return path.dirname(sourceFile);
}

function getActiveAsmFile(): string | null {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
        vscode.window.showWarningMessage('请先打开一个 .asm 文件');
        return null;
    }
    const doc = editor.document;
    if (doc.languageId !== 'sass-asm' && !doc.fileName.endsWith('.asm')) {
        vscode.window.showWarningMessage('当前文件不是 SASS 汇编文件');
        return null;
    }
    return doc.fileName;
}

function runAssembly(file: string, mode: 'normal' | 'print' | 'debug') {
    try {
        const sourceCode = fs.readFileSync(file, 'utf-8');
        const format = getOutputFormat();
        const outputDir = getOutputDir(file);
        const result = assembleFile(sourceCode, file, format, mode, outputDir);

        const channel = vscode.window.createOutputChannel('SASS Assembler');

        if (mode === 'print') {
            channel.clear();
            channel.appendLine(result.output as string);
            channel.show(true);
            vscode.window.showInformationMessage('汇编完成 (打印模式)');
        } else if (mode === 'debug') {
            channel.clear();
            if (result.outputFile) {
                channel.appendLine(`输出文件: ${result.outputFile}`);
            }
            if (result.debugInfo) {
                channel.appendLine('\n=== 标签表 ===');
                channel.appendLine(result.debugInfo.debugSymbols);
                channel.appendLine('\n=== 替换标签后的代码 ===');
                channel.appendLine(result.debugInfo.replacedCode);
            }
            channel.show(true);
            vscode.window.showInformationMessage(`汇编完成 (调试模式): ${path.basename(result.outputFile || '')}`);
        } else {
            vscode.window.showInformationMessage(`汇编成功: ${path.basename(result.outputFile || '')}`);
        }
    } catch (error: any) {
        const message = error.message || String(error);
        vscode.window.showErrorMessage(`汇编失败: ${message}`);
        const channel = vscode.window.createOutputChannel('SASS Assembler');
        channel.clear();
        channel.appendLine(message);
        channel.show(true);
    }
}

export function activate(context: vscode.ExtensionContext) {
    const compileCmd = vscode.commands.registerCommand('sass-asm.compile', () => {
        const file = getActiveAsmFile();
        if (file) {
            runAssembly(file, currentMode);
        }
    });

    const compilePrintCmd = vscode.commands.registerCommand('sass-asm.compilePrint', () => {
        const file = getActiveAsmFile();
        if (file) {
            runAssembly(file, 'print');
        }
    });

    const compileDebugCmd = vscode.commands.registerCommand('sass-asm.compileDebug', () => {
        const file = getActiveAsmFile();
        if (file) {
            runAssembly(file, 'debug');
        }
    });

    const selectModeCmd = vscode.commands.registerCommand('sass-asm.selectCompileMode', async () => {
        const items = [
            { label: '$(play) 正常模式', description: '编译并输出文件', value: 'normal' as const },
            { label: '$(output) 打印模式', description: '编译结果输出到面板', value: 'print' as const },
            { label: '$(bug) 调试模式', description: '编译并生成调试文件', value: 'debug' as const }
        ];
        const selected = await vscode.window.showQuickPick(items, {
            placeHolder: '选择编译模式 (当前: ' + (currentMode === 'normal' ? '正常' : currentMode === 'print' ? '打印' : '调试') + ')'
        });
        if (selected) {
            currentMode = selected.value;
            const modeName = selected.label.replace(/\$\(play\) /, '').replace(/\$\(output\) /, '').replace(/\$\(bug\) /, '');
            vscode.window.showInformationMessage(`编译模式已切换为: ${modeName}`);
        }
    });

    context.subscriptions.push(compileCmd, compilePrintCmd, compileDebugCmd, selectModeCmd);
}

export function deactivate() {}

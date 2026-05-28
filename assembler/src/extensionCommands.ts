import * as vscode from 'vscode';
import { AssemblyRunner } from './assemblyRunner';
import { COMMANDS } from './constants';
import { getActiveAsmFile } from './editor';
import { getCompileModeLabel, getCompileModeQuickPickItems, getCompileModeShortName } from './compileModes';
import { CompileMode, DEFAULT_COMPILE_MODE } from './types';

export function registerAssemblerCommands(runner: AssemblyRunner): vscode.Disposable[] {
    let currentMode: CompileMode = DEFAULT_COMPILE_MODE;

    const runActiveFile = (mode: CompileMode) => {
        const file = getActiveAsmFile();
        if (file) {
            runner.run(file, mode);
        }
    };

    return [
        vscode.commands.registerCommand(COMMANDS.compile, () => runActiveFile(currentMode)),
        vscode.commands.registerCommand(COMMANDS.compilePrint, () => runActiveFile('print')),
        vscode.commands.registerCommand(COMMANDS.compileDebug, () => runActiveFile('debug')),
        vscode.commands.registerCommand(COMMANDS.selectCompileMode, async () => {
            const selected = await vscode.window.showQuickPick(getCompileModeQuickPickItems(), {
                placeHolder: `选择编译模式 (当前: ${getCompileModeShortName(currentMode)})`,
            });
            if (selected) {
                currentMode = selected.value;
                vscode.window.showInformationMessage(`编译模式已切换为: ${getCompileModeLabel(currentMode)}`);
            }
        }),
    ];
}

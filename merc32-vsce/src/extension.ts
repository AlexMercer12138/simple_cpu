import * as vscode from 'vscode';
import { AssemblyRunner } from './assemblyRunner';
import { registerAssemblerCommands, ToolchainCommandState } from './extensionCommands';
import { Merc32ToolchainExplorer } from './toolchainExplorer';
import { DEFAULT_COMPILE_MODE } from './types';

export function activate(context: vscode.ExtensionContext) {
    const runner = new AssemblyRunner();
    const state: ToolchainCommandState = {
        currentMode: DEFAULT_COMPILE_MODE,
        artifacts: [],
    };
    const explorer = new Merc32ToolchainExplorer(state);
    context.subscriptions.push(
        runner,
        vscode.window.registerTreeDataProvider('merc32-toolchain.build', explorer),
        ...registerAssemblerCommands(runner, state, () => explorer.refresh()),
    );
}

export function deactivate() {}

import * as vscode from 'vscode';
import { AssemblyRunner } from './assemblyRunner';
import { registerAssemblerCommands } from './extensionCommands';

export function activate(context: vscode.ExtensionContext) {
    const runner = new AssemblyRunner();
    context.subscriptions.push(runner, ...registerAssemblerCommands(runner));
}

export function deactivate() {}

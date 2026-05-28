import * as vscode from 'vscode';
import { ASSEMBLY_FILE_EXTENSION, LANGUAGE_ID } from './constants';

export function getActiveAsmFile(): string | undefined {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
        vscode.window.showWarningMessage('请先打开一个 .asm 文件');
        return undefined;
    }

    const doc = editor.document;
    if (doc.languageId !== LANGUAGE_ID && !doc.fileName.toLowerCase().endsWith(ASSEMBLY_FILE_EXTENSION)) {
        vscode.window.showWarningMessage('当前文件不是 MERC32 汇编文件');
        return undefined;
    }

    return doc.fileName;
}

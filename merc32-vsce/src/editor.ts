import * as vscode from 'vscode';
import { ASSEMBLY_FILE_EXTENSION, C_FILE_EXTENSION, C_LANGUAGE_ID, LANGUAGE_ID } from './constants';

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

export function getActiveCFile(): string | undefined {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
        vscode.window.showWarningMessage('Please open a .c file first');
        return undefined;
    }

    const doc = editor.document;
    if (doc.languageId !== C_LANGUAGE_ID && !doc.fileName.toLowerCase().endsWith(C_FILE_EXTENSION)) {
        vscode.window.showWarningMessage('Current file is not a MERC32 C source file');
        return undefined;
    }

    return doc.fileName;
}

export function getActiveMerc32SourceFile(): { file: string; kind: 'asm' | 'c' } | undefined {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
        vscode.window.showWarningMessage('Please open a MERC32 .asm or .c file first');
        return undefined;
    }

    const doc = editor.document;
    const lower = doc.fileName.toLowerCase();
    if (doc.languageId === LANGUAGE_ID || lower.endsWith(ASSEMBLY_FILE_EXTENSION)) {
        return { file: doc.fileName, kind: 'asm' };
    }
    if (doc.languageId === C_LANGUAGE_ID || lower.endsWith(C_FILE_EXTENSION)) {
        return { file: doc.fileName, kind: 'c' };
    }

    vscode.window.showWarningMessage('Current file is not a MERC32 .asm or .c source file');
    return undefined;
}

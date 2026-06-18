import * as vscode from 'vscode';
import { COMPILE_MODES, CompileMode } from './types';

interface CompileModeView {
    icon: string;
    label: string;
    shortName: string;
    description: string;
}

export interface CompileModeQuickPickItem extends vscode.QuickPickItem {
    value: CompileMode;
}

const COMPILE_MODE_VIEW: Record<CompileMode, CompileModeView> = {
    normal: {
        icon: '$(play)',
        label: '正常模式',
        shortName: '正常',
        description: '编译并输出文件',
    },
    print: {
        icon: '$(output)',
        label: '打印模式',
        shortName: '打印',
        description: '编译结果输出到面板',
    },
    debug: {
        icon: '$(bug)',
        label: '调试模式',
        shortName: '调试',
        description: '编译并生成调试文件',
    },
};

export function getCompileModeShortName(mode: CompileMode): string {
    return COMPILE_MODE_VIEW[mode].shortName;
}

export function getCompileModeLabel(mode: CompileMode): string {
    return COMPILE_MODE_VIEW[mode].label;
}

export function getCompileModeQuickPickItems(): CompileModeQuickPickItem[] {
    return COMPILE_MODES.map((mode) => {
        const view = COMPILE_MODE_VIEW[mode];
        return {
            label: `${view.icon} ${view.label}`,
            description: view.description,
            value: mode,
        };
    });
}

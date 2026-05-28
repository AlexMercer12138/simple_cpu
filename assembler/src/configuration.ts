import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import { EXTENSION_CONFIG_SECTION } from './constants';
import { DEFAULT_OUTPUT_FORMAT, isOutputFormat, OutputFormat } from './types';

export interface AssemblerSettings {
    outputFormat: OutputFormat;
    outputDir: string;
}

export function getAssemblerSettings(sourceFile: string): AssemblerSettings {
    const config = vscode.workspace.getConfiguration(EXTENSION_CONFIG_SECTION);
    const rawOutputFormat = config.get<string>('outputFormat', DEFAULT_OUTPUT_FORMAT);
    const customOutputPath = config.get<string>('outputPath', '');

    return {
        outputFormat: isOutputFormat(rawOutputFormat) ? rawOutputFormat : DEFAULT_OUTPUT_FORMAT,
        outputDir: resolveOutputDir(sourceFile, customOutputPath),
    };
}

function resolveOutputDir(sourceFile: string, customPath: string): string {
    if (!customPath) {
        return path.dirname(sourceFile);
    }

    const resolved = path.resolve(customPath);
    if (!fs.existsSync(resolved)) {
        fs.mkdirSync(resolved, { recursive: true });
    }
    return resolved;
}

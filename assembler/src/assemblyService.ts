import * as fs from 'fs';
import * as path from 'path';
import { SimpleCPUAssembler } from './assembler';
import { formatAssemblyOutput, formatPrintOutput, OUTPUT_EXTENSIONS } from './outputFormatters';
import { CompileMode, FileAssemblyResult, OutputFormat } from './types';

export function assembleFile(
    sourceCode: string,
    sourceFileName: string,
    format: OutputFormat,
    mode: CompileMode,
    outputDir?: string,
): FileAssemblyResult {
    const assembler = new SimpleCPUAssembler();
    const result = assembler.assemble(sourceCode, { sourceFileName });
    const baseName = result.programName || path.basename(sourceFileName, path.extname(sourceFileName));
    const output = formatAssemblyOutput(result.machineCodes, format, baseName);

    if (mode === 'print') {
        return {
            output: formatPrintOutput(output, format),
            debugInfo: result,
        };
    }

    const dir = outputDir || path.dirname(sourceFileName);
    fs.mkdirSync(dir, { recursive: true });

    const outputFile = path.join(dir, `${baseName}${OUTPUT_EXTENSIONS[format]}`);
    writeOutputFile(outputFile, output, format);

    if (mode === 'debug') {
        const sourceBase = path.join(dir, baseName);
        fs.writeFileSync(`${sourceBase}_label_table.txt`, result.debugSymbols, 'utf-8');
        fs.writeFileSync(`${sourceBase}_replaced.asm`, result.replacedCode, 'utf-8');
        return { output, outputFile, debugInfo: result };
    }

    return { output, outputFile };
}

function writeOutputFile(outputFile: string, output: string | Buffer, format: OutputFormat): void {
    if (format === 'bin') {
        fs.writeFileSync(outputFile, output as Buffer);
        return;
    }

    fs.writeFileSync(outputFile, output.toString(), 'utf-8');
}

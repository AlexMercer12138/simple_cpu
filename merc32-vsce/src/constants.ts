export const EXTENSION_CONFIG_SECTION = 'merc32-asm';
export const LANGUAGE_ID = 'merc32-asm';
export const C_LANGUAGE_ID = 'c';
export const ASSEMBLY_FILE_EXTENSION = '.asm';
export const C_FILE_EXTENSION = '.c';
export const OUTPUT_CHANNEL_NAME = 'MERC32 Toolchain';

export const COMMANDS = {
    compile: 'merc32-asm.compile',
    compilePrint: 'merc32-asm.compilePrint',
    compileDebug: 'merc32-asm.compileDebug',
    selectCompileMode: 'merc32-asm.selectCompileMode',
    assembleActive: 'merc32-asm.assembleActive',
    compileCToAsm: 'merc32-asm.compileCToAsm',
    buildCToRom: 'merc32-asm.buildCToRom',
    openLastArtifact: 'merc32-asm.openLastArtifact',
    refreshExplorer: 'merc32-asm.refreshExplorer',
} as const;

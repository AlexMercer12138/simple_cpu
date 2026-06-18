import * as path from 'path';
import * as vscode from 'vscode';
import { COMMANDS } from './constants';
import { ToolchainCommandState } from './extensionCommands';
import { ToolchainArtifact } from './types';

type NodeKind = 'group' | 'command' | 'artifact' | 'info';

interface NodeSpec {
    label: string;
    kind: NodeKind;
    description?: string;
    icon?: string;
    command?: vscode.Command;
    children?: NodeSpec[];
}

export class Merc32ToolchainExplorer implements vscode.TreeDataProvider<NodeSpec> {
    private readonly changeEmitter = new vscode.EventEmitter<NodeSpec | undefined | null | void>();
    readonly onDidChangeTreeData = this.changeEmitter.event;

    constructor(private readonly state: ToolchainCommandState) {}

    refresh(): void {
        this.changeEmitter.fire();
    }

    getTreeItem(element: NodeSpec): vscode.TreeItem {
        const collapsibleState = element.children
            ? vscode.TreeItemCollapsibleState.Expanded
            : vscode.TreeItemCollapsibleState.None;
        const item = new vscode.TreeItem(element.label, collapsibleState);
        item.description = element.description;
        item.command = element.command;
        if (element.icon) {
            item.iconPath = new vscode.ThemeIcon(element.icon);
        }
        return item;
    }

    getChildren(element?: NodeSpec): NodeSpec[] {
        if (element) {
            return element.children || [];
        }

        return [
            this.buildGroup(),
            this.artifactsGroup(),
        ];
    }

    private buildGroup(): NodeSpec {
        return {
            label: 'Build',
            kind: 'group',
            icon: 'tools',
            children: [
                commandNode('Build Active File', COMMANDS.compile, 'Run default build for .c or .asm', 'play'),
                commandNode('Assemble ASM', COMMANDS.assembleActive, 'Assemble active .asm file', 'file-binary'),
                commandNode('Compile C to ASM', COMMANDS.compileCToAsm, 'Emit MERC32 assembly from active .c file', 'file-code'),
                commandNode('Build C to ROM', COMMANDS.buildCToRom, 'Compile C and assemble configured output', 'package'),
                commandNode('Select Compile Mode', COMMANDS.selectCompileMode, `Current: ${this.state.currentMode}`, 'settings-gear'),
            ],
        };
    }

    private artifactsGroup(): NodeSpec {
        const children = this.state.artifacts.length
            ? this.state.artifacts.map((artifact) => artifactNode(artifact))
            : [infoNode('No artifacts yet', 'Run a build to populate this list')];

        return {
            label: 'Artifacts',
            kind: 'group',
            icon: 'folder-library',
            children,
        };
    }

}

function commandNode(label: string, command: string, description: string, icon: string): NodeSpec {
    return {
        label,
        kind: 'command',
        description,
        icon,
        command: { command, title: label },
    };
}

function artifactNode(artifact: ToolchainArtifact): NodeSpec {
    return {
        label: artifact.label || path.basename(artifact.file),
        kind: 'artifact',
        description: artifact.description || artifact.file,
        icon: 'file',
        command: {
            command: COMMANDS.openLastArtifact,
            title: 'Open Artifact',
            arguments: [artifact],
        },
    };
}

function infoNode(label: string, description: string): NodeSpec {
    return {
        label,
        kind: 'info',
        description,
        icon: 'info',
    };
}

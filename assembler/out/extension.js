"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.activate = activate;
exports.deactivate = deactivate;
const assemblyRunner_1 = require("./assemblyRunner");
const extensionCommands_1 = require("./extensionCommands");
function activate(context) {
    const runner = new assemblyRunner_1.AssemblyRunner();
    context.subscriptions.push(runner, ...(0, extensionCommands_1.registerAssemblerCommands)(runner));
}
function deactivate() { }
//# sourceMappingURL=extension.js.map
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getCompileModeShortName = getCompileModeShortName;
exports.getCompileModeLabel = getCompileModeLabel;
exports.getCompileModeQuickPickItems = getCompileModeQuickPickItems;
const types_1 = require("./types");
const COMPILE_MODE_VIEW = {
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
function getCompileModeShortName(mode) {
    return COMPILE_MODE_VIEW[mode].shortName;
}
function getCompileModeLabel(mode) {
    return COMPILE_MODE_VIEW[mode].label;
}
function getCompileModeQuickPickItems() {
    return types_1.COMPILE_MODES.map((mode) => {
        const view = COMPILE_MODE_VIEW[mode];
        return {
            label: `${view.icon} ${view.label}`,
            description: view.description,
            value: mode,
        };
    });
}
//# sourceMappingURL=compileModes.js.map
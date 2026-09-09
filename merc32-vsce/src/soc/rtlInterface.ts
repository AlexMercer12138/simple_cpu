import { CatalogParameter, CatalogPort } from './model';

/** Read the public ANSI module header, never implementation localparams or nested modules. */
export function parseRtlInterface(source: string, moduleName: string): {
    parameters: Record<string, CatalogParameter>;
    ports: ReadonlyMap<string, CatalogPort>;
} {
    const text = source.replace(/"(?:\\.|[^"\\])*"|\/\/[^\r\n]*|\/\*[\s\S]*?\*\//g,
        token => token.startsWith('"') ? token : ' ');
    const declaration = new RegExp(`\\bmodule\\s+${moduleName}\\b`).exec(text);
    if (!declaration) throw new Error(`Missing RTL module ${moduleName}`);
    let rest = text.slice(declaration.index + declaration[0].length).trimStart();
    const parameters: Record<string, CatalogParameter> = Object.create(null);
    if (rest.startsWith('#')) {
        const list = takeGroup(rest.slice(1).trimStart());
        for (const entry of splitDeclarations(list.body)) {
            const match = /^(?:parameter\s+)?(?:(?:integer|int|logic|reg|bit|string|signed|unsigned)\s+)*(?:\[[^\]]+\]\s*)?([A-Za-z_][A-Za-z0-9_$]*)\s*=\s*([\s\S]+)$/.exec(entry.trim());
            if (!match) throw new Error(`Unsupported RTL parameter in ${moduleName}: ${entry.trim()}`);
            const [, name, expression] = match;
            if (Object.prototype.hasOwnProperty.call(parameters, name)) throw new Error(`Duplicate RTL parameter ${moduleName}.${name}`);
            const value = parseLiteral(expression.trim(), `${moduleName}.${name}`);
            parameters[name] = { type: typeof value === 'string' ? 'string' : 'integer', default: value };
        }
        rest = list.rest.trimStart();
    }
    const ports = new Map<string, CatalogPort>();
    if (rest.startsWith('(')) {
        const list = takeGroup(rest);
        for (const entry of splitDeclarations(list.body)) {
            const match = /^(input|output|inout)\s+(?:(?:wire|reg|logic|signed|unsigned)\s+)*(?:\[([^\]]+)\]\s*)?([A-Za-z_][A-Za-z0-9_$]*)$/.exec(entry.trim());
            if (!match) throw new Error(`Unsupported RTL port in ${moduleName}: ${entry.trim()}`);
            const [, direction, range, name] = match;
            let width: CatalogPort['width'] = 1;
            if (range) {
                const dynamic = /^\s*([A-Za-z_][A-Za-z0-9_$]*)\s*-\s*1\s*:\s*0\s*$/.exec(range);
                if (dynamic && Object.prototype.hasOwnProperty.call(parameters, dynamic[1])) {
                    width = { parameter: dynamic[1] };
                } else {
                    const bounds = range.split(':').map(value => parseLiteral(value.trim(), `${moduleName}.${name} width`));
                    if (bounds.length !== 2 || bounds.some(value => typeof value !== 'number')) {
                        throw new Error(`Unsupported RTL port range ${moduleName}.${name}: ${range}`);
                    }
                    width = Math.abs((bounds[0] as number) - (bounds[1] as number)) + 1;
                }
            }
            ports.set(name, { name, direction: direction as CatalogPort['direction'], width });
        }
        if (!list.rest.trimStart().startsWith(';')) throw new Error(`Invalid RTL header for ${moduleName}`);
    } else if (!rest.startsWith(';')) {
        throw new Error(`Invalid RTL header for ${moduleName}`);
    }
    return { parameters, ports };
}

function parseLiteral(expression: string, label: string): number | string {
    if (/^"(?:[^"\\]|\\["\\nrt])*"$/.test(expression)) return JSON.parse(expression) as string;
    const decimal = /^\+?[0-9][0-9_]*$/.test(expression);
    const based = /^(?:([0-9][0-9_]*)\s*)?'([sS]?)([bBoOdDhH])\s*([0-9a-fA-F_]+)$/.exec(expression);
    let value: bigint;
    if (decimal) {
        value = BigInt(expression.replace(/_/g, ''));
    } else if (based) {
        const radix = based[3].toLowerCase();
        const digits = based[4].replace(/_/g, '');
        const valid = { b: /^[01]+$/, o: /^[0-7]+$/, d: /^[0-9]+$/, h: /^[0-9a-f]+$/i }[radix]!;
        if (!valid.test(digits)) throw new Error(`Invalid RTL literal ${label}: ${expression}`);
        value = BigInt(({ b: '0b', o: '0o', d: '', h: '0x' }[radix] ?? '') + digits);
        if (based[1]) {
            const bits = Number(based[1].replace(/_/g, ''));
            if (!Number.isSafeInteger(bits) || bits < 1 || bits > 65536) throw new Error(`Invalid RTL literal width: ${label}`);
            value = BigInt.asUintN(bits, value);
            if (based[2]) value = BigInt.asIntN(bits, value);
        }
    } else {
        throw new Error(`Unsupported RTL default for ${label}: ${expression}. Expected a constant integer or string literal.`);
    }
    if (value < 0n || value > BigInt(Number.MAX_SAFE_INTEGER)) {
        throw new Error(`RTL default for ${label} must be a non-negative safe integer`);
    }
    return Number(value);
}

function takeGroup(text: string): { body: string; rest: string } {
    if (!text.startsWith('(')) throw new Error('Expected RTL header parenthesis');
    let depth = 0;
    let quoted = false;
    for (let index = 0; index < text.length; index++) {
        const char = text[index];
        if (quoted && char === '\\') { index++; continue; }
        if (char === '"') quoted = !quoted;
        if (quoted) continue;
        if (char === '(') depth++;
        if (char === ')' && --depth === 0) return { body: text.slice(1, index), rest: text.slice(index + 1) };
    }
    throw new Error('Unclosed RTL header parenthesis');
}

function splitDeclarations(text: string): string[] {
    if (!text.trim()) return [];
    const entries: string[] = [];
    let start = 0;
    let depth = 0;
    let quoted = false;
    for (let index = 0; index < text.length; index++) {
        const char = text[index];
        if (quoted && char === '\\') { index++; continue; }
        if (char === '"') quoted = !quoted;
        if (quoted) continue;
        if ('([{'.includes(char)) depth++;
        if (')]}'.includes(char)) depth--;
        if (char === ',' && depth === 0) { entries.push(text.slice(start, index)); start = index + 1; }
    }
    entries.push(text.slice(start));
    return entries;
}

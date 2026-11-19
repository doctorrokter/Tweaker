// The rare alphabets tweak's data (docs/TWEAKS.md, "Rare alphabets"): which fonts go into the phone's composite font lists and
// which characters each of them draws there. Run with Node on the PC:
//
//   node tools/script-fonts.js coverage <a SlatePro-*_Color.cfr from the phone>
//       what the phone's own components name, into scriptfonts/phone-coverage.txt (the phone's file stays out of the repo)
//   node tools/script-fonts.js make <a folder of Noto *-Regular.ttf> [--copy-to <folder>]
//       each font gets the characters it has that neither the phone nor a font before it has; fonts that add nothing, and
//       LEFT_OUT, are left out. Writes scriptfonts/components.cfr-part, scriptfonts/REPORT.md, scriptfonts/samples.txt
//       (a line of each font's letters, to paste into a chat and look at on the phone) and the same as
//       assets/scriptsamples.json for the app's "What it adds" page; --copy-to also puts the chosen fonts
//       into that folder in place of what is there (the package takes them from E:\dev\blackberry\noto-scripts).
//
// The order decides who draws a character two fonts have: each script's own font first (by name), the general ones last
// (GENERAL_LAST). Below U+0300 nothing is taken: Latin, IPA and their marks are the phone's.

const fs = require('fs');
const path = require('path');

const TWEAKER = path.resolve(__dirname, '..');
const SCRIPTFONTS = path.join(TWEAKER, 'scriptfonts');
const COVERAGE_FILE = path.join(SCRIPTFONTS, 'phone-coverage.txt');
const BLOCKS_FILE = path.join(__dirname, 'unicode', 'Blocks.txt');
const GENERAL_LAST = ['NotoSansSymbols', 'NotoSansSymbols2', 'NotoSansMath', 'NotoMusic', 'NotoSans'];
// Megabytes for writing almost nobody sends (2026-11-19).
const LEFT_OUT = {
    NotoSansSignWriting: 'sign language notation, 5 MB, its own positioning',
    NotoSerifTangut: 'a dead script, 3 MB',
    NotoSansDuployan: 'shorthand, 1.5 MB, its own positioning',
};
// Words for the scripts whose letters join or reorder: a row of loose letters would not show whether the phone builds them.
const SAMPLE_WORDS = {
    NotoSansKhmer: 'ភាសាខ្មែរ',
    NotoSansLao: 'ພາສາລາວ',
    NotoSansMyanmar: 'မြန်မာဘာသာ',
    NotoSerifTibetan: 'བོད་ཡིག',
    NotoSansMongolian: 'ᠮᠣᠩᠭᠣᠯ ᠪᠢᠴᠢᠭ',
    NotoSansOriya: 'ଓଡ଼ିଆ',
    NotoSansJavanese: 'ꦧꦱꦗꦮ',
    NotoSansBalinese: 'ᬪᬵᬲᬩᬮᬶ',
    NotoSansSyriac: 'ܠܫܢܐ ܣܘܪܝܝܐ',
    NotoSansThaana: 'ދިވެހި',
    NotoSansTaiTham: 'ᨽᩣᩈᩣᨴᩱ',
    NotoSansSundanese: 'ᮘᮞ ᮞᮥᮔ᮪ᮓ',
    NotoSansEgyptianHieroglyphs: '𓆉 𓆏 𓃰 𓀀 𓂀',
    // The fancy text kinds: a row of math symbols would hide them.
    NotoSansMath: '𝓑𝓵𝓪𝓬𝓴𝓑𝓮𝓻𝓻𝔂 𝔅𝔩𝔞𝔠𝔨 𝐁𝐥𝐚𝐜𝐤 𝙱𝚕𝚊𝚌𝚔',
    NotoSansSymbols: '🄱🄻🄰🄲🄺 🅑🅛🅐🅒🅚',
};

// ---------------------------------------------------------------- font files

function readTables(data) {
    const tables = {};
    const tableCount = data.readUInt16BE(4);
    for (let index = 0; index < tableCount; index++) {
        const record = 12 + index * 16;
        tables[data.toString('latin1', record, record + 4)] = data.readUInt32BE(record + 8);
    }
    return tables;
}

// Every code point the font maps to a glyph (cmap formats 4 and 12).
function readCodePoints(data) {
    const cmap = readTables(data).cmap;
    const codePoints = new Set();
    const subtableCount = data.readUInt16BE(cmap + 2);
    for (let index = 0; index < subtableCount; index++) {
        const record = cmap + 4 + index * 8;
        const platform = data.readUInt16BE(record);
        const subtable = cmap + data.readUInt32BE(record + 4);
        const format = data.readUInt16BE(subtable);
        if (platform !== 0 && platform !== 3) {
            continue;
        }
        if (format === 12) {
            const groupCount = data.readUInt32BE(subtable + 12);
            for (let group = 0; group < groupCount; group++) {
                const at = subtable + 16 + group * 12;
                const last = data.readUInt32BE(at + 4);
                for (let codePoint = data.readUInt32BE(at); codePoint <= last; codePoint++) {
                    codePoints.add(codePoint);
                }
            }
        } else if (format === 4) {
            const segmentCount = data.readUInt16BE(subtable + 6) / 2;
            const ends = subtable + 14;
            const starts = ends + segmentCount * 2 + 2;
            const deltas = starts + segmentCount * 2;
            const rangeOffsets = deltas + segmentCount * 2;
            for (let segment = 0; segment < segmentCount; segment++) {
                const end = data.readUInt16BE(ends + segment * 2);
                const start = data.readUInt16BE(starts + segment * 2);
                const delta = data.readInt16BE(deltas + segment * 2);
                const rangeOffset = data.readUInt16BE(rangeOffsets + segment * 2);
                for (let codePoint = start; codePoint <= end && codePoint !== 0xffff; codePoint++) {
                    let glyph = 0;
                    if (rangeOffset === 0) {
                        glyph = (codePoint + delta) & 0xffff;
                    } else {
                        glyph = data.readUInt16BE(rangeOffsets + segment * 2 + rangeOffset + (codePoint - start) * 2);
                        if (glyph !== 0) {
                            glyph = (glyph + delta) & 0xffff;
                        }
                    }
                    if (glyph !== 0) {
                        codePoints.add(codePoint);
                    }
                }
            }
        }
    }
    return codePoints;
}

// The family name (name ID 1, Windows Unicode).
function readFamilyName(data) {
    const table = readTables(data).name;
    const count = data.readUInt16BE(table + 2);
    const strings = table + data.readUInt16BE(table + 4);
    for (let entry = 0; entry < count; entry++) {
        const at = table + 6 + entry * 12;
        if (data.readUInt16BE(at) === 3 && data.readUInt16BE(at + 6) === 1) {
            const offset = strings + data.readUInt16BE(at + 10);
            const bytes = Buffer.from(data.subarray(offset, offset + data.readUInt16BE(at + 8)));
            bytes.swap16();
            return bytes.toString('utf16le');
        }
    }
    throw new Error('no family name');
}

// ---------------------------------------------------------------- ranges

function parseUsetRanges(text) {
    const ranges = [];
    const pattern = /\[\\u([0-9a-f]+)(?:-\\u([0-9a-f]+))?\]/gi;
    let match;
    while ((match = pattern.exec(text)) !== null) {
        const first = parseInt(match[1], 16);
        ranges.push([first, match[2] ? parseInt(match[2], 16) : first]);
    }
    return ranges;
}

function toRanges(sortedCodePoints) {
    const ranges = [];
    for (const codePoint of sortedCodePoints) {
        const last = ranges[ranges.length - 1];
        if (last && codePoint === last[1] + 1) {
            last[1] = codePoint;
        } else {
            ranges.push([codePoint, codePoint]);
        }
    }
    return ranges;
}

function hex(codePoint) {
    return codePoint.toString(16);
}

function rangesToUset(ranges) {
    return '[ ' + ranges.map(function (range) {
        if (range[0] === range[1]) {
            return '[\\u' + hex(range[0]) + ']';
        }
        return '[\\u' + hex(range[0]) + '-\\u' + hex(range[1]) + ']';
    }).join(' ') + ' ]';
}

function readCoverage() {
    const covered = new Set();
    for (const line of fs.readFileSync(COVERAGE_FILE, 'utf8').split('\n')) {
        const match = line.match(/^([0-9a-f]+)(?:-([0-9a-f]+))?$/i);
        if (!match) {
            continue;
        }
        const first = parseInt(match[1], 16);
        const last = match[2] ? parseInt(match[2], 16) : first;
        for (let codePoint = first; codePoint <= last; codePoint++) {
            covered.add(codePoint);
        }
    }
    return covered;
}

function readBlocks() {
    const blocks = [];
    for (const line of fs.readFileSync(BLOCKS_FILE, 'utf8').split('\n')) {
        const match = line.match(/^([0-9A-F]+)\.\.([0-9A-F]+); (.+?)\s*$/);
        if (match) {
            blocks.push({ first: parseInt(match[1], 16), last: parseInt(match[2], 16), name: match[3] });
        }
    }
    return blocks;
}

function blockOf(blocks, codePoint) {
    for (const block of blocks) {
        if (codePoint >= block.first && codePoint <= block.last) {
            return block;
        }
    }
    return null;
}

// ---------------------------------------------------------------- commands

function coverage(listPath) {
    const ranges = parseUsetRanges(fs.readFileSync(listPath, 'utf8'));
    const covered = new Set();
    for (const range of ranges) {
        for (let codePoint = range[0]; codePoint <= range[1]; codePoint++) {
            covered.add(codePoint);
        }
    }
    const merged = toRanges(Array.from(covered).sort(function (a, b) { return a - b; }));
    const lines = ['# What the phone\'s own components of SlatePro-Regular_Color.cfr name (tools/script-fonts.js coverage), one range a line.'];
    for (const range of merged) {
        lines.push(range[0] === range[1] ? hex(range[0]) : hex(range[0]) + '-' + hex(range[1]));
    }
    fs.writeFileSync(COVERAGE_FILE, lines.join('\n') + '\n');
    console.log(COVERAGE_FILE + ': ' + covered.size + ' code points in ' + merged.length + ' ranges');
}

function familyOrder(fileName) {
    const family = fileName.replace(/-Regular\.ttf$/, '');
    const general = GENERAL_LAST.indexOf(family);
    return general < 0 ? '0 ' + family : '1 ' + String(general).padStart(2, '0');
}

function make(fontsFolder, copyTo) {
    const covered = readCoverage();
    const blocks = readBlocks();
    const files = fs.readdirSync(fontsFolder).filter(function (name) { return name.endsWith('-Regular.ttf'); });
    files.sort(function (a, b) { return familyOrder(a) < familyOrder(b) ? -1 : 1; });

    const claimed = new Set();
    const chosen = [];
    const leftOut = [];
    for (const file of files) {
        if (LEFT_OUT[file.replace(/-Regular\.ttf$/, '')]) {
            continue;
        }
        const data = fs.readFileSync(path.join(fontsFolder, file));
        const added = Array.from(readCodePoints(data)).filter(function (codePoint) {
            return codePoint >= 0x300 && !covered.has(codePoint) && !claimed.has(codePoint);
        }).sort(function (a, b) { return a - b; });
        if (added.length === 0) {
            leftOut.push(file);
            continue;
        }
        added.forEach(function (codePoint) { claimed.add(codePoint); });
        chosen.push({ file: file, family: readFamilyName(data), bytes: data.length, added: added });
    }

    const part = [];
    for (const font of chosen) {
        part.push('        <ComponentDef locationHint="' + font.file + '" name="' + font.family + '">');
        part.push('        <UnicodeCharSet uset="' + rangesToUset(toRanges(font.added)) + '" />');
        part.push('        </ComponentDef>');
    }
    fs.writeFileSync(path.join(SCRIPTFONTS, 'components.cfr-part'), part.join('\n') + '\n');

    // The report: per font, then per block what the fonts add there.
    const totalBytes = chosen.reduce(function (sum, font) { return sum + font.bytes; }, 0);
    const report = ['# Rare alphabets: what the fonts add', '',
        'Made by `tools/script-fonts.js make` from `phone-coverage.txt` (the Passport\'s SlatePro-Regular_Color.cfr) and Unicode ' +
        fs.readFileSync(BLOCKS_FILE, 'utf8').split('\n')[0].replace(/^# Blocks-|\.txt.*$/g, '') + '. ' + chosen.length + ' fonts, ' +
        (totalBytes / 1048576).toFixed(1) + ' MB, ' + claimed.size + ' characters the phone did not have.', '',
        '| Font | KB | Characters added | Blocks |', '|---|---|---|---|'];
    for (const font of chosen) {
        const names = [];
        for (const codePoint of font.added) {
            const block = blockOf(blocks, codePoint);
            const name = block ? block.name : '?';
            if (names.indexOf(name) < 0) {
                names.push(name);
            }
        }
        report.push('| ' + font.family + ' | ' + Math.round(font.bytes / 1024) + ' | ' + font.added.length + ' | ' + names.join(', ') + ' |');
    }
    report.push('', 'Left out, nothing to add: ' + (leftOut.length > 0 ? leftOut.join(', ') : 'none') + '.', '');
    report.push('Left out on purpose: ' + Object.keys(LEFT_OUT).map(function (family) { return family + ' (' + LEFT_OUT[family] + ')'; }).join(', ') + '.', '');
    fs.writeFileSync(path.join(SCRIPTFONTS, 'REPORT.md'), report.join('\n'));

    // A line per font: a word where joining matters, else up to ten of the letters it adds (marks and spaces skipped).
    const samples = [];
    for (const font of chosen) {
        const family = font.file.replace(/-Regular\.ttf$/, '');
        let text = SAMPLE_WORDS[family];
        if (!text) {
            text = font.added.filter(function (codePoint) {
                return /\p{L}|\p{N}|\p{S}/u.test(String.fromCodePoint(codePoint));
            }).slice(0, 10).map(function (codePoint) { return String.fromCodePoint(codePoint); }).join('');
        }
        samples.push(font.family.replace(/^Noto (Sans|Serif) /, '') + ': ' + text);
    }
    fs.writeFileSync(path.join(SCRIPTFONTS, 'samples.txt'), samples.join('\n') + '\n');
    // The same for the app's "What it adds" page: drawn there by the phone itself.
    const appSamples = samples.map(function (line) {
        const colon = line.indexOf(': ');
        return { name: line.substring(0, colon), sample: line.substring(colon + 2) };
    });
    fs.writeFileSync(path.join(TWEAKER, 'assets', 'scriptsamples.json'), JSON.stringify(appSamples, null, 1) + '\n');

    if (copyTo) {
        fs.mkdirSync(copyTo, { recursive: true });
        for (const old of fs.readdirSync(copyTo).filter(function (name) { return name.endsWith('.ttf'); })) {
            fs.unlinkSync(path.join(copyTo, old));
        }
        for (const font of chosen) {
            fs.copyFileSync(path.join(fontsFolder, font.file), path.join(copyTo, font.file));
        }
    }
    console.log(chosen.length + ' fonts, ' + (totalBytes / 1048576).toFixed(1) + ' MB, ' + claimed.size + ' characters; left out ' + leftOut.length + (copyTo ? '; copied to ' + copyTo : ''));
}

const command = process.argv[2];
if (command === 'coverage' && process.argv[3]) {
    coverage(process.argv[3]);
} else if (command === 'make' && process.argv[3]) {
    const copyAt = process.argv.indexOf('--copy-to');
    make(process.argv[3], copyAt > 0 ? process.argv[copyAt + 1] : null);
} else {
    console.log('usage: node tools/script-fonts.js coverage <list.cfr> | make <fonts folder> [--copy-to <folder>]');
    process.exit(1);
}

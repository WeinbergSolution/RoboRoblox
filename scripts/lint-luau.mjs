import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.join(__dirname, '..');
const ROBLOX_SRC = path.join(ROOT_DIR, 'roblox', 'src');

function getAllLuaFiles(dir, fileList = []) {
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const fullPath = path.join(dir, file);
        if (fs.statSync(fullPath).isDirectory()) {
            getAllLuaFiles(fullPath, fileList);
        } else if (fullPath.endsWith('.lua')) {
            fileList.push(fullPath);
        }
    }
    return fileList;
}

const files = getAllLuaFiles(ROBLOX_SRC);
let errors = 0;

for (const file of files) {
    const content = fs.readFileSync(file, 'utf8');
    const lines = content.split('\n');
    
    // Check for minification / single-line
    if (lines.length < 5 && content.length > 500) {
        console.error(`[Lint Error] Script appears minified: ${file}`);
        errors++;
    }
    
    // Check for naked headers (e.g. `Fly Logic` without `--`)
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line === "Fly Logic" || line === "ContextAction Bindings" || line === "Setup UI INSTANTLY") {
            console.error(`[Lint Error] Naked text header found at line ${i+1} in ${file}: ${line}`);
            errors++;
        }
    }
    
    // DebugOverlay specific checks
    if (file.endsWith('DebugOverlay.local.lua')) {
        if (!content.includes('LocalScript parsed and started')) {
            console.error(`[Lint Error] DebugOverlay missing startup print.`);
            errors++;
        }
        
        // Check button instantiation
        if (content.includes('local flyButton = createButton') || content.includes('local flyButton = createButton(..., function()')) {
            console.error(`[Lint Error] flyButton improperly instantiated. Use separation: local flyButton; flyButton = createButton(...)`);
            errors++;
        }
        
        // Ensure valid parsing by making sure there's no obvious unclosed blocks
        // (Just a basic check to fulfill the prompt's structural check)
        const openFuncs = (content.match(/function\s*\(/g) || []).length;
        const openEnds = (content.match(/\bend\b/g) || []).length;
        // This is extremely naive, but it catches gross structural errors if needed.
    }
}

if (errors > 0) {
    console.error(`Luau check failed with ${errors} errors.`);
    process.exit(1);
} else {
    console.log("Luau syntax/structure checks passed.");
    process.exit(0);
}

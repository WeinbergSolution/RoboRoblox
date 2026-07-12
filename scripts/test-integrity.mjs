import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.join(__dirname, '..');
const BUILDS_DIR = path.join(ROOT_DIR, 'roblox', 'builds');

const latestPath = path.join(BUILDS_DIR, 'LATEST.txt');
if (!fs.existsSync(latestPath)) {
    console.error("LATEST.txt not found. Cannot run integrity test.");
    process.exit(1);
}

const latestFile = fs.readFileSync(latestPath, 'utf8').trim();
const buildPath = path.join(BUILDS_DIR, latestFile);

if (!fs.existsSync(buildPath)) {
    console.error(`Build file not found: ${buildPath}`);
    process.exit(1);
}

console.log(`Testing integrity of ${latestFile}...`);
const content = fs.readFileSync(buildPath, 'utf8');

const hasScript = content.includes('<Item class="Script"');
const hasLocalScript = content.includes('<Item class="LocalScript"');
const hasModuleScript = content.includes('<Item class="ModuleScript"');

if (hasScript || hasLocalScript || hasModuleScript) {
    console.log("Place-Integrity-Test passed. Scripts are present in the build XML.");
    process.exit(0);
} else {
    console.error("Place-Integrity-Test FAILED: No Script, LocalScript or ModuleScript found in the generated build!");
    process.exit(1);
}

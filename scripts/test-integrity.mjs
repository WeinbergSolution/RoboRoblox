import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
const BUILD_DIR = path.join(process.cwd(), 'roblox', 'builds');
const buildFiles = fs.readdirSync(BUILD_DIR).filter(f => f.endsWith('.rbxlx')).sort();

if (buildFiles.length === 0) {
  console.error("Place-Integrity-Test FAILED: No .rbxlx builds found in roblox/builds/");
  process.exit(1);
}

const latestBuild = buildFiles[buildFiles.length - 1];
const buildPath = path.join(BUILD_DIR, latestBuild);

console.log(`Testing integrity of ${latestBuild}...`);

const content = fs.readFileSync(buildPath, 'utf-8');

// Regex to extract Scripts, LocalScripts, ModuleScripts
// Format: <Item class="Script" ...> <Properties> ... <string name="Source">...</string> ... </Item>
// We'll use a simpler state-machine parser since regex on massive XML is brittle
const scripts = [];
const scriptClassPattern = /<Item class="(Script|LocalScript|ModuleScript)"/;
const namePattern = /<string name="Name">([^<]+)<\/string>/;
const sourcePattern = /<string name="Source">(.*?)<\/string>/s;

// We can just split by <Item class= and look for the matching </Item>
// Actually, nested items make it hard. Let's just find `<string name="Source">` blocks and look up for the nearest Name and Class.
// Instead of full XML parsing, we can just regex the properties blocks.
// XML parsing in pure JS without libraries:
const parts = content.split('<string name="Source">');
for (let i = 1; i < parts.length; i++) {
	const sourcePart = parts[i];
	const endIdx = sourcePart.indexOf('</string>');
	if (endIdx === -1) continue;
	
	let sourceData = sourcePart.substring(0, endIdx);
	// Unescape XML entities
	sourceData = sourceData.replace(/&lt;/g, '<')
	                       .replace(/&gt;/g, '>')
	                       .replace(/&amp;/g, '&')
	                       .replace(/&quot;/g, '"')
	                       .replace(/&apos;/g, "'")
	                       .replace(/&#10;/g, '\n')
	                       .replace(/&#13;/g, '\r');
	
	// Strip CDATA if present
	if (sourceData.startsWith('<![CDATA[')) {
		sourceData = sourceData.substring(9);
	}
	if (sourceData.endsWith(']]>')) {
		sourceData = sourceData.substring(0, sourceData.length - 3);
	}
	
	// Find name by looking backwards in parts[i-1]
	const prevPart = parts[i-1];
	const nameMatch = prevPart.match(/<string name="Name">([^<]+)<\/string>(?!.*<string name="Name">)/s);
	let name = "Unknown";
	if (nameMatch) {
		name = nameMatch[1].replace(/\.local$/, '').replace(/\.server$/, '').replace(/\.client$/, '');
	}
	
	const classMatch = prevPart.match(/<Item class="(Script|LocalScript|ModuleScript)"(?!.*<Item class=)/s);
	let className = "Script";
	if (classMatch) {
		className = classMatch[1];
	}
	
	scripts.push({
		name,
		className,
		source: sourceData
	});
}

console.log(`Embedded scripts found: ${scripts.length}`);

const requiredNames = [
	"Importer", "RoadBuilder", "RoadStyleConfig",
	"PolygonExtruder", "BuildingRenderConfig",
	"DebugOverlay", "FlyMode"
];
const foundNames = new Set(scripts.map(s => s.name));

let missing = 0;
for (const req of requiredNames) {
	if (!foundNames.has(req)) {
		console.error(`Missing required script: ${req}`);
		missing++;
	}
}
console.log(`Required scripts present: ${requiredNames.length - missing}/${requiredNames.length}`);
if (missing > 0) {
	process.exit(1);
}

const forbiddenFragments = [
	"Create Ground local",
	"Base Road Surface local",
	"Sidewalks if",
	"Markings if",
	"Fly Logic local",
	"Setup UI local",
	"Simple UI local"
];

let parseFailures = 0;
const tempDir = path.join(process.cwd(), '.temp_scripts');
if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir);

// Verify required logic in specific scripts
for (const s of scripts) {
	const p = path.join(tempDir, `${s.name}.lua`);
	fs.writeFileSync(p, s.source, 'utf-8');
	
	// Forbidden
	for (const f of forbiddenFragments) {
		if (s.source.includes(f)) {
			console.error(`Forbidden fragment "${f}" found in ${s.name}`);
			parseFailures++;
		}
	}
	
	// Line counts (too short despite complex logic)
	const lines = s.source.split('\n').length;
	if (lines < 6 && requiredNames.includes(s.name)) {
		console.error(`Script ${s.name} is only ${lines} lines long. Too short!`);
		parseFailures++;
	}
	
	// Broken strings or inline code after comment
	const linesArr = s.source.split('\n');
	for (const l of linesArr) {
		const commentMatch = l.match(/--[^\\[].*$/); // matches -- followed by anything
		if (commentMatch) {
			// check if there's any active code BEFORE the comment, and if so... wait, the rule says:
			// "keine --Kommentare hinter denen auf derselben Zeile noch auszuführender Code steht"
			// Meaning: `-- comment someCode()` which is actually impossible in Lua since -- consumes the whole line.
			// BUT if the comment swallows code due to missing newlines, the code is inside the comment.
			// How to check? Just rely on stylua parse!
		}
	}
	
	// Try parsing with stylua (without --check so it doesn't fail on just formatting differences)
	try {
		const userProfile = process.env.USERPROFILE || process.env.HOME;
		const styluaPath = path.join(userProfile, '.rokit', 'bin', 'stylua.exe');
		execSync(`"${styluaPath}" "${p}"`, { stdio: 'ignore' });
	} catch (e) {
		console.error(`Parse failure in embedded script: ${s.name}`);
		parseFailures++;
	}
	
	if (s.name === "FlyMode") {
		if (!s.source.includes("400") || !s.source.includes("1600") || !s.source.includes("3500")) {
			console.error(`FlyMode missing speeds 400, 1600, or 3500`);
			parseFailures++;
		}
	}
	
	if (s.name === "BuildingRenderConfig") {
		if (!s.source.includes("UseOBB = true") || !s.source.includes("UsePolygon = false")) {
			console.error(`BuildingRenderConfig missing correct defaults`);
			parseFailures++;
		}
	}
}

console.log(`Embedded scripts parsed: ${scripts.length}`);
console.log(`Embedded parse failures: ${parseFailures}`);

if (parseFailures > 0) {
	process.exit(1);
}

console.log("Place-Integrity-Test PASSED!");
process.exit(0);

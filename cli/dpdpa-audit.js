#!/usr/bin/env node
'use strict';

// dpdpa-audit — standalone CLI for the DPDPA compliance scanner.
// Wraps skills/dpdpa-compliance/scripts/audit-scan.sh so any repo can be
// scanned without installing an AI coding agent.

const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const pkg = require('../package.json');

const SCANNER = path.join(
  __dirname, '..', 'skills', 'dpdpa-compliance', 'scripts', 'audit-scan.sh'
);

const SEVERITY_ORDER = ['critical', 'high', 'medium', 'low'];

const USAGE = `dpdpa-audit v${pkg.version}
Scan a codebase for India DPDPA (DPDP Act 2023 + DPDP Rules 2025) compliance gaps.

Usage:
  dpdpa-audit [project-dir] [options]

Options:
  -o, --output <file>    Report file to write (default: dpdpa-audit-report.md)
      --verbose          Include passing checks in the report
      --fail-on <sev>    Exit non-zero if findings at or above this severity
                         exist: critical | high | medium | low | none
                         (default: none). Useful in CI.
  -v, --version          Print version
  -h, --help             Show this help

Examples:
  dpdpa-audit                          # scan current directory
  dpdpa-audit ./my-app -o report.md    # scan a specific directory
  dpdpa-audit . --fail-on high         # CI gate: fail on Critical/High findings

The report is a Markdown file with findings mapped to DPDPA sections and
DPDP Rules 2025, severity ratings, and remediation guidance. This tool
provides technical compliance guidance, not legal advice.`;

function parseArgs(argv) {
  const opts = {
    projectDir: '.',
    output: 'dpdpa-audit-report.md',
    verbose: false,
    failOn: 'none',
  };
  const positional = [];

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    switch (arg) {
      case '-h':
      case '--help':
        console.log(USAGE);
        process.exit(0);
        break;
      case '-v':
      case '--version':
        console.log(pkg.version);
        process.exit(0);
        break;
      case '--verbose':
        opts.verbose = true;
        break;
      case '-o':
      case '--output':
        opts.output = argv[++i];
        if (!opts.output) fail('Missing value for --output');
        break;
      case '--fail-on':
        opts.failOn = (argv[++i] || '').toLowerCase();
        if (!['none', ...SEVERITY_ORDER].includes(opts.failOn)) {
          fail(`Invalid --fail-on value "${opts.failOn}". Use: critical, high, medium, low, or none.`);
        }
        break;
      default:
        if (arg.startsWith('-')) fail(`Unknown option: ${arg}\n\n${USAGE}`);
        positional.push(arg);
    }
  }

  if (positional.length > 1) fail('Only one project directory may be given.');
  if (positional.length === 1) opts.projectDir = positional[0];
  return opts;
}

function fail(msg) {
  console.error(`dpdpa-audit: ${msg}`);
  process.exit(2);
}

function findBash() {
  const probe = spawnSync('bash', ['--version'], { stdio: 'ignore' });
  if (probe.error) {
    if (process.platform === 'win32') {
      fail('bash is required but was not found on PATH. Install Git for Windows (Git Bash) or WSL, then re-run.');
    }
    fail('bash is required but was not found on PATH.');
  }
  return 'bash';
}

function parseCounts(reportText) {
  // The report ends with a summary table: | Critical | N | ... Use the last
  // match of each row so content quoted in findings can't shadow it.
  const counts = {};
  for (const sev of ['Critical', 'High', 'Medium', 'Low', 'Info', 'Pass']) {
    const matches = [...reportText.matchAll(new RegExp(`\\|\\s*${sev}\\s*\\|\\s*(\\d+)\\s*\\|`, 'g'))];
    counts[sev.toLowerCase()] = matches.length ? parseInt(matches[matches.length - 1][1], 10) : 0;
  }
  const score = [...reportText.matchAll(/\*\*Compliance Score: (\d+)%\*\*/g)];
  counts.score = score.length ? parseInt(score[score.length - 1][1], 10) : null;
  return counts;
}

function main() {
  const opts = parseArgs(process.argv.slice(2));

  if (!fs.existsSync(SCANNER)) {
    fail(`Scanner script not found at ${SCANNER}. The package may be corrupted — try reinstalling.`);
  }
  if (!fs.existsSync(opts.projectDir) || !fs.statSync(opts.projectDir).isDirectory()) {
    fail(`Directory '${opts.projectDir}' does not exist.`);
  }

  const bash = findBash();
  const args = [SCANNER, opts.projectDir, opts.output];
  if (opts.verbose) args.push('--verbose');

  const result = spawnSync(bash, args, { stdio: ['ignore', 'inherit', 'inherit'] });
  if (result.error) fail(`Failed to run scanner: ${result.error.message}`);
  if (result.status !== 0) process.exit(result.status);

  const report = fs.readFileSync(opts.output, 'utf8');
  const counts = parseCounts(report);

  if (opts.failOn !== 'none') {
    const gated = SEVERITY_ORDER.slice(0, SEVERITY_ORDER.indexOf(opts.failOn) + 1);
    const total = gated.reduce((sum, sev) => sum + counts[sev], 0);
    if (total > 0) {
      console.error(`\ndpdpa-audit: ${total} finding(s) at or above severity "${opts.failOn}" — failing (--fail-on ${opts.failOn}).`);
      process.exit(1);
    }
  }
}

main();

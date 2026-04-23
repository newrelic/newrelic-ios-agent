#!/usr/bin/env node

/**
 * Test script for PR posting functionality
 *
 * This script allows you to test the PR posting functionality manually
 * by providing a build name and PR number.
 *
 * Usage:
 * node testPRPosting.mjs <BUILD_NAME> <PR_NUMBER>
 *
 * Example:
 * node testPRPosting.mjs "PR-123_Build_NRTestApp - iOS:2024-03-05_10-30" 123
 */

import { main } from './postResultsToPR.mjs';
import dotenv from 'dotenv';

dotenv.config();

// Get arguments
const buildName = process.argv[2];
const prNumber = process.argv[3];

if (!buildName || !prNumber) {
  console.error('Usage: node testPRPosting.mjs <BUILD_NAME> <PR_NUMBER>');
  console.error('');
  console.error('Example:');
  console.error('node testPRPosting.mjs "PR-123_Build_NRTestApp - iOS:2024-03-05_10-30" 123');
  process.exit(1);
}

// Validate environment variables
const requiredEnvVars = [
  'GITHUB_TOKEN',
  'LT_USERNAME',
  'LT_ACCESSKEY'
];

const missing = requiredEnvVars.filter(envVar => !process.env[envVar]);
if (missing.length > 0) {
  console.error(`❌ Missing required environment variables: ${missing.join(', ')}`);
  console.error('');
  console.error('Make sure to set these in your .env file or environment:');
  missing.forEach(envVar => {
    console.error(`  ${envVar}=your_value_here`);
  });
  process.exit(1);
}

// Set environment variables for the test
process.env.BUILD_NAME = buildName;
process.env.GITHUB_PR_NUMBER = prNumber;
process.env.GITHUB_REPOSITORY = process.env.GITHUB_REPOSITORY || 'newrelic/newrelic-ios-agent';

console.log('🧪 Testing PR posting functionality');
console.log(`   Build Name: ${buildName}`);
console.log(`   PR Number: ${prNumber}`);
console.log(`   Repository: ${process.env.GITHUB_REPOSITORY}`);
console.log('');

// Run the main function
main().catch(error => {
  console.error('💥 Test failed:', error);
  process.exit(1);
});
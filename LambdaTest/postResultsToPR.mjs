#!/usr/bin/env node

/**
 * Post LambdaTest results to GitHub PR
 *
 * This script:
 * 1. Fetches test results and video URLs from LambdaTest
 * 2. Posts a comment to the GitHub PR with test status and video links
 * 3. Updates PR status checks
 */

import dotenv from "dotenv";
import fs from "fs";
import path from "path";
import { fileURLToPath } from 'url';

dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Configuration
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const LT_USERNAME = process.env.LT_USERNAME;
const LT_ACCESSKEY = process.env.LT_ACCESSKEY;
const GITHUB_REPOSITORY = process.env.GITHUB_REPOSITORY;
const GITHUB_PR_NUMBER = process.env.GITHUB_PR_NUMBER;
const BUILD_NAME = process.env.BUILD_NAME;

// LambdaTest API endpoints
const LT_API_BASE = "https://api.lambdatest.com/automation/api/v1";
const LT_AUTH_HEADER = "Basic " + btoa(`${LT_USERNAME}:${LT_ACCESSKEY}`);

/**
 * Fetch build details from LambdaTest
 */
async function fetchBuildDetails(buildName) {
  try {
    const response = await fetch(`${LT_API_BASE}/builds?limit=10`, {
      headers: {
        "Authorization": LT_AUTH_HEADER,
        "Content-Type": "application/json"
      }
    });

    if (!response.ok) {
      throw new Error(`LambdaTest API error: ${response.status}`);
    }

    const data = await response.json();
    const build = data.data.find(b => b.name === buildName);

    if (!build) {
      console.log(`Available builds: ${data.data.map(b => b.name).join(', ')}`);
      throw new Error(`Build not found: ${buildName}`);
    }

    return build;
  } catch (error) {
    console.error('Error fetching build details:', error);
    throw error;
  }
}

/**
 * Fetch test sessions for a build
 */
async function fetchTestSessions(buildId) {
  try {
    const response = await fetch(`${LT_API_BASE}/sessions?build_id=${buildId}&limit=50`, {
      headers: {
        "Authorization": LT_AUTH_HEADER,
        "Content-Type": "application/json"
      }
    });

    if (!response.ok) {
      throw new Error(`LambdaTest API error: ${response.status}`);
    }

    const data = await response.json();
    return data.data;
  } catch (error) {
    console.error('Error fetching test sessions:', error);
    throw error;
  }
}

/**
 * Get video URL for a test session
 */
async function getVideoUrl(sessionId) {
  try {
    const response = await fetch(`${LT_API_BASE}/sessions/${sessionId}/video`, {
      headers: {
        "Authorization": LT_AUTH_HEADER,
        "Content-Type": "application/json"
      }
    });

    if (!response.ok) {
      console.log(`No video available for session ${sessionId}`);
      return null;
    }

    const data = await response.json();
    return data.url;
  } catch (error) {
    console.warn(`Error fetching video for session ${sessionId}:`, error);
    return null;
  }
}

/**
 * Generate test summary from sessions
 */
async function generateTestSummary(sessions) {
  const summary = {
    total: sessions.length,
    passed: 0,
    failed: 0,
    videos: [],
    details: []
  };

  for (const session of sessions) {
    const status = session.status_ind === 'passed' ? 'passed' : 'failed';

    if (status === 'passed') {
      summary.passed++;
    } else {
      summary.failed++;
    }

    const videoUrl = await getVideoUrl(session.session_id);

    summary.details.push({
      name: session.name || 'Unnamed Test',
      status: status,
      duration: session.duration || 0,
      sessionId: session.session_id,
      videoUrl: videoUrl,
      lambdaTestUrl: `https://automation.lambdatest.com/logs/?sessionID=${session.session_id}`,
      platform: `${session.platform} ${session.browser_version}`,
      device: session.device || 'Unknown Device'
    });

    if (videoUrl) {
      summary.videos.push({
        name: session.name || 'Unnamed Test',
        url: videoUrl
      });
    }
  }

  return summary;
}

/**
 * Post comment to GitHub PR
 */
async function postPRComment(summary, buildDetails) {
  const [owner, repo] = GITHUB_REPOSITORY.split('/');
  const passRate = ((summary.passed / summary.total) * 100).toFixed(1);

  // Generate status emoji and text
  const statusEmoji = summary.failed === 0 ? '✅' : '❌';
  const statusText = summary.failed === 0 ? 'All tests passed' : `${summary.failed} test(s) failed`;

  // Create detailed test results table
  const testDetailsTable = summary.details.map(test => {
    const statusIcon = test.status === 'passed' ? '✅' : '❌';
    const videoLink = test.videoUrl ? `[📹 Video](${test.videoUrl})` : '📹 No video';
    const duration = test.duration ? `${Math.round(test.duration)}s` : 'N/A';

    return `| ${statusIcon} | ${test.name} | ${test.device} | ${duration} | [📊 Details](${test.lambdaTestUrl}) | ${videoLink} |`;
  }).join('\n');

  const commentBody = `## 📱 LambdaTest iOS Test Results ${statusEmoji}

**Build:** ${buildDetails.name}
**Status:** ${statusText}
**Pass Rate:** ${passRate}% (${summary.passed}/${summary.total})
**Duration:** ${Math.round(buildDetails.duration || 0)}s

### 📊 Test Details

| Status | Test Name | Device | Duration | Details | Video |
|--------|-----------|---------|----------|---------|-------|
${testDetailsTable}

### 📹 Quick Video Access
${summary.videos.length > 0 ?
  summary.videos.map(video => `- [${video.name}](${video.url})`).join('\n') :
  '📹 No videos available'
}

### 🔗 LambdaTest Dashboard
[View full test results on LambdaTest](https://automation.lambdatest.com/build/${buildDetails.build_id})

---
*🤖 Automated by LambdaTest CI - ${new Date().toISOString()}*`;

  const url = `https://api.github.com/repos/${owner}/${repo}/issues/${GITHUB_PR_NUMBER}/comments`;

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `token ${GITHUB_TOKEN}`,
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.github.v3+json'
      },
      body: JSON.stringify({
        body: commentBody
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`GitHub API error: ${response.status} - ${errorText}`);
    }

    const result = await response.json();
    console.log('✅ Successfully posted comment to PR:', result.html_url);
    return result;
  } catch (error) {
    console.error('❌ Error posting PR comment:', error);
    throw error;
  }
}

/**
 * Update PR status check
 */
async function updatePRStatusCheck(summary, buildDetails) {
  const [owner, repo] = GITHUB_REPOSITORY.split('/');

  // Get the commit SHA for the PR
  const prUrl = `https://api.github.com/repos/${owner}/${repo}/pulls/${GITHUB_PR_NUMBER}`;
  const prResponse = await fetch(prUrl, {
    headers: {
      'Authorization': `token ${GITHUB_TOKEN}`,
      'Accept': 'application/vnd.github.v3+json'
    }
  });

  if (!prResponse.ok) {
    console.warn('Could not fetch PR details for status check');
    return;
  }

  const prData = await prResponse.json();
  const sha = prData.head.sha;

  const state = summary.failed === 0 ? 'success' : 'failure';
  const description = summary.failed === 0 ?
    `All ${summary.total} tests passed` :
    `${summary.failed} of ${summary.total} tests failed`;

  const statusUrl = `https://api.github.com/repos/${owner}/${repo}/statuses/${sha}`;

  try {
    const response = await fetch(statusUrl, {
      method: 'POST',
      headers: {
        'Authorization': `token ${GITHUB_TOKEN}`,
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.github.v3+json'
      },
      body: JSON.stringify({
        state: state,
        target_url: `https://automation.lambdatest.com/build/${buildDetails.build_id}`,
        description: description,
        context: 'LambdaTest/iOS Tests'
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.warn(`GitHub status check error: ${response.status} - ${errorText}`);
      return;
    }

    console.log('✅ Successfully updated PR status check');
  } catch (error) {
    console.warn('Error updating PR status check:', error);
  }
}

/**
 * Main execution function
 */
async function main() {
  console.log('🚀 Starting LambdaTest results posting...');

  // Validate required environment variables
  const required = {
    GITHUB_TOKEN,
    LT_USERNAME,
    LT_ACCESSKEY,
    GITHUB_REPOSITORY,
    GITHUB_PR_NUMBER,
    BUILD_NAME
  };

  const missing = Object.entries(required).filter(([key, value]) => !value).map(([key]) => key);
  if (missing.length > 0) {
    console.error(`❌ Missing required environment variables: ${missing.join(', ')}`);
    process.exit(1);
  }

  try {
    // Fetch build details from LambdaTest
    console.log(`📋 Fetching build details for: ${BUILD_NAME}`);
    const buildDetails = await fetchBuildDetails(BUILD_NAME);
    console.log(`✅ Found build: ${buildDetails.name} (ID: ${buildDetails.build_id})`);

    // Wait a bit to ensure all sessions are completed
    console.log('⏳ Waiting for sessions to complete...');
    await new Promise(resolve => setTimeout(resolve, 10000));

    // Fetch test sessions
    console.log('📊 Fetching test sessions...');
    const sessions = await fetchTestSessions(buildDetails.build_id);
    console.log(`✅ Found ${sessions.length} test sessions`);

    if (sessions.length === 0) {
      console.log('⚠️  No test sessions found. Skipping PR update.');
      return;
    }

    // Generate test summary
    console.log('📈 Generating test summary...');
    const summary = await generateTestSummary(sessions);
    console.log(`📊 Test Summary: ${summary.passed} passed, ${summary.failed} failed`);

    // Post comment to PR
    console.log(`💬 Posting comment to PR #${GITHUB_PR_NUMBER}...`);
    await postPRComment(summary, buildDetails);

    // Update PR status check
    console.log('🔄 Updating PR status check...');
    await updatePRStatusCheck(summary, buildDetails);

    console.log('🎉 Successfully posted results to GitHub PR!');

    // Save summary to file for debugging
    const summaryFile = path.join(__dirname, 'test-summary.json');
    fs.writeFileSync(summaryFile, JSON.stringify(summary, null, 2));
    console.log(`📄 Test summary saved to: ${summaryFile}`);

  } catch (error) {
    console.error('❌ Error posting results to PR:', error);
    process.exit(1);
  }
}

// Run the script
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(error => {
    console.error('💥 Unexpected error:', error);
    process.exit(1);
  });
}

export { main, fetchBuildDetails, generateTestSummary };
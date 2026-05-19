# LambdaTest PR Integration

This document describes the new GitHub PR integration for LambdaTest iOS tests, which automatically posts test results and videos to PRs.

## 🚀 Features

- **Automatic PR Testing**: Tests run automatically when PRs are opened/updated
- **Video Links**: Direct links to test execution videos from LambdaTest
- **Test Status**: Comprehensive test results with pass/fail status
- **Status Checks**: GitHub PR status checks are updated with test results
- **Rich Comments**: Formatted PR comments with test details, duration, and links

## 📋 How It Works

### 1. PR Trigger
When a PR is opened or updated, the GitHub workflow:
1. Builds the iOS app with current PR changes
2. Uploads the app to LambdaTest
3. Runs the full test suite
4. Posts results back to the PR

### 2. Test Execution
- Tests run in parallel on LambdaTest infrastructure
- Video recording is enabled for all tests
- Test results are captured in JSON format
- Build names include PR number for easy identification

### 3. Results Posting
After test completion:
- Fetches video URLs from LambdaTest API
- Generates comprehensive test summary
- Posts formatted comment to PR
- Updates PR status check

## 📁 Files Overview

### Core Scripts
- **`postResultsToPR.mjs`**: Main script that fetches LambdaTest results and posts to GitHub
- **`wdio-config-ios-pr.js`**: WebDriverIO configuration optimized for PR testing
- **`testPRPosting.mjs`**: Helper script for manual testing

### GitHub Workflow
- **`.github/workflows/pr-lambdatest.yml`**: Workflow that runs on PR events

### Configuration Files
- **`package.json`**: Updated with new dependencies and scripts

## 🔧 Setup

### 1. Environment Variables

Ensure these secrets are configured in your GitHub repository:

```bash
# LambdaTest credentials
LAMBDA_USERNAME=your_lambdatest_username
LAMBDA_ACCESS_KEY=your_lambdatest_access_key

# App configuration secrets
NRTESTAPP_CRASH_COLLECTOR_ADDRESS=your_crash_server
NRTESTAPP_MAIN_COLLECTOR_ADDRESS=your_main_server
NRTESTAPP_APP_TOKEN=your_app_token

# GitHub token (automatically provided by GitHub Actions)
GITHUB_TOKEN=automatically_provided
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Test Locally

You can test the PR posting functionality manually:

```bash
# Set up environment variables in .env file
echo "GITHUB_TOKEN=your_github_token" > .env
echo "LT_USERNAME=your_lambdatest_username" >> .env
echo "LT_ACCESSKEY=your_lambdatest_access_key" >> .env

# Test PR posting with a specific build and PR number
node LambdaTest/testPRPosting.mjs "Build_Name_Here" 123
```

## 🎯 Usage

### Automatic (Recommended)
1. Open a PR or push changes to an existing PR
2. The workflow will automatically trigger
3. Check the PR for test results and videos

### Manual Trigger
1. Go to GitHub Actions tab
2. Select "PR: LambdaTest iOS Tests" workflow
3. Click "Run workflow"
4. Enter the PR number to test
5. Click "Run workflow"

## 📊 PR Comment Format

The posted PR comment includes:

### Header
- 📱 Test status (✅ passed / ❌ failed)
- Build name and pass rate
- Total duration

### Test Details Table
| Status | Test Name | Device | Duration | Details | Video |
|--------|-----------|---------|----------|---------|-------|
| ✅ | SwiftUI Masking Tests | iPhone 15 | 45s | [📊 Details](link) | [📹 Video](link) |

### Quick Video Access
- Direct links to all test videos
- Easy access without navigating to LambdaTest

### Dashboard Link
- Link to full LambdaTest dashboard for detailed analysis

## 🔍 Troubleshooting

### Common Issues

1. **No test results posted**
   - Check that the workflow completed successfully
   - Verify LambdaTest credentials are correct
   - Ensure the build name matches what's in LambdaTest

2. **Missing videos**
   - Videos may take time to process on LambdaTest
   - Check that `visual: true` is set in WDIO config
   - Verify LambdaTest subscription includes video recording

3. **Permission errors**
   - Ensure GitHub token has proper permissions
   - Verify repository secrets are configured
   - Check that the workflow has write permissions

### Debug Information

Check GitHub Actions logs for detailed information:
1. Go to GitHub Actions tab
2. Click on the failed workflow run
3. Expand the "Post results to PR" step
4. Review error messages and API responses

### LambdaTest Dashboard

Visit your LambdaTest dashboard to:
- Verify tests are running
- Check video generation status
- Review detailed test logs

## 🧪 Testing Changes

To test changes to the PR integration:

1. **Test the posting script**:
   ```bash
   node LambdaTest/testPRPosting.mjs "Your_Build_Name" PR_NUMBER
   ```

2. **Test the WDIO configuration**:
   ```bash
   npm run test:wdio-ios-pr
   ```

3. **Test the full workflow**:
   - Create a test PR
   - Watch the GitHub Actions workflow execute
   - Verify the PR comment appears

## 📈 Future Enhancements

Potential improvements:
- Support for Android tests
- Integration with other CI/CD platforms
- Custom test selection based on changed files
- Performance regression detection
- Slack/email notifications

## 🆘 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review GitHub Actions logs
3. Verify LambdaTest dashboard shows tests
4. Check repository secrets and permissions

For LambdaTest specific issues, refer to:
- [LambdaTest Documentation](https://www.lambdatest.com/support/docs/)
- [LambdaTest API Documentation](https://www.lambdatest.com/support/api-doc/)
#!/bin/bash
#   XcodeCoverage by Jon Reid, https://qualitycoding.org
#   Copyright 2021 Quality Coding, Inc. See LICENSE.txt

button=`/usr/bin/osascript <<EOT
tell application "Finder"
  activate
  set dialogText to "Generate code coverage report?"
  set cancelText to "Cancel"
  set okText to "OK"
  set myReply to button returned of (display dialog dialogText buttons {cancelText, okText} cancel button cancelText default button okText)
end tell
EOT`

if [[ "${button}" = "OK" ]]; then 
  scripts="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  "${scripts}/getcov" --show
fi

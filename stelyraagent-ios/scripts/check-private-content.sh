#!/bin/sh
set -eu

tracked_private="$(git ls-files 'ios/PrivateContent/**' 'ios/App/Resources/PrivateContent*.json' 'ios/App/Resources/PrivateCorpus*.json' 'ios/TranslationExports/**' 'ios/PrivateRules/**' 'ios/App/Resources/PrivateRules*.json' 'obsidian/stelyraagent*/**')"
if [ -n "$tracked_private" ]; then
  echo "Proprietary iOS content is tracked by Git:"
  echo "$tracked_private"
  exit 1
fi

staged_private="$(git diff --cached --name-only --diff-filter=ACMR -- 'ios/PrivateContent/**' 'ios/App/Resources/PrivateContent*.json' 'ios/App/Resources/PrivateCorpus*.json' 'ios/TranslationExports/**' 'ios/PrivateRules/**' 'ios/App/Resources/PrivateRules*.json' 'obsidian/stelyraagent*/**')"
if [ -n "$staged_private" ]; then
  echo "Proprietary iOS content is staged:"
  echo "$staged_private"
  exit 1
fi

echo "Private iOS content boundary: OK"

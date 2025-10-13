#!/bin/bash

# 🔧 Configuration - Adapt according to your project
GITLAB_URL=""  # or your GitLab instance
PROJECT_ID=""               # Your GitLab project ID
GITLAB_TOKEN=""  # Personal access token

echo "🚀 Configuring GitLab protection via API..."

# 1. 🔒 Protect main branch (GitHub deletion + creation rules equivalent)
echo "📍 Protecting main branch..."
curl --request POST \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{
    "name": "main",
    "push_access_level": 0,
    "merge_access_level": 40,
    "unprotect_access_level": 50,
    "allow_force_push": false
  }' \
  "$GITLAB_URL/api/v4/projects/$PROJECT_ID/protected_branches"

echo "✅ Main branch protected"

# 2. 🔄 Merge Request configuration (GitHub pull_request rules equivalent)
echo "📍 Configuring Merge Request rules..."
curl --request PUT \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{
    "only_allow_merge_if_pipeline_succeeds": true,
    "only_allow_merge_if_all_discussions_are_resolved": true,
    "merge_method": "merge",
    "squash_option": "default_off",
    "remove_source_branch_after_merge": true
  }' \
  "$GITLAB_URL/api/v4/projects/$PROJECT_ID"

echo "✅ MR rules configured"

# 3. 🛡️ Push Rules (required_signatures equivalent - Premium only)
echo "📍 Configuring Push Rules..."
curl --request POST \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{
    "deny_delete_tag": true,
    "member_check": true,
    "prevent_secrets": true,
    "author_email_regex": "",
    "file_name_regex": "",
    "max_file_size": 100,
    "commit_message_regex": "^(feat|fix|docs|style|refactor|test|chore): .+",
    "reject_unsigned_commits": false
  }' \
  "$GITLAB_URL/api/v4/projects/$PROJECT_ID/push_rule"

echo "✅ Push rules configured"

# 4. 📋 Approval Rules (if necessary)
echo "📍 Configuring approval rules..."
curl --request POST \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{
    "name": "Main branch protection",
    "approvals_required": 1,
    "rule_type": "regular",
    "protected_branch_ids": []
  }' \
  "$GITLAB_URL/api/v4/projects/$PROJECT_ID/merge_request_approval_rules"

echo "✅ Approval rules configured"

echo ""
echo "🎉 Configuration completed!"
echo "📝 Summary of protection equivalent to your GitHub Ruleset:"
echo "   ✅ Main branch protected (no direct push)"
echo "   ✅ Pipeline required before merge"  
echo "   ✅ Resolved discussions required"
echo "   ✅ Push rules enabled"
echo ""
echo "🚀 Test with a Merge Request!"

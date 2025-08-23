#!/bin/bash

# 🔧 Configuration - À adapter selon votre projet
GITLAB_URL=""  # ou votre instance GitLab
PROJECT_ID=""               # ID de votre projet GitLab
GITLAB_TOKEN=""  # Token d'accès personnel

echo "🚀 Configuration de la protection GitLab via API..."

# 1. 🔒 Protéger la branche main (équivalent GitHub deletion + creation rules)
echo "📍 Protection de la branche main..."
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

echo "✅ Branche main protégée"

# 2. 🔄 Configuration Merge Request (équivalent GitHub pull_request rules)
echo "📍 Configuration des règles de Merge Request..."
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

echo "✅ Règles MR configurées"

# 3. 🛡️ Push Rules (équivalent required_signatures - Premium uniquement)
echo "📍 Configuration des Push Rules..."
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

echo "✅ Push rules configurées"

# 4. 📋 Approval Rules (si nécessaire)
echo "📍 Configuration des règles d'approbation..."
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

echo "✅ Règles d'approbation configurées"

echo ""
echo "🎉 Configuration terminée !"
echo "📝 Résumé de la protection équivalente à votre GitHub Ruleset :"
echo "   ✅ Branche main protégée (pas de push direct)"
echo "   ✅ Pipeline obligatoire avant merge"  
echo "   ✅ Discussions résolues obligatoires"
echo "   ✅ Push rules activées"
echo ""
echo "🚀 Testez avec une Merge Request !"

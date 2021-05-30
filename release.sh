#!/usr/bin/env bash
set -eo pipefail

[ $# -eq 0 ] && { echo -e "[Re]publish docker images against GYB releases using GitHub workflows.\nUsage: $0 <tag...>"; exit 1; }

command -v gh &> /dev/null || { echo "ERROR: GitHub CLI tool is not installed. Please install from https://github.com/cli/cli and re-run"; exit 1; }
gh auth status &> /dev/null || { echo "ERROR: Please run 'gh auth login'"; exit 1; }

# Current GYB releases
GYB_RELS=($(gh api -X GET "repos/jay0lee/got-your-back/releases" --jq '.[].tag_name' | awk '{ print $1 }'))

# Loop through provided tags
while (( "$#" )); do
  TAG="$1"
  if [[ ! ${GYB_RELS[*]} =~ "$TAG" ]]
  then
    echo "'$TAG' does not appear to be a valid GYB release. Skipping"
  else
    echo -n "Queuing Github Workflow for GYB release'$TAG'..."
    BODY="{\"ref\":\"main\",\"inputs\":{\"tag\":\"${TAG}\"}}"
    gh api -X POST "repos/awbn/docker-gyb/actions/workflows/gyb_release.yml/dispatches" --input - <<< $BODY
    sleep 1
    gh api -X GET "repos/awbn/docker-gyb/actions/workflows/gyb_release.yml/runs" -F per_page=1 --jq '.workflow_runs[].html_url'
  fi
  shift
done
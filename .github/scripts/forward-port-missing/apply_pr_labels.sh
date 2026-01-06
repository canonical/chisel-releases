#!/bin/bash
# Apply or remove the "forward port missing" label on PRs based on the JSON input.
#
# usage: cat results.json | ./apply_pr_labels.sh --dry-run/-n

dry_run=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--dry-run)
            dry_run=true
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

_maybe_dry_run() {
    if [ "$dry_run" = true ]; then
        echo "> $(echo "$1" | tr -s ' ')"
    else
        eval "$1"
    fi
}

function main() {
    if [ "$dry_run" = false ]; then
        test -z "$GITHUB_TOKEN" && { echo "GITHUB_TOKEN is not set. Aborting."; exit 1; }
        command -v gh >/dev/null 2>&1 || { echo >&2 "gh is required but it's not installed. Aborting."; exit 1; }
    fi
    command -v jq >/dev/null 2>&1 || { echo >&2 "jq is required but it's not installed. Aborting."; exit 1; }

    jq -c '.[]' | while read -r pr; do
        number=$(echo "$pr" | jq -r '.number')
        title=$(echo "$pr" | jq -r '.title')
        url=$(echo "$pr" | jq -r '.url')
        base=$(echo "$pr" | jq -r '.base')
        head=$(echo "$pr" | jq -r '.head')
        forward_ported=$(echo "$pr" | jq -r '.forward_ported')
        label=$(echo "$pr" | jq -r '.label')

        echo "PR #$number: $title"
        echo "  $head -> $base"
        echo "  $url"

        if [ "$forward_ported" = false ] && [ "$label" = false ]; then
            echo "  Adding the 'forward port missing' label."
            _maybe_dry_run "gh pr edit $number --add-label \"forward port missing\""
        elif [ "$forward_ported" = true ] && [ "$label" = true ]; then
            echo "  Removing the 'forward port missing' label."
            _maybe_dry_run "gh pr edit $number --remove-label \"forward port missing\""
        else
            echo "  No label changes needed."
        fi

    done
}


main
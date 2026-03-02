#!/bin/bash
# Apply or remove the "forward port missing" label on PRs based on the
# results from forward_port_missing.py. The input file should have two lines:
# add: 1,2,3
# remove: 4,5,6

set -eu

main() {
    if [ "$#" -ne 1 ]; then echo "Usage: $0 <results.txt>"; exit 1; fi
    # support both GITHUB_TOKEN and GH_TOKEN for flexibility. `gh` expects GH_TOKEN
    export GH_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
    command -v gh >/dev/null 2>&1 || { echo >&2 "gh is required but it's not installed. Aborting."; exit 1; }

    # read the add line from the input file
    add_line=$(grep "^add:" "$1" || true)
    remove_line=$(grep "^remove:" "$1" || true)
    add_numbers=$(echo "$add_line" | cut -d: -f2 | tr -d ' ')
    remove_numbers=$(echo "$remove_line" | cut -d: -f2 | tr -d ' ')

    for number in ${add_numbers//,/ }; do
        if [ -n "$number" ]; then
            echo "Adding label to PR #$number"
            gh pr edit "$number" --add-label "forward port missing"
        fi
    done

    for number in ${remove_numbers//,/ }; do
        if [ -n "$number" ]; then
            echo "Removing label from PR #$number"
            gh pr edit "$number" --remove-label "forward port missing"
        fi
    done
}

main "$1"

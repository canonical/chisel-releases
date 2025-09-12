#!/usr/bin/env bash
# Run all tests.
# The tests can also be run individually.

__THIS_FILE_DIR__=$(realpath "$(dirname "$0")")

function main() {
    declare -a files
    declare -a results
    IFS=$'\n' read -r -d '' -a files < \
        <(find "$__THIS_FILE_DIR__" -name 'test_*.sh' | sort && printf '\0')
    for test in "${files[@]}"; do
        echo -e "\e[34mRunning test\e[0m: $test"
        bash "$test" "$@"
        results+=($?)
    done

    echo "=== OVERALL RESULTS ==="
    local overall_result=0
    for i in "${!results[@]}"; do
        local result="${results[$i]}"
        local file_name="${files[$i]}"
        if [[ $result -ne 0 ]]; then
            echo -e "\e[31mTest failed\e[0m: $file_name"
            overall_result=1
        else
            echo -e "\e[32mTest passed\e[0m: $file_name"
        fi
    done

    if [[ $overall_result -eq 0 ]]; then
        echo -e "\e[32mAll tests passed\e[0m"
    else
        echo -e "\e[31mSome tests failed\e[0m"
    fi
    return $overall_result
}

main "$@"
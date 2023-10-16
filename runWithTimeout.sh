timeout -s SIGKILL --foreground 25m bash ./composerNetValidation.sh

exit_status=$?
if [[ $exit_status -eq 124 ]]; then
    echo
    echo "Net Validation script timed out!"
fi

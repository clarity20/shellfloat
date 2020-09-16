function _shellfloat_assert_returnCode()
{
    _shellfloat_assert_functionReturn -c "$@"
    return $?
}

function _shellfloat_assert_returnString()
{
    echo -n "$(_shellfloat_assert_functionReturn "$@")"
    return $?
}


function _shellfloat_assert_equal()
{
    if [[ $# != 2 ]]; then
        echo USAGE: "$FUNCNAME" value1 value2
        echo Two input arguments required.
    fi
}

###############################################################################
# Internal functions
###############################################################################

function _shellfloat_assert_functionReturn()
{
    if [[ $# -lt 2 ]]; then
        echo 'USAGE: "$FUNCNAME" [-c] returnStringOrCode functionName [ functionArgs ... ]'
        echo "    By default, asserts against the string output by the function."
        echo "    Use -c to assert against the numeric return code instead."
        return ${__shellfloat_returnCodes[FAIL]}
    fi

    if [[ "${1,,}" == '-c' ]]; then
        mode=RETURN_CODE
        shift
    else
        mode=RETURN_STRING
    fi

    expectedReturn="$1"
    func="$2"
    shift 2

    args=("$@")

    local __shellfloat_isTesting=${__shellfloat_true}
    "$func" "${args[@]}"
    returnCode=$?
    __shellfloat_isTesting=${__shellfloat_false}

    # Fetch the return values. Their number will vary.
    declare -a returns
    _shellfloat_getReturnValues returns[0] returns[1] returns[2] \
        returns[3] returns[4] returns[5] returns[6] returns[7]

    resultFormat="%-5s"

    if [[ $mode == RETURN_STRING ]]; then
        if [[ "${returns[@]}" == "$expectedReturn" ]]; then
            printf $resultFormat ok
            return 0
        else
            printf $resultFormat FAIL
            return 1
        fi
    elif [[ $mode == RETURN_CODE ]]; then
        if [[ "$returnCode" == "$expectedReturn" ]]; then
            printf $resultFormat ok
            return 0
        else
            printf $resultFormat FAIL
            return 1
        fi
    fi

}


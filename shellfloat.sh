################################################################################
# shellfloat.sh
# Shell functions for floating-point arithmetic using only builtins
#
# Copyright (c) 2020 by Michael Wood. All rights reserved.
#
# Usage:
#
#    source thisPath/shellfloat.sh
#    add() { echo $(_shellfloat_add "$@"); }    # Rename as desired
#    mySum=$(add 202.895 6.00311)
# 
################################################################################

declare -A -r __shellfloat_returnCodes=(
    [SUCCESS]="0:Success"
    [FAIL]="1:General failure"
    [ILLEGAL_NUMBER]="2:Invalid decimal number argument: '%s'"
)

declare -A -r __shellfloat_numericTypes=(
    [INTEGER]=64
    [DECIMAL]=32
    [SCIENTIFIC]=16
)
declare -r __shellfloat_allTypes=$((__shellfloat_numericTypes[INTEGER] \
    + __shellfloat_numericTypes[DECIMAL] \
    + __shellfloat_numericTypes[SCIENTIFIC]))

declare -r __shellfloat_true=1
declare -r __shellfloat_false=0

function _shellfloat_getReturnCode()
{
    local errorName="$1"
    return ${__shellfloat_returnCodes[$errorName]%%:*}
}

function _shellfloat_warn()
{
    # Generate an error message and return control to the caller
    _shellfloat_handleError -r "$@"
    return $?
}

function _shellfloat_exit()
{
    # Generate an error message and EXIT THE SCRIPT / interpreter
    _shellfloat_handleError "$@"
}

function _shellfloat_handleError()
{
    # Hidden option "-r" causes return instead of exit
    if [[ "$1" == "-r" ]]; then
        returnDontExit=${__shellfloat_true}
        shift
    fi

    # Format of $1:  returnCode:msgTemplate
    [[ "$1" =~ ^([0-9]+):(.*) ]]
    returnCode=${BASH_REMATCH[1]}
    msgTemplate=${BASH_REMATCH[2]}
    shift
    
    # Display error msg, making parameter substitutions as needed
    msgParameters="$@"
    printf  "$msgTemplate" "${msgParameters[@]}"

    if [[ $returnDontExit == ${__shellfloat_true} ]]; then
        return $returnCode
    else
        exit $returnCode
    fi

}

function _shellfloat_validateAndParse()
{
    local n="$1"
    local isNegative=${__shellfloat_false}
    local numericType

    # Initialize return code to SUCCESS
    _shellfloat_getReturnCode SUCCESS
    local returnCode=$?

    
    # Accept integers
    if [[ "$n" =~ ^[-]?[0-9]+$ ]]; then
        numericType=${__shellfloat_numericTypes[INTEGER]}

        n=$(_shellfloat_factorOutMinusSign "$n")
        isNegative=$?

        echo $n
        return $((numericType|isNegative))

    # Accept decimals: leading digits (optional), decimal point, trailing digits
    elif [[ "$n" =~ ^[-]?([0-9]*)\.([0-9]+)$ ]]; then
        numericType=${__shellfloat_numericTypes[DECIMAL]}

        # Strip off negative sign (if present) and track it
        n=$(_shellfloat_factorOutMinusSign "$n")
        isNegative=$?

        echo ${BASH_REMATCH[1]} ${BASH_REMATCH[2]}
        return $((numericType|isNegative))

    # Accept scientific notation: 1e5, 2.44E+10, etc.
    elif [[ "$n" =~ (.*)[Ee](.*) ]]; then
        local significand=${BASH_REMATCH[1]}
        local exponent=${BASH_REMATCH[2]}

        # Significand may be either integer or decimal:  1 <= |signif| < 10
        if [[ "$significand" =~ ^[-]?([1-9]\.)?[0-9]+$ ]]; then
            # Break down and store the significand
            declare -a significandParts
            significandParts=($(_shellfloat_validateAndParse "$significand"))
            declare sigRet=$?
            local isSigNegative=$(($sigRet & $__shellfloat_true))

            # Exponent must be an integer with optional sign prefix
            if [[ "$exponent" =~ ^[-+]?[0-9]+$ ]]; then
                local isExpNegative=${__shellfloat_false}
                if [[ "$exponent" =~ ^[-] ]]; then
                    isExpNegative=${__shellfloat_true}
                    exponent=${exponent:1}
                else
                    exponent=$((exponent))    # Strip the + sign, if any
                fi

                numericType=${__shellfloat_numericTypes[SCIENTIFIC]}
                isNegative=$((isSigNegative<<1 | isExpNegative))
                echo ${significandParts[0]} ${significandParts[1]} $exponent
                return $((numericType|isNegative))
            fi
        fi

    # Reject everything else
    else
        _shellfloat_getReturnCode ILLEGAL_NUMBER
        returnCode=$?
        echo ""
        return $returnCode
    fi
}

function _shellfloat_factorOutMinusSign()
{
    local isNegative=$__shellfloat_false

    if [[ "${1:0:1}" == '-' ]]; then
        n=${n:1}
        isNegative=${__shellfloat_true}
    fi

    echo "$n"
    return $isNegative
}


function _shellfloat_add()
{
    local n1="$1"
    local n2="$2"
    declare -a numericParts
    declare -i flags
    local sign

    _shellfloat_getReturnCode "SUCCESS"
    declare -ri SUCCESS=$?
    _shellfloat_getReturnCode "ILLEGAL_NUMBER"
    declare -ri ILLEGAL_NUMBER=$?

    if [[ $# -eq 0 ]]; then
        echo "Usage: $FUNCNAME  addend_1  addend_2"
        return $SUCCESS
    fi

    numericParts=($(_shellfloat_validateAndParse "$n1"))
    flags=$?
    if [[ "$flags" == "$ILLEGAL_NUMBER" ]]; then
        _shellfloat_warn  ${__shellfloat_returnCodes[ILLEGAL_NUMBER]}  "$n1"
        return $?
    fi

    if [[ $# -eq 1 ]]; then
        echo $n1
        return $SUCCESS
    elif [[ $# -gt 2 ]]; then
        shift
        n2=$(_shellfloat_add "$@")
        local recursiveReturn=$?
        if [[ "$recursiveReturn" != "$SUCCESS" ]]; then
            echo $n2
            return $recursiveReturn
        fi
    fi

    declare isNegative1=$((flags & __shellfloat_true))
    declare type1=$((flags & __shellfloat_allTypes))
    local integerPart1=${numericParts[0]}
    local fractionalPart1=${numericParts[1]}

    numericParts=($(_shellfloat_validateAndParse "$n2"))
    flags=$?
    if [[ $flags == $ILLEGAL_NUMBER ]]; then
        _shellfloat_warn  ${__shellfloat_returnCodes[ILLEGAL_NUMBER]}  "$n2"
        return $?
    fi

    declare isNegative2=$((flags & __shellfloat_true))
    declare type2=$((flags & __shellfloat_allTypes))
    local integerPart2=${numericParts[0]}
    local fractionalPart2=${numericParts[1]}

    if [[ $type1 == ${__shellfloat_numericTypes[SCIENTIFIC]} \
       || $type2 == ${__shellfloat_numericTypes[SCIENTIFIC]} ]]; then
        echo Scientific notation not yet implemented.
        return 0
    fi

    # Right-pad the fractional parts with zeros to align by place value,
    # using string formatting techniques to avoid mathematical side-effects
    declare fractionalLen1=${#fractionalPart1}
    declare fractionalLen2=${#fractionalPart2}
    if ((fractionalLen1 > fractionalLen2)); then
        printf -v fractionalPart2 %-*s $fractionalLen1 $fractionalPart2
        fractionalPart2=${fractionalPart2// /0}
    elif ((fractionalLen2 > fractionalLen1)); then
        printf -v fractionalPart1 %-*s $fractionalLen2 $fractionalPart1
        fractionalPart1=${fractionalPart1// /0}
    fi
    declare unsignedFracLength=${#fractionalPart1}

    # Implement a sign convention that will enable us to detect carries by
    # comparing string lengths of addends and sums: propagate the sign across
    # both numeric parts (whether unsigned or zero).
    if ((isNegative1)); then
        fractionalPart1="-"$fractionalPart1
        integerPart1="-"$integerPart1
    fi
    if ((isNegative2)); then
        fractionalPart2="-"$fractionalPart2
        integerPart2="-"$integerPart2
    fi

    declare -i integerSum=0
    ((integerSum = integerPart1+integerPart2))

    # Summing the fractional parts is tricky: We need to override the shell's
    # default interpretation of leading zeros, but the operator for doing this
    # (the "10#" operator) cannot work directly with negative numbers. So we
    # break it all down.
    declare fractionalSum=0    # "-i" flag would prevent string manipulation
    if ((isNegative1)); then
        ((fractionalSum += (-1) * 10#${fractionalPart1:1}))
    else
        ((fractionalSum += 10#$fractionalPart1))
    fi
    if ((isNegative2)); then
        ((fractionalSum += (-1) * 10#${fractionalPart2:1}))
    else
        ((fractionalSum += 10#$fractionalPart2))
    fi

    unsignedFracSumLength=${#fractionalSum}
    if [[ "$fractionalSum" =~ ^[-] ]]; then
        ((unsignedFracSumLength--))
    fi

    # Restore any leading zeroes that were lost when adding
    if ((unsignedFracSumLength < unsignedFracLength)); then
        local lengthDiff=$((unsignedFracLength - unsignedFracSumLength))
        fractionalSum=$((10**lengthDiff))$fractionalSum
        fractionalSum=${fractionalSum#1}
    fi

    # Carry a digit from fraction to integer if required
    if ((fractionalSum!=0 && unsignedFracSumLength > unsignedFracLength)); then
        local carryAmount
        ((carryAmount=isNegative1?-1:1))
        ((integerSum += carryAmount))
        # Remove the leading 1-digit whether the fraction is + or -
        fractionalSum=${fractionalSum/1/}
    fi

    # Resolve sign discrepancies between the partial sums
    if ((integerSum < 0 && fractionalSum > 0)); then
        ((integerSum += 1))
        ((fractionalSum = 10**${#fractionalSum} - fractionalSum))
    elif ((integerSum > 0 && fractionalSum < 0)); then
        ((integerSum -= 1))
        ((fractionalSum = 10**${#fractionalSum} + fractionalSum))
    elif ((integerSum == 0 && fractionalSum < 0)); then
        integerSum="-"$integerSum
        ((fractionalSum *= -1))
    fi

    # Touch up the numbers for display
    if ((fractionalSum < 0)); then ((fractionalSum*=-1)); fi
    if ((fractionalSum)); then
        printf -v sum "%s.%s" $integerSum $fractionalSum
    else
        sum=$integerSum
    fi

    echo $sum
    return $SUCCESS
}

function _shellfloat_subtract()
{
    return 0
}

function _shellfloat_multiply()
{
    return 0
}

function _shellfloat_divide()
{
    return 0
}


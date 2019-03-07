#!/bin/bash
PASSED_INFO=""
FAILED_INFO=""

##############################################################################
#| BEG: user shell field
#/----------------------------------------------------------------------------
#| User shell script can be implemented at this field.

__CP_TEST_DURATION=180
__CP_TEST_LOG_DIR='/tmp'

# retrieve topology callback function
# param: $1 alsa params
function retrieved_param
{
    local params=$1
    [[ -z $params ]] && return 1

    local dev=$(dict_value $params 'dev')
    local channel=$(dict_value $params 'channel')
    local rate=$(dict_value $params 'rate')
    local fmt=$(dict_value $params 'fmt')

    local type=$(dict_value $params 'type')
    if [[ $type == capture || $type == both ]]; then
        local recOutput=$__CP_TEST_LOG_DIR/record-${dev}-c${channel}-r${rate}-f${fmt}-d${__CP_TEST_DURATION}-`date '+%s'`.wav
        arecord -D $dev --dump-hw-params -c $channel -r $rate -f $fmt -d $__CP_TEST_DURATION $recOutput
    else
        logi "Skip Device [$dev]($type)..."
    fi
}
#\----------------------------------------------------------------------------
#| END: user shell field
##############################################################################

##############################################################################
#| BEG: override the functions
#/----------------------------------------------------------------------------
function __case_passed
{
    echo -n #__OCCUPY_LINE_DELETE_ME__ case passed post response
}

function __case_failed
{
    echo -n #__OCCUPY_LINE_DELETE_ME__ case failed post response
}

function __case_blocked
{
    echo -n #__OCCUPY_LINE_DELETE_ME__ case blocked post response
}

function __execute
{
    # cannot execute this case speratedly.
    [[ -z $__auto__ ]] && return 0

    local caseInfo=$1
    __CP_TEST_LOG_DIR=$(dict_value "$caseInfo" "logdir" "/tmp")

    retrieve_tplg retrieved_param
}
#\----------------------------------------------------------------------------
#| END: override the functions
##############################################################################

#/----------------------------------------------------------------------------
#| manual executable entrance
#/----------------------------------------------------------------------------
[[ -z $__auto__ ]] && {
    __execute $*
    [[ $? -ne 0 ]] && __case_failed || __case_passed
}
#\----------------------------------------------------------------------------
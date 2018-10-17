#!/bin/bash

RUN_ID=foo7

stepDir () {
    local WHERE=$1
    local STEP_ID=$2
    local STATE_DIR=$WHERE/$RUN_ID/$STEP_ID
    mkdir -p $STATE_DIR
    echo $STATE_DIR
}

stateDir () {
    local STEP_ID=$1
    stepDir state $STEP_ID
}

outputDir () {
    local STEP_ID=$1
    stepDir output $STEP_ID
}

hashInputs () {
    cat $* | sha1sum
}

checkInputs () {
    local STEP_ID=$1
    shift
    local INPUTS=$*
    local INPUTS_HASH=$(hashInputs $INPUTS)
    local STATE_DIR=$(stateDir $STEP_ID)
    local HASH_FILE=$STATE_DIR/hash
    if test -a $HASH_FILE; then
        cmp $HASH_FILE <(echo $INPUTS_HASH) >&2
    else
        echo $INPUTS_HASH > $HASH_FILE
    fi
}

isDone () {
    local STEP_ID=$1
    test -a $(stateDir $STEP_ID)/done
}

finish () {
    local STEP_ID=$1
    date > $(stateDir $STEP_ID)/done
}

log () {
    >&2 echo $*
}

step () {
    local EXE=$1
    local INPUT=$2
    local STEP_ID=$(basename $EXE)
    local STATE_DIR=$(stateDir $STEP_ID)
    if isDone $STEP_ID; then
        log "nothing to do for step $STEP_ID"
        exit
    fi
    if ! checkInputs $STEP_ID $0 $EXE $INPUT; then
        log inputs changed
        exit
    fi
    local OUTPUT_DIR=$(outputDir $STEP_ID)
    $EXE $INPUT $OUTPUT_DIR > $STATE_DIR/log 2>&1
    local EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        finish
        echo $OUTPUT_DIR
        log step $STEP_ID finished
    else
        log step $STEP_ID failed with exit code $EXIT_CODE
    fi
}

A_OUT=$(step ./steps/a configs/a.conf)
B_OUT=$(step ./steps/b <(cat configs/b.conf; echo A_OUT=$A_OUT))


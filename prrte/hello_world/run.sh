#!/bin/bash -xe

# Final return value
FINAL_RTN=0

# Number of nodes - for accounting/verification purposes
# Default: 1
NUM_NODES=${CI_NUM_NODES:-${SLURM_NNODES:-1}}

NUM_TASKS=${SLURM_TASKS_PER_NODE:-5}
# Fix for slurm format 4x(2)
NUM_TASKS=$(echo "$NUM_TASKS" | grep -o '^[0-9]\+')
TIMEFORMAT="RUNTIME,%R,%U,%S"
_shutdown()
{
    # ---------------------------------------
    # Cleanup DVM
    # ---------------------------------------
    pterm

    exit $FINAL_RTN
}

# ---------------------------------------
# Start the DVM
# ---------------------------------------
if [ "x" = "x$CI_HOSTFILE" ] ; then
    prte --no-ready-msg &
else
    prte --no-ready-msg --hostfile $CI_HOSTFILE &
fi

date
# Wait for DVM to start
sleep 5
date


# ---------------------------------------
# Run the test - Hostname
# ---------------------------------------

time prun --map-by ppr:$NUM_TASKS:node hostname 2>&1 | tee output-hn.txt

# ---------------------------------------
# Verify the results
# ---------------------------------------
ERRORS=`grep ERROR output-hn.txt | wc -l`
if [[ $ERRORS -ne 0 ]] ; then
    echo "ERROR: Error string detected in the output"
    FINAL_RTN=1
    _shutdown
fi

LINES=`wc -l output-hn.txt | awk '{print $1}'`
if [[ $LINES -ne $(( $NUM_TASKS * $NUM_NODES )) ]] ; then
    echo "ERROR: Incorrect number of lines of output"
    FINAL_RTN=2
    _shutdown
fi


if [ $FINAL_RTN == 0 ] ; then
    echo "Success - hostname"
fi


# ---------------------------------------
# Run the test - Hello World (PMIx)
# ---------------------------------------
time prun --map-by ppr:$NUM_TASKS:node ./hello 2>&1 | tee output.txt
# ---------------------------------------
# Verify the results
# ---------------------------------------
ERRORS=`grep ERROR output.txt | wc -l`
if [[ $ERRORS -ne 0 ]] ; then
    echo "ERROR: Error string detected in the output"
    FINAL_RTN=1
    _shutdown
fi

LINES=`wc -l output.txt | awk '{print $1}'`
if [[ $LINES -ne $(( $NUM_TASKS * $NUM_NODES )) ]] ; then
    echo "ERROR: Incorrect number of lines of output"
    FINAL_RTN=2
    _shutdown
fi


if [ $FINAL_RTN == 0 ] ; then
    echo "Success - hello world"
fi

_shutdown


#!/bin/bash

# Taskwarrior extension that lets you attach notes to tasks
export EDITOR="${EDITOR:-nvim}"

SEARCHSTRING="${1:-'/./'}"
echo "$SEARCHSTRING"

TASKLIST="$(
    task rc.report.list.filter:'status:pending or status:waiting or status:completed' \
        rc.report.list.columns:'id,start.age,entry.age,depends.indicator,priority,project,tags,recur.indicator,scheduled.countdown,due,until.remaining,description.count,urgency,uuid' \
        rc.report.list.labels:'ID,Active,Age,D,P,Project,Tags,R,Sch,Due,Until,Description,Urg,UUID' \
        rc.defaultwidth=0 \
        rc.defaultheight=0 rc.verbose=nothing rc._forcecolor=on "$SEARCHSTRING" list
)"
echo "$TASKLIST"
exit

if [ "$(echo "$TASKLIST" | wc -l)" -gt 1 ]; then
    TASKLINE="$(echo "$TASKLIST" | fzf --ansi)"
    [ -z "$TASKLINE" ] && exit 1
else
    if [ -z "$TASKLIST" ]; then
        echo "no results"
        exit 1
    fi
    TASKLINE="$TASKLIST"
fi

TUUID="$(grep -o '[^ ]*$' <<<"$TASKLINE")"
if [ -z "$TUUID" ]; then
    echo "uuid not found"
    exit 1
fi

TASKLOCATION="$(task show data.location | sed 's/^[^ ]*[ ]*//g')"
if [ -z "$TASKLOCATION" ] || ! [ -e "$TASKLOCATION" ]; then
    echo "data location appears to be non-existent or corrupted"
    exit 1
fi

[ -e "$TASKLOCATION/yatext" ] || mkdir "$TASKLOCATION"/yatext

export EDITOR="${EDITOR:-nvim}"

$EDITOR "$TASKLOCATION/yatext/$TUUID.md"

#!/bin/bash

# Taskwarrior extension that lets you attach notes to tasks
export EDITOR="${EDITOR:-nvim}"

SEARCHSTRING="${1:-'/./'}"
echo "$SEARCHSTRING"

if [ -n "$1" ]; then
    case $1 in
    --help)
        echo "usage: yatext taskwarrior-filter-expression"
        exit
        ;;
    esac
fi

TASKLIST="$(
    task rc.report.list.filter:'status:pending or status:waiting or status:completed' \
        rc.report.list.columns:'id,start.age,entry.age,depends.indicator,priority,description.count,tags,recur.indicator,scheduled.countdown,due,until.remaining,project,urgency,uuid' \
        rc.report.list.labels:'ID,Active,Age,D,P,Description,Tags,R,Sch,Due,Until,Project,Urg,UUID' \
        rc.report.list.sort:'status-,start-,due+,project+,urgency-' \
        rc.defaultwidth=0 \
        rc.defaultheight=0 rc.verbose=nothing rc._forcecolor=on "$SEARCHSTRING" list
)"

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

TUUID="$(grep -o '[^ ]*$' <<<"$TASKLINE" | sed 's/\x1b\[[0-9;]*m//g')"
if [ -z "$TUUID" ]; then
    echo "uuid not found"
    exit 1
fi

TASKLOCATION="$(task rc.defaultheight=0 rc.verbose=nothing show data.location | sed 's/^[^ ]*[ ]*//g' | grep '.' | tail -1)"
TASKLOCATION="${TASKLOCATION/#\~/$HOME}"
echo "task $TASKLOCATION"

if [ -z "$TASKLOCATION" ] || ! [ -e "$TASKLOCATION" ]; then
    exit 1
fi

[ -e "$TASKLOCATION/yatext" ] || mkdir "$TASKLOCATION"/yatext

export EDITOR="${EDITOR:-nvim}"

if ! task "$TUUID" | grep -q 'yatext'; then
    task "$TUUID" annotate yatext note
    task "$TUUID" modify +yatext
    echo "initialized new yatext task"
fi

$EDITOR "$TASKLOCATION/yatext/$TUUID.md"

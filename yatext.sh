#!/bin/bash

# Taskwarrior extension that lets you attach notes to tasks
export EDITOR="${EDITOR:-nvim}"

SEARCHSTRING="${1:-'/./'}"

if [ -n "$1" ]; then
    case $1 in
    --help)
        echo "usage: yatext taskwarrior-filter-expression"
        exit
        ;;
    esac
fi

TASKLIST=""

searchtask() {
    TMPSEARCH="$1"
    if grep -q '^+[a-zA-Z0-9]*$' <<<"$TMPSEARCH"; then
        if ! {
            task tags | grep -q "^$TMPSEARCH"
        } &>/dev/null; then
            echo "partial tag found"
            NEWTAG="$(task rc.verbose:nothing tags | grep -o "^[^ ]*" | grep "^${TMPSEARCH#+}")"
            if [ -z "$NEWTAG" ]; then
                echo "no tag matches for $TMPSEARCH"
                exit 1
            fi
            if [ "$(echo "$NEWTAG" | wc -l)" -gt 1 ]; then
                NEWTAG="$(echo "$NEWTAG" | fzf)"
                [ -z "$NEWTAG" ] && exit 1
            fi
            echo "new tag $NEWTAG"
            TMPSEARCH="+$NEWTAG"
        fi
    fi

    # partial project search
    if grep -q '^p:[^ ]*$' <<<"$TMPSEARCH"; then
        echo "project search initiated"
        TMPPROJECT="$(grep -o ' p:[^*]* ' <<<"$TMPSEARCH" | grep -o '[^:]*$' | grep -o '^[^ ]*' | head -1)"
        NEWPROJECT="$(task rc.verbose:nothing projects | grep -v '^[0-9]* projects' | grep -v '(none)'| grep -o "^[^ ]*" | grep "^${TMPPROJECT#p:}")"
        if [ -z "$NEWPROJECT" ]; then
            echo "no project matches found"
            exit 1
        fi
        if [ "$(echo "$NEWPROJECT" | wc -l)" -gt 1 ]; then
            NEWPROJECT="$(echo "$NEWPROJECT" | fzf)"
            TMPSEARCH="project:$NEWPROJECT"
            echo "new search $TMPSEARCH"
            [ -z "$NEWPROJECT" ] && exit 1
        fi

    fi

    TASKLIST="$(
        task rc.report.list.filter:'status:pending or status:waiting or status:completed' \
            rc.report.list.columns:'id,start.age,entry.age,depends.indicator,priority,description.count,tags,recur.indicator,scheduled.countdown,due,until.remaining,project,urgency,uuid' \
            rc.report.list.labels:'ID,Active,Age,D,P,Description,Tags,R,Sch,Due,Until,Project,Urg,UUID' \
            rc.report.list.sort:'status-,start-,due+,project+,urgency-' \
            rc.defaultwidth=0 \
            rc.defaultheight=0 rc.verbose=nothing rc._forcecolor=on "$TMPSEARCH" list
    )"
}

searchtask "$SEARCHSTRING"

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

if [ -z "$TASKLOCATION" ] || ! [ -e "$TASKLOCATION" ]; then
    exit 1
fi

[ -e "$TASKLOCATION/yatext" ] || mkdir "$TASKLOCATION"/yatext

export EDITOR="${EDITOR:-nvim}"

$EDITOR "$TASKLOCATION/yatext/$TUUID.md"

if [ -e "$TASKLOCATION/yatext/$TUUID.md" ]; then
    if ! {
        task "$TUUID" information | grep -q 'yatext'
    } &>/dev/null; then
        task "$TUUID" annotate yatext note
        task "$TUUID" modify +yatext
        echo "initialized new yatext task"
    fi
fi

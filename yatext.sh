#!/bin/bash

# Taskwarrior extension that lets you attach notes to tasks
export EDITOR="${EDITOR:-nvim}"

SEARCHSTRING="${1:-'/./'}"

TASKLOCATION="$(task rc.defaultheight=0 rc.verbose=nothing show data.location | sed 's/^[^ ]*[ ]*//g' | grep '.' | tail -1)"
TASKLOCATION="${TASKLOCATION/#\~/$HOME}"

if [ -n "$1" ]; then
    case $1 in
    --help)
        echo "usage: yatext taskwarrior-filter-expression"
        exit
        ;;
    a)
        YACTION="append"
        shift 1
        SEARCHSTRING="${1:-'/./'}"
        ;;
    r)
        cd "$TASKLOCATION/yatext" || exit 1
        if [ -z "$2" ]; then
            GREPTEXT="$(dialog --inputbox searchtext 10 100)"
            [ -z "$GREPTEXT" ] && exit 1
        else
            GREPTEXT="$2"
        fi
        SEARCHLIST="$(rg --vimgrep "$GREPTEXT" . | sed 's/\([^:]*\):[0-9]*:[0-9]*:\(.*\)/\1;:; \2/g')"
        if [ -z "$SEARCHLIST" ]; then
            echo "no matches"
            exit
        fi
        if [ "$(wc -l <<<"$SEARCHLIST")" -gt 1 ]; then
            SEARCHFILE="$(fzf <<<"$SEARCHLIST")"
        else
            SEARCHFILE="$SEARCHLIST"
        fi
        SEARCHFILE="$(grep -o '^.*;:;' <<<"$SEARCHFILE" | sed 's/;:;//g')"

        [ -z "$SEARCHFILE" ] && exit

        $EDITOR "$SEARCHFILE"

        exit

        ;;
    *) ;;
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
        NEWPROJECT="$(task rc.verbose:nothing projects | grep -v '^[0-9]* projects' | grep -v '(none)' | grep -o "^[^ ]*" | grep "^${TMPPROJECT#p:}")"
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
            rc.defaultheight=0 rc.verbose=nothing rc._forcecolor=on "$TMPSEARCH" list |
            grep '....' | grep -v 'ID.*Age.*Description.*Tags' | grep -v '^1 t'
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

if [ -z "$TASKLOCATION" ] || ! [ -e "$TASKLOCATION" ]; then
    exit 1
fi

[ -e "$TASKLOCATION/yatext" ] || mkdir "$TASKLOCATION"/yatext

if ! [ -e "$TASKLOCATION/yatext/$TUUID.md" ]; then
    TTITLE="$(task rc.report.next.columns:'description' rc.report.next.labels:'description' rc.verbose=nothing rc.defaultwidth=0 next "$TUUID")"
    echo "TITLE $TTITLE"
    echo "# $TTITLE" >"$TASKLOCATION/yatext/$TUUID.md"
    echo "created new task"
fi

if [ -z "$YACTION" ]; then
    $EDITOR "$TASKLOCATION/yatext/$TUUID.md"
else
    case $YACTION in
    append)
        if [ -z "$2" ]; then
            APPENDTEXT="$(dialog --inputbox 'append text' 10 100)"
            [ -z "$APPENDTEXT" ] && exit 1
        else
            APPENDTEXT="$2"
        fi
        echo "$APPENDTEXT" >>"$TASKLOCATION/yatext/$TUUID.md"
        ;;
    ripgrep)

        if [ -z "$2" ]; then
            GREPTEXT="$(dialog --inputbox searchtext 10 100)"
            [ -z "$GREPTEXT" ] && exit 1
        else
            GREPTEXT="$2"
        fi
        SEARHCHFILE="$(rg --vimgrep "$GREPTEXT" . | sed 's/\([^:]*\):[0-9]*:[0-9]*:\(.*\)/\1\/ \2/g' | fzf | grep -o '^[^/]*')"
        echo "Searchfile $SEARHCHFILE"
        ;;
    esac

fi

if [ -e "$TASKLOCATION/yatext/$TUUID.md" ]; then
    if ! {
        task "$TUUID" information | grep -q 'yatext'
    } &>/dev/null; then
        task "$TUUID" annotate yatext note
        task "$TUUID" modify +yatext
        echo "initialized new yatext task"
    fi
fi

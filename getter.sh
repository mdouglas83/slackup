#!/bin/bash
START_TIME=$(date +%s)
DATA_DIR="./data"
AUTH_URL="https://westeros-inc.slack.com"
BASE_URL="https://slack.com/api"
EDGE_URL="https://edgeapi.slack.com/cache"
CONFIG_FILE="./config.env" && source "$CONFIG_FILE"
LOG_FILE="./script.log"

log() {
    local message="$1"
    local output="$(date +"%Y-%m-%d %T") $message"
    echo "$output" >> $LOG_FILE && echo "$output"
}

# Command-line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) less -c README.md; exit 0;;
        -n|--no_download) no_download=1 && log "[OPTIONS.] - no_download flag is SET";;
        -r|--re_download) re_download=1 && log "[OPTIONS.] - re_download flag is SET";;
    esac
    shift
done

progress_bar() {
    local current=$1
    local total=$2
    local width=28
    if [[ $total -gt 0 ]]; then
        local progress=$((current * width / total))
        local percent=$((current * 100 / total))
    else
        local progress=0
        local percent=100
    fi

    local color_bar="\e[36m"       # Cyan for the progress bar
    local color_percent="\e[36m"   # Cyan for the percentage
    local color_count="\e[32m"     # Green for the current count
    local color_total="\e[35m"     # Magenta for the total count
    local color_reset="\e[0m"      # Reset color

    if [[ $progress -gt 0 ]]; then progtext=$(printf '#%.0s' $(seq 1 $progress)); else progtext=''; fi
    if [[ $percent -lt 100 ]]; then progvoid=$(printf ' %.0s' $(seq 1 $((width - progress)))); else progvoid=''; fi
    
    printf -v progress_bar "[%s%s%s%s%s] %s%d%%%s (%s%d%s/%s%d%s)" \
        "$color_bar" "$progtext" "$color_reset" "$progvoid" "$color_reset" \
        "$color_percent" "$percent" "$color_reset" \
        "$color_count" "$current" "$color_reset" \
        "$color_total" "$total" "$color_reset"
    
    echo -ne "$progress_bar\r"
}

log "[SLACKUP.] Script started"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    log "[PRECHECK] jq is not installed, using surrogate binary."
    alias jq=./jq
fi

# Data Directory
mkdir -p "$DATA_DIR"
mkdir -p "$DATA_DIR/self"
mkdir -p "$DATA_DIR/team"
mkdir -p "$DATA_DIR/users"
mkdir -p "$DATA_DIR/channels"
mkdir -p "$DATA_DIR/shared"
mkdir -p "$DATA_DIR/mpims"
mkdir -p "$DATA_DIR/ims"
mkdir -p "$DATA_DIR/public_channels"
mkdir -p "$DATA_DIR/files"

# get_session_token() {
#     response=$(curl -L --cookie "$COOKIE_DATA" "$AUTH_URL")
#     echo "$response" > auth_response.txt
# }
# get_session_token

# user_boot_
# [x] self[]
# [ ] prefs[]
# [x] team[]
# [ ] workspaces[]
# [x] channels[]
# [x] ims[]
# [x] mpims[]
# [x] public_channels[]

fetch_data() {
    chan_file="$DATA_DIR/channels/channels.json"
    if [[ ! -f "$chan_file" ]]; then
        response=$(curl -s -X POST "$BASE_URL/client.userBoot" \
            -H "Authorization: Bearer $SLACK_TOKEN" \
            -H "Cookie: $COOKIE_DATA" \
            -H "Content-Type: application/json" \
            --data '{"_x_reason":"deferred-data", "include_min_version_bump_check":"1", "_x_sonic":"true", "_x_app_name":"client"}')
        if [[ $(echo "$response" | jq -r '.ok') != "true" ]]; then
            log "[ERROR...] ✕ $(echo "$response" | jq -r '.error')"
            return 1
        fi
        data=$(echo "$response" | jq)
        echo "$data" > "$chan_file"
    else
        data=$(cat "$chan_file")
    fi
    if [[ "$#" -gt 0 ]]; then
        data_file="$DATA_DIR/$1/$1.json"
        if [[ ! -f "$data_file" ]]; then
            data=$(echo "$data" | jq -r ".$1 // empty | @json" | jq '.')
            echo "$data" > "$data_file";
        else
            data=$(cat "$data_file")
        fi
    fi
    echo "$data"
}

fetch_channels() {
    channels=$(fetch_data channels)
    mpims=$(echo "$channels" | jq -r '.channels[] | select(.is_mpim) | @json' | jq -s '.') # move back down
    echo "$mpims" > "$DATA_DIR/mpims/mpims.json"
    shared=$(echo "$channels" | jq -r '.channels[] | select(.is_mpim == false) | @json' | jq -s '.')
    echo "$shared" > "$DATA_DIR/shared/shared.json"
    mpims=$(echo "$channels" | jq -r '.channels[] | select(.is_mpim) | @json' | jq -s '.')
    echo "$mpims" > "$DATA_DIR/mpims/mpims.json"
    ims=$(fetch_data ims)
    echo "$shared" | jq -r 'select(type == "array") | .[].id' | sed 's/$/:shared/' >> "$DATA_DIR/conversations.list"
    echo "$mpims" | jq -r 'select(type == "array") | .[].id' | sed 's/$/:mpims/' >> "$DATA_DIR/conversations.list"
    echo "$ims" | jq -r 'select(type == "array") | .[].id' | sed 's/$/:ims/' >> "$DATA_DIR/conversations.list"
}

fetch_public_channels() {
    response=$(curl -s -X POST "$BASE_URL/conversations.list" \
        -H "Authorization: Bearer $SLACK_TOKEN" \
        -H "Cookie: $COOKIE_DATA" \
        -H "Content-Type: application/json" \
        --data '{"limit":999, "types":"public_channel"}')
    if [[ $(echo "$response" | jq -r '.ok') != "true" ]]; then
        log "[ERROR...] ✕ $(echo "$response" | jq -r '.error')"
        return 1
    fi
    echo "$response" | jq -r > "$DATA_DIR/public_channels/public_channels.json"
    echo "$response" | jq -r '.channels[].id' | sed 's/$/:public_channels/' >> "$DATA_DIR/conversations.list"
}

fetch_user_data() {
    response=$(curl -s "$BASE_URL/users.list" \
        -H "Authorization: Bearer $SLACK_TOKEN" \
        -H "Cookie: $COOKIE_DATA" \
        -H "Content-Type: text/plain;charset=UTF-8")

    if [[ $(echo "$response" | jq -r '.ok') != "true" ]]; then
        log "[ERROR...] ✕ $(echo "$response" | jq -r '.error')"
        return 1
    fi
    echo "$response" | jq -r '.members' > "$DATA_DIR/users/users.json"
}

fetch_messages() {
    local type=$1
    local conversation=$2
    local latest="9999999999.999999"
    local file_path="$DATA_DIR/$type/$conversation/messages.json"
    local file_path_temp="$DATA_DIR/$type/$conversation/messages_temp.json"
    log "[CHANNELS] ● Fetching channel '$conversation' ($type)"
    mkdir -p "$DATA_DIR/$type/$conversation"    
    >"$file_path"
    message_total=0
    while true; do
        response=$(curl -s -X POST "$BASE_URL/conversations.history" \
            -H "Authorization: Bearer $SLACK_TOKEN" \
            -H "Cookie: $COOKIE_DATA" \
            -H "Content-Type: application/json" \
            --data '{"channel":"'$conversation'", "limit":999, "latest":"'$latest'"}')
        if [[ $(echo "$response" | jq -r '.ok') != "true" ]]; then
            log "[ERROR...] ✕ $(echo "$response" | jq -r '.error')"
            break
        fi
        messages=$(echo "$response" | jq -r '.messages[] | @json')
        message_count=$(echo "$response" | jq -r '.messages | length')
        echo "$messages" | jq -r >> "$file_path"
        latest=$(echo "$response" | jq -r '.messages[-1].ts')
        has_more=$(echo "$response" | jq -r '.has_more')
        log "[MESSAGES] ○ Retrieved $message_count messages ($(( message_total += message_count )) total)"
        progress_bar 0 $message_total
        if [[ "$has_more" != "true" ]]; then
            break
        fi
        sleep 1 # rate limits
    done
    if [[ ! $message_total -gt 0 ]]; then
        log "[NO MSGS.] △ No messages returned."
        echo "[]" > "$file_path"
        return
    fi
    local messages=$(cat "$file_path" | jq -s '.')
    echo "$messages" > "$file_path"
    >"$file_path_temp"
    jq -r '.[] | "\(.)\t\(.reply_count)\t\(.ts)"' "$file_path" | while IFS=$'\t' read -r message reply_count ts; do
        progress_bar $((++current_message)) $message_total
        if [[ "$reply_count" != null ]]; then
            log "[REPLIES.] ✓ Found $reply_count replies ($(( reply_total += reply_count )) total)"
            progress_bar $current_message $message_total
            replies=$(fetch_replies "$conversation" "$ts")
            echo "$message" | jq ".replies += $replies" >> "$file_path_temp"
        else
            echo "$message" | jq '.' >> "$file_path_temp"
        fi
        progress_bar $current_message $message_total
    done
    local messages=$(cat "$file_path_temp" | jq -s '.')
    echo "$messages" > "$file_path"
    rm -f "$file_path_temp"
}

fetch_replies() {
    local channel=$1
    local ts=$2
    response=$(curl -s -X GET "$BASE_URL/conversations.replies?channel=${channel}&ts=${ts}" \
        -H "Authorization: Bearer ${SLACK_TOKEN}" \
        -H "Cookie: $COOKIE_DATA" \
        -H "Content-Type: application/json")
    if [[ $(echo "$response" | jq -r '.ok') != "true" ]]; then
        log "[ERROR...] ✕ $(echo "$response" | jq -r '.error')"
        log "[ERROR...] ✕ $(echo "$response" | jq -r '.error')"
        return 1
    fi
    data=$(echo "$response" | jq -r '.messages[]' | jq -s '.')
    echo "$data"
}

download_files() {
    local conversation_id=$1
    local conversation_type=$2
    local json_file="$DATA_DIR/$conversation_type/$conversation_id/messages.json"
    local has_logged=0;
    if [[ -f "$json_file" ]]; then
        jq -r '.[] | select(.files != null) | .files[] | "\(.id)\t\(.name)\t\(.url_private)"' "$json_file" | while IFS=$'\t' read -r id name url_private; do
            if [[ "$url_private" != null ]]; then
                file_dir="$DATA_DIR/files/$id"
                if [[ ! -f "$file_dir/$name" || -n $re_download ]]; then
                    if [ $has_logged -eq 0 ]; then
                        log "[HTTP GET] ♥ Downloading files for conversation '$conversation_id' ($conversation_type)"
                        has_logged=1;
                    fi
                    mkdir -p "$file_dir"
                    curl -s -o "$file_dir/$name" -H "Authorization: Bearer $SLACK_TOKEN" -H "Cookie: $COOKIE_DATA" "$url_private"
                    log "[ 200 OK ] · $id|$url_private"
                fi
            fi
        done
        # local has_skipped_first=0;
        jq -r '.[] | select(.replies != null) | .replies[] | select(.files != null) | .files[] | "\(.id)\t\(.name)\t\(.url_private)"' "$json_file" | while IFS=$'\t' read -r id name url_private; do
            if [[ "$url_private" != null ]]; then
                file_dir="$DATA_DIR/files/$id"
                # in rare cases, the first reply message object is not the same as the parent message
                # a small haldful of files were getting skipped. since the -f check is fast, don't skip the first reply, it doesn't matter.
                # if [ $has_skipped_first -eq 0 ]; then
                #     has_skipped_first=1;
                # else
                    if [[ ! -f "$file_dir/$name" || -n $re_download ]]; then
                        mkdir -p "$file_dir"
                        curl -s -o "$file_dir/$name" -H "Authorization: Bearer $SLACK_TOKEN" -H "Cookie: $COOKIE_DATA" "$url_private"
                        log "[ 200 OK ] · $id|$url_private (in reply)"
                    fi
                # fi
            fi
        done
    fi
}

download_image() {
    local id=$1
    local key=$2
    local url=$3
    local file_name=$(basename "$url")
    local file_extension="${file_name##*.}"
    local file_path="./data/users/$id/$key.$file_extension"
    # if [ -f "$file_path" ]; then
    #     echo "File already exists: $file_path"
    # else
    if [ ! -f "$file_path" ]; then
        mkdir -p "$(dirname "$file_path")"
        curl -s -o "$file_path" -L "$url"
        if [ -f "$file_path" ]; then
            echo "Successful download to $file_path"
        else
            echo "Failed download to $file_path"
        fi
    fi
}

>$DATA_DIR/conversations.list

TEAM_ID=$(fetch_data team | jq -r '.id')
SELF_ID=$(fetch_data self | jq -r '.id')

fetch_channels
fetch_public_channels
fetch_user_data

# Loop through conversations and fetch messages + files
while IFS=: read -r conversation_id conversation_type; do
    if [[ -n "$conversation_id" && -n "$conversation_type" ]]; then
        fetch_messages "$conversation_type" "$conversation_id"
        if [[ -z $no_download ]]; then
            download_files "$conversation_id" "$conversation_type"
        fi
    else
        log "[ERROR...] ✕ Invalid conversation entry: $conversation_id $conversation_type"
    fi
done < "$DATA_DIR/conversations.list"

# download user images
jq -r '.[] | select(.profile != null) | . as $parent | .profile | to_entries[] | select(.key | startswith("image_")) | "\($parent.id),\(.key),\(.value)"' "$DATA_DIR/users/users.json" | while IFS=, read -r id key url; do
    download_image "$id" "$key" "$url"
done
# image_24 - 512 exist for all users, image_1024 for some (blown up or reduced from image_original). image_1024 and image_original are 1:1.
# *** To do: get messages.user_profile.image_72 & messages.replies.user_profile.image_72, save to ./data/users/$user/image_72.jpg|png ***
# local count=$(echo "$var" | wc -l) #total lines in a variable, might be useful later


# tar.gz backup? maybe -b/--backup switch to enable.
# tar -czvf slackup-backup.tar.gz .

end_time=$(date +%s)
elapsed_time=$(($end_time - $START_TIME))
hours=$((elapsed_time / 3600))
minutes=$(((elapsed_time % 3600) / 60))
seconds=$((elapsed_time % 60))
log "[SLACKUP.] Total elapsed time: ${hours}h ${minutes}m ${seconds}s"
log "[SLACKUP.] Script finished"

#!/bin/bash
set -euo pipefail

# Must be run as root
if [[ "$EUID" -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

# Check arguments: <archive-name> [--since 'duration']
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <archive-name> [--since 'duration']"
  echo "Example: $0 pg_logs_20250528 --since '6 hours ago'"
  exit 1
fi

ARCHIVE_NAME="$1"
shift

# Default 'since' time
JOURNAL_SINCE="1 year ago"

# Parse optional --since argument
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Missing value for --since"
        exit 1
      fi
      JOURNAL_SINCE="$1"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

WORK_DIR="/tmp/$(basename ${ARCHIVE_NAME})"
TAR_PATH="${ARCHIVE_NAME}.tar.gz"

echo "Target archive: $TAR_PATH"
echo "Temporary directory: $WORK_DIR"
echo "Journal since: $JOURNAL_SINCE"
mkdir -p "$WORK_DIR"
chmod 750 "$WORK_DIR"

# Run a SQL query as postgres user
run_psql() {
  sudo -u postgres psql -At -c "$1"
}

# Query PostgreSQL configuration
PGDATA_DIR=$(run_psql "SHOW data_directory;")
LOG_DIR=$(run_psql "SHOW log_directory;")
LOG_FILENAME=$(run_psql "SHOW log_filename;")
LOG_DEST=$(run_psql "SHOW log_destination;")
LOG_COLLECTOR=$(run_psql "SHOW logging_collector;")

echo "data_directory:       $PGDATA_DIR"
echo "log_directory:        $LOG_DIR"
echo "log_filename pattern: $LOG_FILENAME"
echo "log_destination:      $LOG_DEST"
echo "logging_collector:    $LOG_COLLECTOR"
echo

# If journald is used
if [[ "$LOG_DEST" == *stderr* ]] && [[ "$LOG_COLLECTOR" == "off" ]]; then
  echo "PostgreSQL logs are sent to journald only."
  echo "Extracting logs since: $JOURNAL_SINCE"
  journalctl -u postgresql --no-pager --since "$JOURNAL_SINCE" > "$WORK_DIR/journalctl_postgresql.log"
  echo "Journald logs saved to $WORK_DIR/journalctl_postgresql.log"
else
  # Resolve absolute path
  if [[ "$LOG_DIR" = /* ]]; then
    ABS_LOG_DIR="$LOG_DIR"
  else
    ABS_LOG_DIR="$PGDATA_DIR/$LOG_DIR"
  fi

  if [[ ! -d "$ABS_LOG_DIR" ]]; then
    echo "Error: log directory $ABS_LOG_DIR does not exist."
    exit 1
  fi

  echo "Found log directory: $ABS_LOG_DIR"
  cd "$ABS_LOG_DIR"
  shopt -s nullglob

  MATCHING_LOGS=($LOG_FILENAME*)

  if [[ ${#MATCHING_LOGS[@]} -eq 0 ]]; then
    echo "No matching log files found with pattern: $LOG_FILENAME*"
    exit 0
  fi

  for logfile in "${MATCHING_LOGS[@]}"; do
    cp -a "$logfile" "$WORK_DIR/${logfile}"
  done

  echo "Copied ${#MATCHING_LOGS[@]} log file(s) to: $WORK_DIR"
fi

# Create archive and cleanup
echo "Creating archive: $TAR_PATH"
tar -cvzf "$TAR_PATH" -C "$WORK_DIR/.." "$(basename $ARCHIVE_NAME)"
rm -rf "$WORK_DIR"
echo "Archive created and working directory removed."

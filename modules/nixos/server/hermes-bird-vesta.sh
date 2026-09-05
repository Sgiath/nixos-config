# Keep the command shape used by the existing digest scripts.
if [[ ! -r "$CREDS_FILE" ]]; then
  echo "Twitter credentials unavailable: $CREDS_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$CREDS_FILE"
export AUTH_TOKEN CT0

if [[ "${1:-}" == "user-tweets" ]]; then
  shift
  handle="${1:-}"
  shift || true
  count="10"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--count)
        count="${2:-10}"
        shift 2
        ;;
      *) shift ;;
    esac
  done
  cd "$SCRAPER_DIR"
  exec node "$SCRAPER_DIR/bird-user-tweets.mjs" "$handle" "$count"
fi

exec "$BIRD_BIN" "$@"

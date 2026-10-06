#!/bin/zsh
# Snapshots real third-party pages into self-contained HTML (SingleFile inlines CSS, images, fonts),
# the multi-MB documents the replay has to ingest. Output: pages/<id>.html (ignored by git).
# Usage: ./capture.sh [id ...]     (default: every page below)
set -u
cd ${0:A:h}
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
typeset -A URLS
URLS=(
  wikipedia-falcon9  https://en.wikipedia.org/wiki/List_of_Falcon_9_and_Falcon_Heavy_launches
  wikipedia-cities   https://en.wikipedia.org/wiki/List_of_largest_cities
  mdn-html-elements  https://developer.mozilla.org/en-US/docs/Web/HTML/Element
  guardian-front     https://www.theguardian.com/international
  cnn-home           https://www.cnn.com
  dailymail-home     https://www.dailymail.co.uk/home/index.html
  bbc-news           https://www.bbc.com/news
  nytimes-home       https://www.nytimes.com
  hn-front           https://news.ycombinator.com
  github-linux       https://github.com/torvalds/linux
  stackoverflow-q    https://stackoverflow.com/questions/11227809
  amazon-usb-c       "https://www.amazon.com/s?k=usb+c+cable"
)
ids=(${@:-${(ok)URLS}})
mkdir -p pages
for id in $ids; do
  url=$URLS[$id]; [ -z "$url" ] && { echo "unknown id $id"; continue; }
  echo "== $id"
  ./node_modules/.bin/single-file "$url" pages/$id.html \
    --browser-executable-path="$CHROME" --browser-headless=true \
    --browser-wait-until=networkIdle --browser-load-max-time=60000 \
    --browser-width=390 --browser-height=844 --load-deferred-images=true \
    --remove-hidden-elements=false --remove-unused-styles=false --compress-HTML=false \
    --user-agent="Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1" \
    2>&1 | tail -2
  ls -l pages/$id.html 2>/dev/null | awk '{printf "   %.1f MB\n", $5/1e6}'
done

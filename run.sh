#!/bin/sh
# vite build --watch: src/link.js is a symbolic link to store/a.js. The link is replaced by one
# to store/b.js (made beside it and renamed over it). Does the bundle hold the new target? The
# control is a plain edit of another module.
# Usage: npm install && sh run.sh [same|other]
#   same   the old and the new target have the same modification time
#   other  they have different modification times
cd "$(dirname "$0")" || exit 1
mode=${1:-other}
touch -d '2026-01-01 00:00:00' store/a.js
if [ "$mode" = same ]; then touch -d '2026-01-01 00:00:00' store/b.js; else touch -d '2026-02-02 00:00:00' store/b.js; fi
cat store/a.js store/b.js > /dev/null      # both targets have been read, as files in use have
has() { if grep -q "$1" dist/main.js 2>/dev/null; then echo yes; else echo no; fi; }
wait_for() { i=0; until [ "$(has "$1")" = yes ] || [ $i -ge "$2" ]; do sleep 1; i=$((i+1)); done; has "$1"; }
plain() { printf "export default '%s';\n" "$1" > src/plain.js; }
rm -rf dist fresh; plain PLAIN1; ln -sfn ../store/a.js src/link.js
./node_modules/.bin/vite build --ssr src/main.js --watch --outDir dist --logLevel silent > watch.log 2>&1 &
pid=$!
first=$(wait_for TARGET_A 60)
sleep 3
plain PLAIN2                                  # control: a plain edit
edit=$(wait_for PLAIN2 30)
sleep 2
ln -s ../store/b.js src/.link.tmp && mv -T src/.link.tmp src/link.js      # the link now points at b.js
retarget=$(wait_for TARGET_B 20)
plain PLAIN3                                  # a later edit of another module
later=$(wait_for PLAIN3 30)
sleep 2
after=$(has TARGET_B)
kill $pid 2>/dev/null
./node_modules/.bin/vite build --ssr src/main.js --outDir fresh --emptyOutDir --logLevel silent > /dev/null 2>&1
if grep -q TARGET_B fresh/main.js 2>/dev/null; then fresh=yes; else fresh=no; fi
rm -rf fresh dist src/link.js; plain PLAIN1
echo "RESULT target_times=$mode first_build=$first plain_edit_followed=$edit new_target_shown=$retarget later_edit_followed=$later new_target_after_later_edit=$after fresh_build=$fresh"

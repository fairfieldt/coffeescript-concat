#!/bin/sh

DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

/usr/bin/env node "$DIR/coffeescript-concat.js" $@

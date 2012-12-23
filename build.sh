#!/bin/sh

coffee -c coffeescript-concat.coffee
echo "#!/usr/bin/env node" | cat - coffeescript-concat.js > coffeescript-concat


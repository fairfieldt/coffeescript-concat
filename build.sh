#!/bin/sh

node_modules/.bin/coffee -c coffeescript-concat.coffee
echo "#!/usr/bin/env node" | cat - coffeescript-concat.js > coffeescript-concat
chmod +x coffeescript-concat

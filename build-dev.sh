#!/bin/bash
NODE_ENV=production node_modules/.bin/babel-node --presets 'react,es2015' react-dev/render_to_file.js
bundle exec jekyll serve --config "_config.yml,_config_dev.yml"

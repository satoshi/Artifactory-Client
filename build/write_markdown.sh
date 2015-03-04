#!/bin/bash

echo "[![Build Status](https://travis-ci.org/satoshi/Artifactory-Client.svg?branch=master)](https://travis-ci.org/satoshi/Artifactory-Client)" > README.md
echo "" >> README.md
perl -MPod::Markdown -e 'Pod::Markdown->new->filter(@ARGV)' ./lib/Artifactory/Client.pm >> README.md
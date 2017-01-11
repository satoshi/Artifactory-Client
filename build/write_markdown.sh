#!/bin/bash

# RUN THIS AFTER VERSIONS ARE BUMPED UP ELSEWHERE, AS README VERSION IS TAKEN FROM THERE

echo "[![Build Status](https://travis-ci.org/satoshi/Artifactory-Client.svg?branch=master)](https://travis-ci.org/satoshi/Artifactory-Client)" > README.md
echo "" >> README.md
perl -Ilocal/lib/perl5 -MPod::Markdown -e 'Pod::Markdown->new->filter(@ARGV)' ./lib/Artifactory/Client.pm >> README.md

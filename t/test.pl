#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Artifactory::Client;

my $args = {
    artifactory => 'http://localhost',
    port => 8081,
    repository => 'test'
};

my $client = Artifactory::Client->new( $args );
my $resp = $client->retrieve_artifact( '/test.zip' );

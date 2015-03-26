#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Getopt::Long;
use Data::Dumper;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Artifactory::Client;

my $opts = {};
GetOptions( $opts, 'server=s' );

my $args = {
    artifactory => 'http://' . $opts->{server},
    port        => 8081,
    repository  => 'testrepo',
};

my $client = Artifactory::Client->new($args);

subtest 'all_builds', sub {
    my $resp = $client->all_builds();
    my $uri  = $resp->request->uri;
    like( $uri, qr|/artifactory/api/build|, 'request made successfully' );
};

done_testing();

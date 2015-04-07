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

subtest 'all_builds', sub {
    my $client = setup();
    my $resp   = $client->all_builds();
    my $uri    = $resp->request->uri;
    like( $uri, qr|/artifactory/api/build|, 'all_builds called' );
};

subtest 'build_runs', sub {
    my $client = setup();
    my $resp   = $client->build_runs('foo');
    my $url    = $resp->request->uri;
    like( $url, qr|/artifactory/api/build/foo|, 'build_runs called' );
};

subtest 'build_upload', sub {
    my $client = setup();
    my $resp   = $client->build_upload("$Bin/data/test.json");
    my $url    = $resp->request->uri;
    like( $url, qr|/artifactory/api/build|, 'build_upload called' );
};

subtest 'build_info', sub {
    my $client = setup();
    my $resp   = $client->build_info( 'foo', 2 );
    my $url    = $resp->request->uri;
    like( $url, qr|/artifactory/api/build/foo/2|, 'build_info called' );
};

subtest 'builds_diff', sub {
    my $client = setup();
    my $resp   = $client->builds_diff( 'foo', 2, 1 );
    my $url    = $resp->request->uri;
    like( $url, qr|/api/build/foo/2\?diff=1|, 'builds_diff called' );
};

subtest 'build_promotion', sub {
    my $client  = setup();
    my $payload = { status => 'staged' };
    my $resp    = $client->build_promotion( 'foo', 2, $payload );
    my $url     = $resp->request->uri;
    like( $url, qr|/api/build/promote/foo/2|, 'build_promotion called' );
};

subtest 'delete_builds', sub {
    my $client = setup();
    my %args   = (
        name         => 'foo',
        buildnumbers => [ 1, 2, 3, 4, 5 ],
        artifacts    => 1,
        deleteall    => 1,
    );
    my $resp = $client->delete_builds(%args);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/build/foo\?buildNumbers=1,2,3,4,5&artifacts=1&deleteAll=1|, 'delete_builds called' );
};

done_testing();

sub setup {
    my $args = {
        artifactory => 'http://' . $opts->{server},
        port        => 8081,
        repository  => 'testrepo',
    };

    my $client = Artifactory::Client->new($args);
    return $client;
}

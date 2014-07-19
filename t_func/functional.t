#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Data::Dumper;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Artifactory::Client;

subtest 'retrieve_artifact without file', sub {
    my $client = setup();
    my $resp   = $client->retrieve_artifact('/test.zip');
    is( $resp->code, 200, 'retrieve succeessful' );
};

subtest 'retrieve_artifact with filename', sub {
    my $client = setup();
    my $file   = "$Bin/foobar.zip";
    my $resp   = $client->retrieve_artifact( '/test.zip', $file );
    is( $resp->code, 200, 'retrieve successful' );
    ok( -f $file, 'file exists' );
    unlink $file;
};

sub setup {
    my $args = {
        artifactory => 'http://localhost',
        port        => 8081,
        repository  => 'test'
    };
    return Artifactory::Client->new($args);
}

done_testing();

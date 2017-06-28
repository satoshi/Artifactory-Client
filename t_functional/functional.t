#!/usr/bin/perl

use strict;
use warnings;
use HTTP::Headers;
use LWP::UserAgent;
use Data::Dumper;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../local/lib/perl5";
use Artifactory::Client;

my $client = setup_client();

subtest 'test_function', sub {
    my $resp = $client->delete_certificate( 'foobar' );
    print Dumper($resp);
};

sub setup_client {
    my $h = HTTP::Headers->new();
    $h->authorization_basic( 'admin', 'password' );
    my $ua = LWP::UserAgent->new( default_headers => $h );

    my $args = {
        artifactory => 'http://localhost',
        port        => 8081,
        repository  => 'example-repo-local',
        ua          => $ua
    };
    return Artifactory::Client->new($args);
}

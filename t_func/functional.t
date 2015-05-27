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

subtest 'build_rename', sub {
    my $client = setup();
    my $resp   = $client->build_rename( 'foo', 'bar' );
    my $url    = $resp->request->uri;
    like( $url, qr|/api/build/rename/foo\?to=bar|, 'build_rename called' );
};

subtest 'push_build_to_bintray', sub {
    my $client = setup();
    my %args   = (
        buildName     => 'name',
        buildNumber   => 1,
        gpgPassphrase => 'foo',
        gpgSign       => 'true',
        payload       => { subject => "myUser" },
    );
    my $resp = $client->push_build_to_bintray(%args);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/build/pushToBintray/name/1\?gpgPassphrase=foo&gpgSign=true|, 'push_to_bintray called' );
};

subtest 'folder_info', sub {
    my $client = setup();
    my $resp   = $client->folder_info('foo/bar');
    my $url    = $resp->request->uri;
    like( $url, qr|/testrepo/foo/bar|, 'folder_info called' );
};

subtest 'file_info', sub {
    my $client = setup();
    my $resp   = $client->file_info('foo/bar');
    my $url    = $resp->request->uri;
    like( $url, qr|/testrepo/foo/bar|, 'file_info called' );
};

subtest 'item_last_modified', sub {
    my $client = setup();
    my $resp   = $client->item_last_modified('foo/bar');
    my $url    = $resp->request->uri;
    like( $url, qr|/testrepo/foo/bar\?lastModified|, 'file_info called' );
};

subtest 'file_statistics', sub {
    my $client = setup();
    my $resp   = $client->file_statistics('foo/bar');
    my $url    = $resp->request->uri;
    like( $url, qr|/testrepo/foo/bar\?stats|, 'file_statistics called' );
};

subtest 'item_properties', sub {
    my $client = setup();
    my $resp   = $client->item_properties( path => 'foo/bar', properties => [ 'foo', 'bar' ] );
    my $url    = $resp->request->uri;
    like( $url, qr|/testrepo/foo/bar\?properties=foo,bar|, 'item_properties called' );
};

subtest 'set_item_properties', sub {
    my $client = setup();
    my $resp   = $client->set_item_properties( path => 'foo/bar', properties => { foo => [ 'bar', 'baz' ] } );
    my $url    = $resp->request->uri;
    like( $url, qr|/testrepo/foo/bar\?properties=foo=bar,baz|, 'set_item_properties called' );
};

subtest 'delete_item_properties', sub {
    my $client = setup();
    my $resp   = $client->delete_item_properties( path => 'foo/bar', properties => [ 'bar', 'baz' ] );
    my $url    = $resp->request->uri;
    like( $url, qr|/testrepo/foo/bar\?properties=bar,baz|, 'delete item properties called' );
};

subtest 'retrieve_artifact', sub {
    my $client = setup();
    my $resp   = $client->retrieve_artifact('foo/bar');
    my $url    = $resp->request->uri;
    like( $url, qr|/testrepo/foo/bar|, 'retrieve_artifact called' );
};

subtest 'retrieve_latest_artifact', sub {
    my $client = setup();
    my $resp   = $client->retrieve_latest_artifact( path => 'foo/bar', version => '1.0', flag => 'snapshot' );
    my $url    = $resp->request->uri;
    like( $url, qr|/testrepo/foo/bar/1.0-SNAPSHOT/bar-1.0-SNAPSHOT.jar|, 'retrieve_latest_artifact called' );
};

subtest 'retrieve_build_artifacts_archive', sub {
    my $client  = setup();
    my $payload = {
        buildName   => 'foo',
        buildNumber => 15,
        archiveType => 'zip'
    };
    my $resp = $client->retrieve_build_artifacts_archive($payload);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/archive/buildArtifacts|, 'retrieve_build_artifacts_archive called' );
};

subtest 'trace_artifact_retrieval', sub {
    my $client = setup();
    my $resp   = $client->trace_artifact_retrieval('foo/bar');
    my $url    = $resp->request->uri;
    like( $url, qr|/testrepo/foo/bar\?trace|, 'trace_artifact_retrieval called' );
};

subtest 'archive_entry_download', sub {
    my $client = setup();
    my $resp   = $client->archive_entry_download( 'foo/bar', 'baz/goo' );
    my $url    = $resp->request->uri;
    like( $url, qr|/testrepo/foo/bar!baz/goo|, 'archive_entry_download called' );
};

subtest 'create_directory', sub {
    my $client = setup();
    my $resp   = $client->create_directory( path => 'foo/bar/' );
    my $url    = $resp->request->uri;
    like( $url, qr|/testrepo/foo/bar/|, 'create_directory called' );
    $client->delete_item('foo/bar');
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

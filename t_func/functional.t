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
    $client->delete_item('foo');
};

subtest 'deploy_artifact', sub {
    my $client = setup();
    my $resp   = $client->deploy_artifact( path => 'foo/bar' );
    my $url    = $resp->request->uri;
    like( $url, qr|/testrepo/foo/bar|, 'deploy_artifact called' );
    $client->delete_item('foo');
};

subtest 'deploy_artifact_by_checksum', sub {
    my $client = setup();
    my $resp   = $client->deploy_artifact_by_checksum( path => 'foo/bar', sha1 => 'abc' );    # would fail, and it's ok
    my $url    = $resp->request->uri;
    like( $url, qr|/testrepo/foo/bar|, 'deploy_artifact_by_checksum called' );
};

subtest 'deploy_artifacts_from_archive', sub {
    my $client = setup();
    my $resp   = $client->deploy_artifacts_from_archive( path => 'foo/bar.zip', file => "$Bin/data/foo.zip" );
    my $url    = $resp->request->uri;
    like( $url, qr|/testrepo/foo/bar\.zip|, 'deploy_artifacts_from_archive called' );
    $client->delete_item('foo');
};

subtest 'push_a_set_of_artifacts_to_bintray', sub {
    my $client = setup();
    my $resp   = $client->push_a_set_of_artifacts_to_bintray(
        descriptor    => 'foo',
        gpgPassphrase => 'top_secret',
        gpgSign       => 'true'
    );
    my $url = $resp->request->uri;
    like( $url, qr|/api/bintray/push|, 'push_a_set_of_artifacts_to_bintray called' );
};

subtest 'push_docker_tag_to_bintray', sub {
    my $client = setup();
    my $resp   = $client->push_docker_tag_to_bintray(
        dockerImage => 'jfrog/ubuntu:latest',
        async       => 'true'
    );
    my $url = $resp->request->uri;
    like( $url, qr|/bintray/docker/push/testrepo|, 'push_docker_tag_to_bintray called' );
};

subtest 'file_compliance_info', sub {
    my $client = setup();
    my $resp   = $client->file_compliance_info('foo/bar');
    my $url    = $resp->request->uri;
    like( $url, qr|/api/compliance/testrepo/foo/bar|, 'file_compliance_info called' );
};

subtest 'delete_item', sub {
    my $client = setup();
    $client->deploy_artifact( path => 'foo/bar' );
    my $resp = $client->delete_item('foo');
    my $url  = $resp->request->uri;
    like( $url, qr|/artifactory/testrepo/foo|, 'delete_item called' );
};

subtest 'copy_item', sub {
    my $client = setup();
    $client->deploy_artifact( path => 'foo/bar' );
    my $resp = $client->copy_item( from => '/testrepo/foo/bar', to => '/testrepo/bar/baz' );
    my $url = $resp->request->uri;
    like( $url, qr|/api/copy/testrepo/foo/bar\?to=/testrepo/bar/baz|, 'copy_item called' );
    $client->delete_item('foo');
    $client->delete_item('bar');
};

subtest 'move_item', sub {
    my $client = setup();
    $client->deploy_artifact( path => 'foo/bar' );
    my $resp = $client->move_item( from => '/testrepo/foo/bar', to => '/testrepo/bar/baz' );
    my $url = $resp->request->uri;
    like( $url, qr|/api/move/testrepo/foo/bar\?to=/testrepo/bar/baz|, 'move_item called' );
    $client->delete_item('foo');    # to kill off the directory
    $client->delete_item('bar');
};

subtest 'get_repository_replication_configuration', sub {
    my $client = setup();
    my $resp   = $client->get_repository_replication_configuration();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/replications/testrepo|, 'get_repository_replication_configuration called' );
};

subtest 'set_repository_replication_configuration', sub {
    my $client  = setup();
    my $payload = { foo => 'bar', };
    my $resp    = $client->set_repository_replication_configuration($payload);
    my $url     = $resp->request->uri;
    like( $url, qr|/api/replications/testrepo|, 'set_repository_replication_configuration called' );
};

subtest 'update_repository_replication_configuration', sub {
    my $client  = setup();
    my $payload = { foo => 'bar', };
    my $resp    = $client->update_repository_replication_configuration($payload);
    my $url     = $resp->request->uri;
    like( $url, qr|/api/replications/testrepo|, 'update_repository_replication_configuration called' );
};

subtest 'delete_repository_replication_configuration', sub {
    my $client = setup();
    my $resp   = $client->delete_repository_replication_configuration();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/replications/testrepo|, 'delete_repository_replication_configuration called' );
};

subtest 'scheduled_replication_status', sub {
    my $client = setup();
    my $resp   = $client->scheduled_replication_status();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/replication/testrepo|, 'scheduled_replication_status called' );
};

subtest 'pull_push_replication', sub {
    my $client  = setup();
    my $payload = {
        username => "replicator",
        password => "secret",
    };
    my $resp = $client->pull_push_replication( payload => $payload, path => '/foo' );
    my $url = $resp->request->uri;
    like( $url, qr|/api/replication/testrepo/foo|, 'pull_push_replication called' );
};

subtest 'create_or_replace_local_multi_push_replication', sub {
    my $client  = setup();
    my $payload = {
        cronExp                => "0 0/9 14 * * ?",
        enableEventReplication => 'true',
    };
    my $resp = $client->create_or_replace_local_multi_push_replication($payload);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/replications/multiple|, 'create_or_replace_local_multi_push_replication called' );
};

subtest 'update_local_multi_push_replication', sub {
    my $client  = setup();
    my $payload = {
        cronExp                => "0 0/9 14 * * ?",
        enableEventReplication => 'true',
    };
    my $resp = $client->update_local_multi_push_replication($payload);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/replications/multiple|, 'update_local_multi_push_replication called' );
};

subtest 'delete_local_multi_push_replication', sub {
    my $client = setup();
    my $resp   = $client->delete_local_multi_push_replication('http://10.0.0.1/artifactory/libs-release-local');
    my $url    = $resp->request->uri;
    like(
        $url,
        qr|/api/replications/testrepo\?url=http://10.0.0.1/artifactory/libs-release-local|,
        'delete_local_multi_push_replication called'
    );
};

subtest 'file_list', sub {
    my $client = setup();
    my $resp   = $client->file_list('/foo');
    my $url    = $resp->request->uri;
    like( $url, qr|/api/storage/testrepo/foo\?list|, 'file_list called' );
};

subtest 'artifactory_query_language', sub {
    my $client = setup();
    my $aql    = q|items.find(
    {
        "repo":{"$eq":"jcenter"}
    }
)|;
    my $resp = $client->artifactory_query_language($aql);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/search/aql|, 'artifactory_query_language called' );
};

subtest 'artifact_search', sub {
    my $client = setup();
    my %info   = (
        name  => 'foobar',
        repos => ['testrepo'],
    );
    my $resp = $client->artifact_search(%info);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/search/artifact\?name=foobar&repos=testrepo|, 'artifact_search called' );
};

subtest 'archive_entry_search', sub {
    my $client = setup();
    my %info   = (
        name  => 'foobar',
        repos => ['testrepo'],
    );
    my $resp = $client->archive_entry_search(%info);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/search/archive\?name=foobar&repos=testrepo|, 'archive_entry_search called' );
};

subtest 'gavc_search', sub {
    my $client = setup();
    my %info   = (
        g => 'foo',
        c => 'bar'
    );
    my $resp = $client->gavc_search(%info);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/search/gavc|, 'gavc_search called' );
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

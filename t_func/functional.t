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
    like( $url, qr|/libs-release-local/foo/bar|, 'folder_info called' );
};

subtest 'file_info', sub {
    my $client = setup();
    my $resp   = $client->file_info('foo/bar');
    my $url    = $resp->request->uri;
    like( $url, qr|/libs-release-local/foo/bar|, 'file_info called' );
};

subtest 'item_last_modified', sub {
    my $client = setup();
    my $resp   = $client->item_last_modified('foo/bar');
    my $url    = $resp->request->uri;
    like( $url, qr|/libs-release-local/foo/bar\?lastModified|, 'file_info called' );
};

subtest 'file_statistics', sub {
    my $client = setup();
    my $resp   = $client->file_statistics('foo/bar');
    my $url    = $resp->request->uri;
    like( $url, qr|/libs-release-local/foo/bar\?stats|, 'file_statistics called' );
};

subtest 'item_properties', sub {
    my $client = setup();
    my $resp   = $client->item_properties( path => 'foo/bar', properties => [ 'foo', 'bar' ] );
    my $url    = $resp->request->uri;
    like( $url, qr|/libs-release-local/foo/bar\?properties=foo,bar|, 'item_properties called' );
};

subtest 'set_item_properties', sub {
    my $client = setup();
    my $resp   = $client->set_item_properties( path => 'foo/bar', properties => { foo => [ 'bar', 'baz' ] } );
    my $url    = $resp->request->uri;
    like( $url, qr|/libs-release-local/foo/bar\?properties=foo=bar,baz|, 'set_item_properties called' );
};

subtest 'delete_item_properties', sub {
    my $client = setup();
    my $resp   = $client->delete_item_properties( path => 'foo/bar', properties => [ 'bar', 'baz' ] );
    my $url    = $resp->request->uri;
    like( $url, qr|/libs-release-local/foo/bar\?properties=bar,baz|, 'delete item properties called' );
};

subtest 'retrieve_artifact', sub {
    my $client = setup();
    my $resp   = $client->retrieve_artifact('foo/bar');
    my $url    = $resp->request->uri;
    like( $url, qr|/libs-release-local/foo/bar|, 'retrieve_artifact called' );
};

subtest 'retrieve_latest_artifact', sub {
    my $client = setup();
    my $resp   = $client->retrieve_latest_artifact( path => 'foo/bar', version => '1.0', flag => 'snapshot' );
    my $url    = $resp->request->uri;
    like( $url, qr|/libs-release-local/foo/bar/1.0-SNAPSHOT/bar-1.0-SNAPSHOT.jar|, 'retrieve_latest_artifact called' );
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
    like( $url, qr|/libs-release-local/foo/bar\?trace|, 'trace_artifact_retrieval called' );
};

subtest 'archive_entry_download', sub {
    my $client = setup();
    my $resp   = $client->archive_entry_download( 'foo/bar', 'baz/goo' );
    my $url    = $resp->request->uri;
    like( $url, qr|/libs-release-local/foo/bar!baz/goo|, 'archive_entry_download called' );
};

subtest 'create_directory', sub {
    my $client = setup();
    my $resp   = $client->create_directory( path => 'foo/bar/' );
    my $url    = $resp->request->uri;
    like( $url, qr|/libs-release-local/foo/bar/|, 'create_directory called' );
    $client->delete_item('foo');
};

subtest 'deploy_artifact', sub {
    my $client = setup();
    my $resp   = $client->deploy_artifact( path => 'foo/bar' );
    my $url    = $resp->request->uri;
    like( $url, qr|/libs-release-local/foo/bar|, 'deploy_artifact called' );
    $client->delete_item('foo');
};

subtest 'deploy_artifact_by_checksum', sub {
    my $client = setup();
    my $resp   = $client->deploy_artifact_by_checksum( path => 'foo/bar', sha1 => 'abc' );    # would fail, and it's ok
    my $url    = $resp->request->uri;
    like( $url, qr|/libs-release-local/foo/bar|, 'deploy_artifact_by_checksum called' );
};

subtest 'deploy_artifacts_from_archive', sub {
    my $client = setup();
    my $resp   = $client->deploy_artifacts_from_archive( path => 'foo/bar.zip', file => "$Bin/data/foo.zip" );
    my $url    = $resp->request->uri;
    like( $url, qr|/libs-release-local/foo/bar\.zip|, 'deploy_artifacts_from_archive called' );
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
    like( $url, qr|/bintray/docker/push/libs-release-local|, 'push_docker_tag_to_bintray called' );
};

subtest 'file_compliance_info', sub {
    my $client = setup();
    my $resp   = $client->file_compliance_info('foo/bar');
    my $url    = $resp->request->uri;
    like( $url, qr|/api/compliance/libs-release-local/foo/bar|, 'file_compliance_info called' );
};

subtest 'delete_item', sub {
    my $client = setup();
    $client->deploy_artifact( path => 'foo/bar' );
    my $resp = $client->delete_item('foo');
    my $url  = $resp->request->uri;
    like( $url, qr|/artifactory/libs-release-local/foo|, 'delete_item called' );
};

subtest 'copy_item', sub {
    my $client = setup();
    $client->deploy_artifact( path => 'foo/bar' );
    my $resp = $client->copy_item( from => '/libs-release-local/foo/bar', to => '/libs-release-local/bar/baz' );
    my $url = $resp->request->uri;
    like( $url, qr|/api/copy/libs-release-local/foo/bar\?to=/libs-release-local/bar/baz|, 'copy_item called' );
    $client->delete_item('foo');
    $client->delete_item('bar');
};

subtest 'move_item', sub {
    my $client = setup();
    $client->deploy_artifact( path => 'foo/bar' );
    my $resp = $client->move_item( from => '/libs-release-local/foo/bar', to => '/libs-release-local/bar/baz' );
    my $url = $resp->request->uri;
    like( $url, qr|/api/move/libs-release-local/foo/bar\?to=/libs-release-local/bar/baz|, 'move_item called' );
    $client->delete_item('foo');    # to kill off the directory
    $client->delete_item('bar');
};

subtest 'get_repository_replication_configuration', sub {
    my $client = setup();
    my $resp   = $client->get_repository_replication_configuration();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/replications/libs-release-local|, 'get_repository_replication_configuration called' );
};

subtest 'set_repository_replication_configuration', sub {
    my $client  = setup();
    my $payload = { foo => 'bar', };
    my $resp    = $client->set_repository_replication_configuration($payload);
    my $url     = $resp->request->uri;
    like( $url, qr|/api/replications/libs-release-local|, 'set_repository_replication_configuration called' );
};

subtest 'update_repository_replication_configuration', sub {
    my $client  = setup();
    my $payload = { foo => 'bar', };
    my $resp    = $client->update_repository_replication_configuration($payload);
    my $url     = $resp->request->uri;
    like( $url, qr|/api/replications/libs-release-local|, 'update_repository_replication_configuration called' );
};

subtest 'delete_repository_replication_configuration', sub {
    my $client = setup();
    my $resp   = $client->delete_repository_replication_configuration();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/replications/libs-release-local|, 'delete_repository_replication_configuration called' );
};

subtest 'scheduled_replication_status', sub {
    my $client = setup();
    my $resp   = $client->scheduled_replication_status();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/replication/libs-release-local|, 'scheduled_replication_status called' );
};

subtest 'pull_push_replication', sub {
    my $client  = setup();
    my $payload = {
        username => "replicator",
        password => "secret",
    };
    my $resp = $client->pull_push_replication( payload => $payload, path => '/foo' );
    my $url = $resp->request->uri;
    like( $url, qr|/api/replication/libs-release-local/foo|, 'pull_push_replication called' );
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
        qr|/api/replications/libs-release-local\?url=http://10.0.0.1/artifactory/libs-release-local|,
        'delete_local_multi_push_replication called'
    );
};

subtest 'file_list', sub {
    my $client = setup();
    my $resp   = $client->file_list('/foo');
    my $url    = $resp->request->uri;
    like( $url, qr|/api/storage/libs-release-local/foo\?list|, 'file_list called' );
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
        repos => ['libs-release-local'],
    );
    my $resp = $client->artifact_search(%info);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/search/artifact\?name=foobar&repos=libs-release-local|, 'artifact_search called' );
};

subtest 'archive_entry_search', sub {
    my $client = setup();
    my %info   = (
        name  => 'foobar',
        repos => ['libs-release-local'],
    );
    my $resp = $client->archive_entry_search(%info);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/search/archive\?name=foobar&repos=libs-release-local|, 'archive_entry_search called' );
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

subtest 'property_search', sub {
    my $client = setup();
    my %info   = (
        p     => [ 'v1', 'v2' ],
        repos => ['libs-release-local']
    );
    my $resp = $client->property_search(%info);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/search/prop|, 'property_search called' );
};

subtest 'checksum_search', sub {
    my $client = setup();
    my %info   = (
        md5   => '12345',
        repos => ['libs-release-local']
    );
    my $resp = $client->checksum_search(%info);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/search/checksum|, 'checksum_search called' );
};

subtest 'bad_checksum_search', sub {
    my $client = setup();
    my %info   = (
        type  => 'md5',
        repos => ['libs-release-local']
    );
    my $resp = $client->bad_checksum_search(%info);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/search/badChecksum|, 'bad_checksum_search called' );
};

subtest 'artifacts_not_downloaded_since', sub {
    my $client = setup();
    my %info   = (
        notUsedSince  => 12345,
        createdBefore => 12345,
        repos         => [ 'repo1', 'repo2' ]
    );
    my $resp = $client->artifacts_not_downloaded_since(%info);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/search/usage|, 'artifacts_not_downloaded_since called' );
};

subtest 'artifacts_with_date_in_date_range', sub {
    my $client = setup();
    my %info   = (
        from       => 12345,
        to         => 23456,
        repos      => ['libs-release-local'],
        dateFields => [ 'created', 'lastModified' ]
    );
    my $resp = $client->artifacts_with_date_in_date_range(%info);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/search/dates|, 'artifacts_with_date_in_date_range called' );
};

subtest 'artifacts_created_in_date_range', sub {
    my $client = setup();
    my %info   = (
        from  => 12345,
        to    => 23456,
        repos => ['libs-release-local']
    );
    my $resp = $client->artifacts_created_in_date_range(%info);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/search/creation|, 'artifacts_created_in_date_range called' );
};

subtest 'pattern_search', sub {
    my $client = setup();
    my $resp   = $client->pattern_search("some_pattern");
    my $url    = $resp->request->uri;
    like( $url, qr|/pattern\?pattern=libs-release-local:some_pattern|, 'pattern_search called' );
};

subtest 'builds_for_dependency', sub {
    my $client = setup();
    my $resp   = $client->builds_for_dependency( sha1 => '12345' );
    my $url    = $resp->request->uri;
    like( $url, qr|/search/dependency\?sha1=12345|, 'builds_for_dependency called' );
};

subtest 'license_search', sub {
    my $client = setup();
    my %args   = (
        approved   => 1,
        unapproved => 1,
        repos      => ['libs-release-local']
    );
    my $resp = $client->license_search(%args);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/search/license|, 'license_search called' );
};

subtest 'artifact_version_search', sub {
    my $client = setup();
    my %args   = (
        g     => 'foo',
        a     => 'bar',
        v     => '1.0',
        repos => ['libs-release-local']
    );
    my $resp = $client->artifact_version_search(%args);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/search/versions|, 'artifact_version_search called' );
};

subtest 'artifact_latest_version_search_based_on_layout', sub {
    my $client = setup();
    my %args   = (
        g     => 'foo',
        a     => 'bar',
        v     => '1.0',
        repos => ['libs-release-local']
    );
    my $resp = $client->artifact_latest_version_search_based_on_layout(%args);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/search/latestVersion|, 'artifact_latest_version_search_based_on_layout called' );
};

subtest 'artifact_latest_version_search_based_on_properties', sub {
    my $client = setup();
    my %args   = (
        os        => 'win',
        license   => 'GPL',
        listFiles => 1,
        repo      => '_any',
        path      => 'a/b',
    );
    my $resp = $client->artifact_latest_version_search_based_on_properties(%args);
    my $url  = $resp->request->uri;
    like( $url, qr|/artifactory/api/versions|, 'artifact_latest_version_search_based_on_properties called' );
};

subtest 'build_artifacts_search', sub {
    my $client = setup();
    my %args   = (
        buildNumber => 15,
        buildName   => 'foobar'
    );
    my $resp = $client->build_artifacts_search(%args);
    my $url  = $resp->request->uri;
    like( $url, qr|/api/search/buildArtifacts|, 'build_artifacts_search called' );
};

subtest 'get_users', sub {
    my $client = setup();
    my $resp   = $client->get_users();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/security/users|, 'get_users called' );
};

subtest 'get_user_details', sub {
    my $client = setup();
    my $resp   = $client->get_user_details('anonymous');
    my $url    = $resp->request->uri;
    like( $url, qr|/api/security/users/anonymous|, 'get_user_details called' );
};

subtest 'get_user_encrypted_password', sub {
    my $client = setup();
    my $resp   = $client->get_user_encrypted_password();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/security/encryptedPassword|, 'get_user_encrypted_password called' );
};

subtest 'create_or_replace_user', sub {
    my $client = setup();
    my $resp   = $client->create_or_replace_user( 'davids', password => 'foobar' );
    my $url    = $resp->request->uri;
    like( $url, qr|/api/security/users/davids|, 'create_or_replace_user called' );
};

subtest 'update_user', sub {
    my $client = setup();
    my $resp   = $client->update_user( 'davids', password => 'foobar' );
    my $url    = $resp->request->uri;
    like( $url, qr|/api/security/users/davids|, 'update_user called' );
};

subtest 'delete_user', sub {
    my $client = setup();
    my $resp   = $client->delete_user('davids');
    my $url    = $resp->request->uri;
    like( $url, qr|/api/security/users/davids|, 'delete_user called' );
};

subtest 'get_groups', sub {
    my $client = setup();
    my $resp   = $client->get_groups();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/security/groups|, 'get_groups called' );
};

subtest 'get_group_details', sub {
    my $client = setup();
    my $resp   = $client->get_group_details('dev-leads');
    my $url    = $resp->request->uri;
    like( $url, qr|/api/security/groups/dev-leads|, 'get_group_details called' );
};

subtest 'create_or_replace_group', sub {
    my $client = setup();
    my %args   = ( name => 'dev-leads' );
    my $resp   = $client->create_or_replace_group( 'dev-leads', %args );
    my $url    = $resp->request->uri;
    like( $url, qr|/api/security/groups/dev-leads|, 'create_or_replace_group called' );
};

subtest 'update_group', sub {
    my $client = setup();
    my %args   = ( name => 'dev-leads' );
    my $resp   = $client->update_group( 'dev-leads', %args );
    my $url    = $resp->request->uri;
    like( $url, qr|/api/security/groups/dev-leads|, 'update_group called' );
};

subtest 'delete_group', sub {
    my $client = setup();
    my $resp   = $client->delete_group('dev-leads');
    my $url    = $resp->request->uri;
    like( $url, qr|/api/security/groups/dev-leads|, 'delete_group called' );
};

subtest 'get_permission_targets', sub {
    my $client = setup();
    my $resp   = $client->get_permission_targets();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/security/permissions|, 'get_permission_targets called' );
};

subtest 'get_permission_target_details', sub {
    my $client = setup();
    my $resp   = $client->get_permission_target_details('populateCaches');
    my $url    = $resp->request->uri;
    like( $url, qr|/api/security/permissions/populateCaches|, 'get_permission_target_details called' );
};

subtest 'create_or_replace_permission_target', sub {
    my $client = setup();
    my %args   = ( name => 'populateCaches' );
    my $resp   = $client->create_or_replace_permission_target( 'populateCaches', %args );
    my $url    = $resp->request->uri;
    like( $url, qr|/api/security/permissions/populateCaches|, 'create_or_replace_permission_target called' );
};

subtest 'delete_permission_target', sub {
    my $client = setup();
    my $resp   = $client->delete_permission_target('populateCaches');
    my $url    = $resp->request->uri;
    like( $url, qr|/api/security/permissions/populateCaches|, 'delete_permission_target' );
};

subtest 'effective_item_permissions', sub {
    my $client = setup();
    my $resp   = $client->effective_item_permissions('foobar');
    my $url    = $resp->request->uri;
    like( $url, qr|/api/storage/libs-release-local/foobar\?permissions|, 'effective_item_permissions called' );
};

subtest 'security_configuration', sub {
    my $client = setup();
    my $resp   = $client->security_configuration();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/system/security|, 'security_configuration called' );
};

subtest 'activate_master_key_encryption', sub {
    my $client = setup();
    my $resp   = $client->activate_master_key_encryption();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/system/encrypt|, 'activate_master_key_encryption called' );
};

subtest 'deactivate_master_key_encryption', sub {
    my $client = setup();
    my $resp   = $client->deactivate_master_key_encryption();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/system/decrypt|, 'deactivate_master_key_encryption called' );
};

subtest 'set_gpg_public_key', sub {
    my $client = setup();
    my $resp   = $client->set_gpg_public_key( key => read_key() );
    my $url    = $resp->request->uri;
    like( $url, qr|/api/gpg/key/public|, 'set_gpg_public_key called' );
};

subtest 'get_gpg_public_key', sub {
    my $client = setup();
    my $resp   = $client->get_gpg_public_key();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/gpg/key/public|, 'get_gpg_public_key called' );
};

subtest 'set_gpg_private_key', sub {
    my $client = setup();
    my $resp   = $client->set_gpg_private_key( key => read_key() );
    my $url    = $resp->request->uri;
    like( $url, qr|/api/gpg/key/private|, 'set_gpg_private_key called' );
};

subtest 'set_gpg_pass_phrase', sub {
    my $client = setup();
    my $resp   = $client->set_gpg_pass_phrase('foobar');
    my $url    = $resp->request->uri;
    like( $url, qr|/api/gpg/key/passphrase|, 'set_gpg_pass_phrase called' );
};

subtest 'get_repositories', sub {
    my $client = setup();
    my $resp   = $client->get_repositories();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/repositories|, 'get_repositories called' );
};

subtest 'repository_configuration', sub {
    my $client = setup();
    my $resp   = $client->repository_configuration('libs-release-local');
    my $url    = $resp->request->uri;
    like( $url, qr|/api/repositories/libs-release-local|, 'repository_configuration called' );
};

subtest 'create_or_replace_repository_configuration', sub {
    my $client  = setup();
    my $payload = { foo => 'bar' };
    my $resp    = $client->create_or_replace_repository_configuration( 'foo', $payload, pos => 5 );
    my $url     = $resp->request->uri;
    like( $url, qr|/api/repositories/foo\?pos=5|, 'create_or_replace_repository_configuration called' );
};

subtest 'update_repository_configuration', sub {
    my $client  = setup();
    my $payload = { foo => 'bar' };
    my $resp    = $client->update_repository_configuration( 'foo', $payload );
    my $url     = $resp->request->uri;
    like( $url, qr|/api/repositories/foo|, 'update_repository_configuration called' );
};

subtest 'delete_repository', sub {
    my $client = setup();
    my $resp   = $client->delete_repository('foobarbaz');
    my $url    = $resp->request->uri;
    like( $url, qr|/api/repositories/foobarbaz|, 'delete_repository called' );
};

subtest 'calculate_yum_repository_metadata', sub {
    my $client = setup();
    my $resp   = $client->calculate_yum_repository_metadata( async => 1 );
    my $url    = $resp->request->uri;
    like( $url, qr|/api/yum/libs-release-local\?async=1|, 'calculate_yum_repository_metadata called' );
};

subtest 'calculate_nuget_repository_metadata', sub {
    my $client = setup();
    my $resp   = $client->calculate_nuget_repository_metadata();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/nuget/libs-release-local/reindex|, 'calculate_nuget_repository_metadata called' );
};

subtest 'calculate_npm_repository_metadata', sub {
    my $client = setup();
    my $resp   = $client->calculate_npm_repository_metadata();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/npm/libs-release-local/reindex|, 'calculate_npm_repository_metadata called' );
};

subtest 'calculate_maven_index', sub {
    my $client = setup();
    my $resp   = $client->calculate_maven_index( repos => ['libs-release-local'], force => 1 );
    my $url    = $resp->request->uri;
    like( $url, qr|/api/maven\?repos=libs-release-local&force=1|, 'calculate_maven_index called' );
};

subtest 'calculate_maven_metadata', sub {
    my $client = setup();
    my $resp   = $client->calculate_maven_metadata('/org/acme');
    my $url    = $resp->request->uri;
    like( $url, qr|/api/maven/calculateMetadata/libs-release-local/org/acme|, 'calculate_maven_metadata called' );
};

subtest 'calculate_debian_repository_metadata', sub {
    my $client = setup();
    my $resp   = $client->calculate_debian_repository_metadata();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/deb/reindex/libs-release-local|, 'calculate_debian_repository_metadata called' );
};

subtest 'system_info', sub {
    my $client = setup();
    my $resp   = $client->system_info();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/system|, 'system_info called' );
};

subtest 'system_health_ping', sub {
    my $client = setup();
    my $resp   = $client->system_health_ping();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/system/ping|, 'system_health_ping called' );
};

subtest 'general_configuration', sub {
    my $client = setup();
    my $resp   = $client->general_configuration();
    my $url    = $resp->request->uri;
    like( $url, qr|/api/system/configuration|, 'general_configuration called' );
};

done_testing();

sub setup {
    my $h = HTTP::Headers->new();
    $h->authorization_basic( 'admin', 'password' );
    my $ua = LWP::UserAgent->new( default_headers => $h );

    my $args = {
        artifactory => 'http://' . $opts->{server},
        port        => 8081,
        repository  => 'libs-release-local',
        ua          => $ua,
    };

    my $client = Artifactory::Client->new($args);
    return $client;
}

sub read_key {
    open( my $fh, '<', "$Bin/data/gpg_public.key" );
    chomp( my @lines = <$fh> );
    return join( "\n", @lines );
}

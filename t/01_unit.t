#!/usr/local/bin/perl

use strict;
use warnings;
use Test::More;
use Data::Dumper;
use JSON;
use FindBin qw($Bin);
use WWW::Mechanize;
use URI::http;
use HTTP::Request;
use lib "$Bin/../lib";
use Artifactory::Client;

# it became silly to do this in every subtest
no strict 'refs';
no warnings 'redefine';

my $artifactory = 'http://example.com';
my $port = 7777;
my $repository = 'repository';

my %mock_responses = (
    http_201 => bless( { '_rc' => 201 }, 'HTTP::Response' ),
    http_404 => bless( { '_rc' => 404, '_headers' => bless( {}, 'HTTP::Headers' ) }, 'HTTP::Response' ),
    http_200 => bless( { '_rc' => 200 }, 'HTTP::Response' ),
    http_204 => bless( { '_rc' => 204 }, 'HTTP::Response' ),
);

subtest 'check if ua is LWP::UserAgent', sub {
    my $client = setup();
    isa_ok( $client->{ ua }, 'LWP::UserAgent' );

    my $ua = WWW::Mechanize->new();
    $client->ua( $ua );
    isa_ok( $client->{ ua }, 'WWW::Mechanize' );
};

subtest 'deploy_artifact with properties and content', sub {
    my $client = setup();
    my $properties = {
        one => ['two'],
        baz => ['three', 'four'],
    };
    my $path = '/unique_path';
    my $content = "content of artifact";

    local *{ 'LWP::UserAgent::put' } = sub {
        return $mock_responses{ http_201 };
    };

    my $resp = $client->deploy_artifact( path => $path, properties => $properties, content => $content );
    is( $resp->is_success, 1, 'request came back successfully' );
   
    local *{ 'LWP::UserAgent::get' } = sub {
        my ( $self, $url ) = @_;

        if ( $url eq "$artifactory:$port/api/storage/$repository/unique_path?properties" ) {
            return bless( {
                '_content' => '{
                    "properties" : {
                        "baz" : [ "three", "four" ],
                        "one" : [ "two" ]
                    }
                }',
                '_rc' => 200,
                '_headers' => bless( {}, 'HTTP::Headers' ),
            }, 'HTTP::Response' );
        }
        else {
            return bless( {
                '_content' => 'content of artifact',
                '_rc' => 200,
                '_headers' => bless( {}, 'HTTP::Headers' ),
            }, 'HTTP::Response' );
        }
    };
 
    my $resp2 = $client->item_properties( path => $path );
    my $scalar = from_json( $resp2->decoded_content );
    is_deeply( $scalar->{ properties }, $properties, 'properties are correct' );
    my $artifact_url = "$artifactory:$port/$repository$path";
    my $resp3 = $client->get( $artifact_url );
    is( $resp3->decoded_content, $content, 'content matches' );
};

subtest 'set_item_properties on non-existing artifact', sub {
    my $client = setup();
    my $properties = {
        one => [1],
        two => [2],
    };

    local *{ 'LWP::UserAgent::put' } = sub {
        return $mock_responses{ http_404 }
    };
    my $resp = $client->set_item_properties( path => '/unique_path', properties => $properties );
    is( $resp->code, 404, 'got 404 for attempting to set props on non-existent artifact' );
};

subtest 'deploy artifact by checksum', sub {
    my $client = setup();
    my $path = '/unique_path';
    my $sha1 = 'da39a3ee5e6b4b0d3255bfef95601890afd80709'; # sha-1 of 0 byte file

    local *{ 'LWP::UserAgent::put' } = sub {
        return bless( {
            '_request' => bless( { 
                '_headers' => bless( { 
                    'x-checksum-sha1' => $sha1,
                    'x-checksum-deploy' => 'true',
                }, 'HTTP::Headers' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };

    my $resp = $client->deploy_artifact_by_checksum( path => $path, sha1 => $sha1 );
    is( $resp->request()->header( 'x-checksum-deploy' ), 'true', 'x-checksum-deploy set' );
    is( $resp->request()->header( 'x-checksum-sha1' ), $sha1, 'x-checksum-sha1 set' );
    
    local *{ 'LWP::UserAgent::put' } = sub {
        return $mock_responses{ http_404 }
    };

    my $resp2 = $client->deploy_artifact_by_checksum( path => $path ); # no sha-1 on purpose
    is( $resp2->code, 404, 'got 404 since no sha1 was supplied' );
};

subtest 'item properties', sub {
    my $client = setup();
    my $properties = {
        this => ['here', 'there'],
        that => ['one'],
    };

    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_content' => '{
                "properties" : {
                    "that" : [ "one" ]
                }
            }',
            '_headers' => bless( {}, 'HTTP::Headers' ),
        }, 'HTTP::Response' );
    };

    my $resp = $client->item_properties( path => '/unique_path', properties => ['that'] );
    my $scalar = from_json( $resp->decoded_content );
    is_deeply( $scalar->{ properties }, { that => ['one'] }, 'property content is correct' );
};

subtest 'retrieve artifact', sub {
    my $client = setup();
    my $content = "content of artifact";

    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_content' => 'content of artifact',
            '_headers' => bless( {}, 'HTTP::Headers' ),
        }, 'HTTP::Response' );
    };

    my $resp = $client->retrieve_artifact( '/unique_path' );
    is( $resp->decoded_content, $content, 'artifact retrieved successfully' );
};

subtest 'all_builds', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::get' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->all_builds();
    is( $resp->is_success, 1, 'fetched all builds' );
};

subtest 'delete_item', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::delete' } = sub {
        return $mock_responses{ http_204 };
    };
    my $resp = $client->delete_item( '/unique_path' );
    is( $resp->code, 204, 'deleted item' );
};

subtest 'build_runs', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::get' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->build_runs( 'api-test' );
    is( $resp->code, 200, 'got build runs' );
};

subtest 'build_info', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::get' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->build_info( 'api-test', 14 );
    is( $resp->code, 200, 'got build info' );
};

subtest 'builds_diff', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::get' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->builds_diff( 'api-test', 14, 10 );
    is( $resp->code, 200, 'got builds diff' );
};

subtest 'build_promotion', sub {
    my $client = setup();
    my $payload = {
        status => "staged",
    };

    local *{ 'LWP::UserAgent::post' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->build_promotion( 'api-test', 10, $payload );
    is( $resp->code, 200, 'build_promotion succeeded' );
};

subtest 'delete_build', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::delete' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = 'http://example.com:7777/artifactory/api/build/api-test?buildNumbers=1&artifacts=0&deleteAll=0')}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };

    my $resp = $client->delete_build( name => 'api-test', buildnumbers => [1],  artifacts => 0, deleteall => 0 );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr/buildNumbers=1/, 'buildNumbers showed up' );
    like( $url_in_response, qr/artifacts=0/, 'artifacts showed up' );
    like( $url_in_response, qr/deleteAll=0/, 'deleteAll showed up' );
};

subtest 'build_rename', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::post' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->build_rename( 'api-test', 'something' );
    is( $resp->code, 200, 'build_rename succeeded' );
};

subtest 'folder_info', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::get' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->folder_info( "/some_dir" );
    is( $resp->code, 200, 'folder_info succeeded' );
};

subtest 'file_info', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::get' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->file_info( "/somefile" );
    is( $resp->code, 200, 'file_info succeeded' );
};

subtest 'item_last_modified', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::get' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->item_last_modified( '/unique_path' );
    is( $resp->code, 200, 'item_last_modified succeeded' );
};

subtest 'file_statistics', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::get' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->file_statistics( '/unique_path' );
    is( $resp->code, 200, 'file_statistics succeeded' );
};

subtest 'delete_item_properties', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::delete' } = sub {
        return $mock_responses{ http_204 };
    };
    my $resp = $client->delete_item_properties( path => '/unique_path', properties => ['first'] );
    is( $resp->code, 204, 'delete_item_properties succeeded' );
};

subtest 'retrieve_latest_artifact', sub {
    my $client = setup();
    my $path = '/unique_path';

    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = 'http://example.com:7777/artifactory/repository/unique_path/0.9.9-snapshot/unique_path-0.9.9-snapshot.jar')}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->retrieve_latest_artifact( path => $path, snapshot => 'snapshot', version => '0.9.9' );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr/\Qunique_path-0.9.9-snapshot.jar\E/, 'snapshot URL looks sane' );

    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = 'http://example.com:7777/artifactory/repository/unique_path/release/unique_path-release.jar')}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    $resp = $client->retrieve_latest_artifact( path => $path, release => 'release' );
    my $url_in_response2 = $resp->request->uri;
    like( $url_in_response2, qr/\Qunique_path-release.jar\E/, 'release URL looks sane' );

    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = 'http://example.com:7777/artifactory/repository/unique_path/1.0-integration/unique_path-1.0-integration.jar')}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    $resp = $client->retrieve_latest_artifact( path => $path, version => '1.0', integration => 'integration' );
    my $url_in_response3 = $resp->request->uri;
    like( $url_in_response3, qr/\Qunique_path-1.0-integration.jar\E/, 'integration URL looks sane' );
};

subtest 'retrieve_build_artifacts_archive', sub {
   my $client = setup();
   my $payload = {
       buildName => 'api-test',
       buildNumber => 10,
       archiveType => 'zip',
   };

   local *{ 'LWP::UserAgent::post' } = sub {
        return $mock_responses{ http_200 };
   };
   my $resp = $client->retrieve_build_artifacts_archive( $payload );
   is( $resp->code, 200, 'retrieve_build_artifacts_archive succeeded' );
};

subtest 'trace_artifact_retrieval', sub {
    my $client = setup();

   local *{ 'LWP::UserAgent::get' } = sub {
        return $mock_responses{ http_200 };
   };
    my $resp = $client->trace_artifact_retrieval( '/unique_path' );
    is( $resp->code, 200, 'trace_artifact_retrieval succeeded' );
};

subtest 'archive_entry_download', sub {
    my $client = setup();
    my $path = '/unique_path';
    my $archive_path = '/archive_path';

    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/repo$path!$archive_path")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->archive_entry_download( $path, $archive_path );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr/$path!$archive_path/, 'archive_entry_download succeeded' );
};

subtest 'create_directory', sub {
    my $client = setup();
    my $dir = '/unique_dir/';

    local *{ 'LWP::UserAgent::put' } = sub {
        return $mock_responses{ http_201 };
    };
    my $resp = $client->create_directory( path => $dir );
    is( $resp->code, 201, 'create_directory succeeded' );
};

subtest 'deploy_artifacts_from_archive', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::put' } = sub {
        return $mock_responses{ http_200 };
    };

    local *{ 'File::Slurp::read_file' } = sub {
        # no-op, unit test reads no file
    };
    my $resp = $client->deploy_artifacts_from_archive( file => 'test.zip', path => '/some_path/test.zip' );
    is( $resp->code, 200, 'deploy_artifacts_from_archive worked' );
};

subtest 'file_compliance_info', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/compliance/repo/some_path")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->file_compliance_info( '/some_path' );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/compliance|, 'requsted URL looks sane' );
};

subtest 'copy_item', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::post' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->copy_item( from => "/repo/some_path", to => "/repo2/some_path2" );
    is( $resp->code, 200, 'copy_item worked' );
};

subtest 'move_item', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::post' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->move_item( from => "/repo/some_path", to => "/repo2/some_path2" );
    is( $resp->code, 200, 'move_item worked' );
};

subtest 'request method call', sub {
    my $client = setup();
    my $req = HTTP::Request->new( GET => 'http://www.example.com/' );

    local *{ 'LWP::UserAgent::request' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->request( $req );
    is( $resp->code, 200, 'request method call worked' );
};

subtest 'scheduled_replication_status', sub {
    my $client = setup();
    local *{ 'LWP::UserAgent::get' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->scheduled_replication_status();
    is( $resp->code, 200, 'scheduled_replication_status succeeded' );
};

subtest 'get_repository_replication_configuration', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/replications/foobar")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->get_repository_replication_configuration();
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/replications|, 'requsted URL looks sane' );
};

subtest 'set_repository_replication_configuration', sub {
    my $client = setup();
    my $payload = {
        username => "admin",
    };

    local *{ 'LWP::UserAgent::put' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/replications/foobar")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->set_repository_replication_configuration( $payload );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/replications|, 'requsted URL looks sane' );
};

subtest 'update_repository_replication_configuration', sub {
    my $client = setup();
    my $payload = {
        username => "admin",
    };

    local *{ 'LWP::UserAgent::post' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/replications/foobar")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->update_repository_replication_configuration( $payload );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/replications|, 'requsted URL looks sane' );
};

subtest 'pull_push_replication', sub {
    my $client = setup();
    my $payload = {
        username => 'replicator',
    };
    my $path = '/foo/bar';
    
    local *{ 'LWP::UserAgent::post' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/replication/foobar")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->pull_push_replication( payload => $payload, path => $path );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/replication|, 'requsted URL looks sane' );
};

subtest 'file_list', sub {
    my $client = setup();
    my %opts = (
        deep => 1,
        depth => 1,
        listFolders => 1,
        mdTimestamps => 1,
        includeRootPath => 1,
    );
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->file_list( '/some_dir/', %opts );
    is( $resp->code, 200, 'got 200 back' );
};

subtest 'artifact_search', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::get' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->artifact_search( name => 'some_file', repos => [ 'foobar' ] );
    is( $resp->code, 200, 'got 200 back' );
};

subtest 'archive_entry_search', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/search/archive")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->archive_entry_search( name => 'archive', repos => [ 'repo' ] );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/search/archive|, 'requsted URL looks sane' );
};

subtest 'gavc_search', sub {
    my $client = setup();
    my %args = (
        g => 'foo',
        a => 'bar',
        v => '1.0',
        c => 'abc',
        repos => [ 'repo', 'abc' ],
    );

    local *{ 'LWP::UserAgent::get' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->gavc_search( %args );
    is( $resp->code, 200, 'got 200 back' );
};

subtest 'property_search', sub {
    my $client = setup();
    my %args = (
        key => [ 'val1', 'val2' ],
        repos => [ 'repo', 'abc' ],
    );
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->property_search( %args );
    is( $resp->code, 200, 'got 200 back' );
};

subtest 'checksum_search', sub {
    my $client = setup();
    my %args = (
        md5sum => '12345',
        repos => [ 'repo', 'abc' ],
    );

    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/search/checksum")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->checksum_search( %args );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/search/checksum|, 'requsted URL looks sane' );
};

subtest 'bad_checksum_search', sub {
    my $client = setup();
    my %args = (
        type => 'md5',
        repos => [ 'repo', 'abc' ],
    );
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/search/badChecksum")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->bad_checksum_search( %args );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/search/badChecksum|, 'requsted URL looks sane' );
};

subtest 'artifacts_not_downloaded_since', sub {
    my $client = setup();
    my %args = (
        notUsedSince => 12345,
        createdBefore => 12345,
        repos => [ 'repo', 'abc' ],
    );
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/search/usage")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->artifacts_not_downloaded_since( %args );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/search/usage|, 'requsted URL looks sane' );
};

subtest 'artifacts_created_in_date_range', sub {
    my $client = setup();
    my %args = (
        from => 12345,
        repos => [ 'repo', 'abc' ],
    );
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/search/creation")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->artifacts_created_in_date_range( %args );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/search/creation|, 'requsted URL looks sane' );
};

subtest 'pattern_search', sub {
    my $client = setup();
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->pattern_search( 'killer/*/ninja/*/*.jar' );
    is( $resp->code, 200, 'request succeeded' );
};

subtest 'builds_for_dependency', sub {
    my $client = setup();
    my %args = (
        sha1 => 'abcde',
    );
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/search/dependency")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->builds_for_dependency( %args );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/search/dependency|, 'requsted URL looks sane' );
};

subtest 'license_search', sub {
    my $client = setup();
    my %args = (
        unapproved => 1,
        unknown => 1,
        notfound => 0,
        neutral => 0,
        approved => 0,
        autofind => 0,
        repos => [ 'foo' ],
    );
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/search/license")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->license_search( %args );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/search/license|, 'requsted URL looks sane' );
};

subtest 'artifact_version_search', sub {
    my $client = setup();
    my %args = (
        g => 'foo',
        a => 'bar',
        v => '1.0',
        remote => 1,
        repos => [ 'dist-packages' ],
    );
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/search/versions")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->artifact_version_search( %args );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/search/versions|, 'requsted URL looks sane' );
};

subtest 'artifact_latest_version_search_based_on_layout', sub {
    my $client = setup();
    my %args = (
        g => 'foo',
        a => 'bar',
        v => '1.0',
        remote => 1,
        repos => [ 'foo' ],
    );
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/search/latestVersion")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->artifact_latest_version_search_based_on_layout( %args );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/search/latestVersion|, 'requsted URL looks sane' );
};

subtest 'artifact_latest_version_search_based_on_properties', sub {
    my $client = setup();
    my %args = (
        repo => '_any',
        path => '/a/b',
        listFiles => 1,
    );
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/versions")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->artifact_latest_version_search_based_on_properties( %args );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/versions|, 'requsted URL looks sane' );
};

subtest 'build_artifacts_search', sub {
    my $client = setup();
    my %args = (
        buildName => 'api-test',
        buildNumber => 14,
    );
    
    local *{ 'LWP::UserAgent::post' } = sub {
        return return $mock_responses{ http_200 };
    };
    my $resp = $client->build_artifacts_search( %args );
    is( $resp->code, 200, 'request succeeded' );
};

subtest 'get_users', sub {
    my $client = setup();
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/security/users")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->get_users();
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/security/users|, 'requsted URL looks sane' );
};

subtest 'get_user_details', sub {
    my $client = setup();
    my $user = 'foo';
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/security/users/$user")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->get_user_details( $user );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/security/users/$user|, 'requsted URL looks sane' );
};

subtest 'create_or_replace_user', sub {
    my $client = setup();
    my $user = 'foo';
    my %args = (
        name => 'foo',
    );

    local *{ 'LWP::UserAgent::put' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/security/users/$user")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->create_or_replace_user( $user, %args );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/security/users/$user|, 'requsted URL looks sane' );
};

subtest 'update_user', sub {
    my $client = setup();
    my $user = 'foo';
    my %args = (
        name => 'foo',
    );

    local *{ 'LWP::UserAgent::post' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/security/users/$user")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->update_user( $user, %args );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/security/users/$user|, 'requsted URL looks sane' );
};

subtest 'delete_user', sub {
    my $client = setup();
    my $user = 'foo';
    
    local *{ 'LWP::UserAgent::delete' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/security/users/$user")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->delete_user( $user );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/security/users/$user|, 'requsted URL looks sane' );
};

subtest 'get_groups', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/security/groups")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->get_groups();
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/security/groups|, 'requsted URL looks sane' );
};

subtest 'get_group_details', sub {
    my $client = setup();
    my $group = 'dev-leads';
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/security/groups/$group")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->get_group_details( $group );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/security/groups/$group|, 'requsted URL looks sane' );
};

subtest 'create_or_replace_group', sub {
    my $client = setup();
    my $group = 'dev-leads';
    my %args = (
        name => 'dev-leads',
    );

    local *{ 'LWP::UserAgent::put' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/security/groups/$group")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->create_or_replace_group( $group, %args );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/security/groups/$group|, 'requsted URL looks sane' );
};

subtest 'update_group', sub {
    my $client = setup();
    my $group = 'dev-leads';
    my %args = (
        name => 'dev-leads',
    );

    local *{ 'LWP::UserAgent::post' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/security/groups/$group")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->update_group( $group, %args );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/security/groups/$group|, 'requsted URL looks sane' );
};

subtest 'delete_group', sub {
    my $client = setup();
    my $group = 'dev-leads';
    
    local *{ 'LWP::UserAgent::delete' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/security/groups/$group")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->delete_group( $group );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/security/groups/$group|, 'requsted URL looks sane' );
};

subtest 'get_permission_targets', sub {
    my $client = setup();
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/security/permissions")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->get_permission_targets();
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/security/permissions|, 'requsted URL looks sane' );
};

subtest 'get_permission_target_details', sub {
    my $client = setup();
    my $name = 'populateCaches';
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/security/permissions/$name")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->get_permission_target_details( $name );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/security/permissions/$name|, 'requsted URL looks sane' );
};

subtest 'create_or_replace_permission_target', sub {
    my $client = setup();
    my $name = 'populateCaches';
    my %args = (
        name => 'populateCaches',
    );
    
    local *{ 'LWP::UserAgent::put' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/security/permissions/$name")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->create_or_replace_permission_target( $name, %args );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/security/permissions/$name|, 'requsted URL looks sane' );
};

subtest 'delete_permission_target', sub {
    my $client = setup();
    my $permission = 'populateCaches';
    
    local *{ 'LWP::UserAgent::delete' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/security/permissions/$permission")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->delete_permission_target( $permission );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/security/permissions/$permission|, 'requsted URL looks sane' );
};

subtest 'effective_item_permissions', sub {
    my $client = setup();
    my $path = '/foobar';
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return $mock_responses{ http_200 };
    };
    my $resp = $client->effective_item_permissions( $path );
    is( $resp->code, 200, 'request came back successfully' );
};

subtest 'security_configuration', sub {
    my $client = setup();
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/system/security")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->security_configuration();
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/system/security|, 'requsted URL looks sane' );
};

subtest 'get_repositories', sub {
    my $client = setup();

    local *{ 'LWP::UserAgent::get' } = sub {
        return $mock_responses{ http_200 };
    }; 
    my $resp = $client->get_repositories();
    is( $resp->code, 200, 'got repositories' );
};

subtest 'repository_configuration', sub {
    my $client = setup();
    my $repo = 'dist-packages';
    my %args = (
        type => 'local',
    );
    
    local *{ 'LWP::UserAgent::get' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/repositories/$repo")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->repository_configuration( $repo, %args );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/repositories/$repo|, 'requsted URL looks sane' );
};

subtest 'create_or_replace_repository_configuration', sub {
    my $client = setup();
    my $repo = 'foo';
    my $payload = {
        key => "local-repo1",
    };
    my %args = (
        pos => 2,
    );

    local *{ 'LWP::UserAgent::put' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/repositories/$repo")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->create_or_replace_repository_configuration( $repo, $payload, %args );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/repositories/$repo|, 'requsted URL looks sane' );
};

subtest 'update_repository_configuration', sub {
    my $client = setup();
    my $repo = 'foo';
    my $payload = {
        key => "local-repo1",
    };

    local *{ 'LWP::UserAgent::post' } = sub {
        return bless( {
            '_request' => bless( {
            '_uri' => bless( do{\(my $o = "http://example.com:7777/artifactory/api/repositories/$repo")}, 'URI::http' ),
            }, 'HTTP::Request' )
        }, 'HTTP::Response' );
    };
    my $resp = $client->update_repository_configuration( $repo, $payload );
    my $url_in_response = $resp->request->uri;
    like( $url_in_response, qr|/api/repositories/$repo|, 'requsted URL looks sane' );
};

done_testing();

sub setup {
    my $args = {
        artifactory => $artifactory,
        port => $port,
        repository => $repository,
    };
    return Artifactory::Client->new( $args );
}

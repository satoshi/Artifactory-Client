#!/usr/local/bin/perl

use strict;
use warnings;
use Test::More;
use Data::Dumper;
use JSON;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Artifactory::Client;
use URI::http;

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

done_testing();

sub setup {
    my $args = {
        artifactory => $artifactory,
        port => $port,
        repository => $repository,
    };
    return Artifactory::Client->new( $args );
}

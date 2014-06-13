package Artifactory::Client;

use strict;
use warnings;
use Moose;
use LWP::UserAgent;
use Data::Dumper;
use URI::Escape;
use namespace::autoclean;
use JSON;
use File::Basename;
use File::Slurp;

=head1 NAME

Artifactory::Client - Perl client for Artifactory REST API

=head1 VERSION

Version 0.6.1

=cut

our $VERSION = '0.6.1';

=head1 SYNOPSIS

This is a Perl client for Artifactory REST API: https://www.jfrog.com/confluence/display/RTF/Artifactory+REST+API
Every public method provided in this module returns a HTTP::Response object.

    use Artifactory::Client;

    my $args = {
        artifactory => 'http://artifactory.server.com',
        port => 8080,
        repository => 'myrepository',
        ua => LWP::UserAgent->new() # LWP::UserAgent-like object is pluggable.  Default is LWP::UserAgent.
    };

    my $client = Artifactory::Client->new( $args );
    my $path = '/foo'; # path on artifactory

    # Properties are a hashref of key-arrayref pairs.  Note that value must be an arrayref even for a single element.
    # This is to conform with Artifactory which treats property values as a list.
    my $properties = {
        one => ['two'],
        baz => ['three'],
    };
    my $content = "content of artifact";

    # Name of methods are taken straight from Artifactory REST API documentation.  'Deploy Artifact' would map to
    # deploy_artifact method, like below.  The caller gets HTTP::Response object back.
    my $resp = $client->deploy_artifact( path => $path, properties => $properties, content => $content );

    # Custom requests can also be made via usual get / post / put / delete requests.
    my $resp = $client->get( 'http://artifactory.server.com/path/to/resource' );

    # drop in a different UserAgent:
    my $ua = WWW::Mechanize->new();
    $client->ua( $ua ); # now uses WWW::Mechanize to make requests

Note on testing:
This module is developed using Test-Driven Development.  I have functional tests making real API calls, however they
contain proprietary information and I am not allowed to open source them.  The unit tests included are dumbed-down
version of my functional tests.  They should serve as a detailed guide on how to make API calls.

=cut

has 'artifactory' => (
    is => 'ro',
    isa => 'Str',
);

has 'port' => (
    is => 'ro',
    isa => 'Int',
    default => 80
);

has 'ua' => (
    is => 'rw',
    isa => 'LWP::UserAgent',
    builder => '_build_ua'
);

has 'repository' => (
    is => 'ro',
    isa => 'Str',
);

=head1 GENERIC METHODS

=cut

=head2 get( @args )

Invokes GET request on LWP::UserAgent-like object; params are passed through.

=cut

sub get {
    my ( $self, @args ) = @_;
    return $self->_request( 'get', @args );
}

=head2 post( @args )

nvokes POST request on LWP::UserAgent-like object; params are passed through.

=cut

sub post {
    my ( $self, @args ) = @_;
    return $self->_request( 'post', @args );
}

=head2 put( @args )

Invokes PUT request on LWP::UserAgent-like object; params are passed through.

=cut

sub put {
    my ( $self, @args ) = @_;
    return $self->_request( 'put', @args );
}

=head2 delete( @args )

Invokes DELETE request on LWP::UserAgent-like object; params are passed through.

=cut

sub delete {
    my ( $self, @args ) = @_;
    return $self->_request( 'delete', @args );
}

=head2 request( @args )

Invokes request() on LWP::UserAgent-like object; params are passed through.

=cut

sub request {
    my ( $self, @args ) = @_;
    return $self->_request( 'request', @args );
}

=head1 BUILDS

=cut

=head2 all_builds

Retrieves information on all builds from artifactory.

=cut

sub all_builds {
    my $self = shift;
    return $self->_get_build('');
}

=head2 build_runs( $build_name )

Retrieves information of a particular build from artifactory.

=cut

sub build_runs {
    my ( $self, $build ) = @_;
    return $self->_get_build( $build );
}

=head2 build_info( $build_name, $build_number )

Retrieves information of a particular build number.

=cut

sub build_info {
    my ( $self, $build, $number ) = @_;
    return $self->_get_build( "$build/$number" );
}

=head2 builds_diff( $build_name, $new_build_number, $old_build_number )

Retrieves diff of 2 builds

=cut

sub builds_diff {
    my ( $self, $build, $new, $old ) = @_;
    return $self->_get_build( "$build/$new?diff=$old" );
}

=head2 build_promotion( $build_name, $build_number, $payload )

Promotes a build by POSTing payload

=cut

sub build_promotion {
    my ( $self, $build, $number, $payload ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = "$artifactory:$port/artifactory/api/build/promote/$build/$number";
    return $self->post( $url, "Content-Type" => 'application/json', Content => to_json( $payload ) );
}

=head2 delete_build( name => $build_name, buildnumbers => [ buildnumbers ], artifacts => 0,1, deleteall => 0,1 )

Promotes a build by POSTing payload

=cut

sub delete_build {
    my ( $self, %args ) = @_;
    my $build = $args{ name };
    my $buildnumbers = $args{ buildnumbers };
    my $artifacts = $args{ artifacts };
    my $deleteall = $args{ deleteall };

    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = "$artifactory:$port/artifactory/api/build/$build";
    my @params;

    if ( ref( $buildnumbers ) eq 'ARRAY' ) {
        my $str = "buildNumbers=";
        $str .= join( ",", @{ $buildnumbers } );
        push @params, $str;
    }

    if ( defined $artifacts ) {
        push @params, "artifacts=$artifacts";
    }

    if ( defined $deleteall ) {
        push @params, "deleteAll=$deleteall";
    }

    if ( @params ) {
        $url .= "?";
        $url .= join( "&", @params );
    }
    return $self->delete( $url );
}

=head2 build_rename( $build_name, $new_build_name )

Renames a build

=cut

sub build_rename {
    my ( $self, $build, $new_build ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = "$artifactory:$port/artifactory/api/build/rename/$build?to=$new_build";
    return $self->post( $url );
}

=head1 ARTIFACTS & STORAGE

=cut

=head2 folder_info( $path )

Returns folder info

=cut

sub folder_info {
    my ( $self, $path ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/api/storage/$repository$path";
    return $self->get( $url );
}

=head2 file_info( $path )

Returns file info

=cut

sub file_info {
    my ( $self, $path ) = @_;
    return $self->folder_info( $path ); # should be OK to do this
}

=head2 item_last_modified( $path )

Returns item_last_modified for a given path

=cut

sub item_last_modified {
    my ( $self, $path ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/api/storage/$repository$path?lastModified";
    return $self->get( $url );
}

=head2 file_statistics( $path )

Returns file_statistics for a given path

=cut

sub file_statistics {
    my ( $self, $path ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/api/storage/$repository$path?stats";
    return $self->get( $url );
}

=head2 item_properties( path => $path, properties => [ key_names ] )

Takes path and properties then get item properties.

=cut

sub item_properties {
    my ( $self, %args ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );

    my $path = $args{ path };
    my $properties = $args{ properties };
    my $url = "$artifactory:$port/api/storage/$repository$path?properties";

    if ( ref( $properties ) eq 'ARRAY' ) {
        my $str = join( ',', @{ $properties } );
        $url .= "=" . $str;
    }
    return $self->get( $url );
}

=head2 set_item_properties( path => $path, properties => { key => [ values ] }, recursive => 0,1 )

Takes path and properties then set item properties.  Supply recursive => 0 if you want to suppress propagation of
properties downstream.  Note that properties are a hashref with key-arrayref pairs, such as:

    $prop = { key1 => ['a'], key2 => ['a', 'b'] }

=cut

sub set_item_properties {
    my ( $self, %args ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );

    my $path = $args{ path };
    my $properties = $args{ properties };
    my $recursive = $args{ recursive };
    my $url = "$artifactory:$port/api/storage/$repository$path?properties=";
    my $request = $self->_attach_properties( url => $url, properties => $properties );
    $request .= "&recursive=$recursive" if ( defined $recursive );
    return $self->put( $request );
}

=head2 delete_item_properties( path => $path, properties => [ key_names ], recursive => 0,1 )

Takes path and properties then delete item properties.  Supply recursive => 0 if you want to suppress propagation of
properties downstream.

=cut

sub delete_item_properties {
    my ( $self, %args ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );

    my $path = $args{ path };
    my $properties = $args{ properties };
    my $recursive = $args{ recursive };
    my $url = "$artifactory:$port/api/storage/$repository$path?properties=" . join( ",", @{ $properties } );
    $url .= "&recursive=$recursive" if ( defined $recursive );
    return $self->delete( $url );
}

=head2 retrieve_artifact( $path )

Takes path and retrieves artifact on the path.

=cut

sub retrieve_artifact {
    my ( $self, $path ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/$repository$path";
    return $self->get( $url );
}

=head2 retrieve_latest_artifact( path => $path, snapshot => $snapshot, release => $release, integration => $integration,
    version => $version )

Takes path, version, snapshot / release / integration and makes a GET request

=cut

sub retrieve_latest_artifact {
    my ( $self, %args ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $path = $args{ path };
    my $snapshot = $args{ snapshot };
    my $release = $args{ release };
    my $integration = $args{ integration };
    my $version = $args{ version };

    my $base_url = "$artifactory:$port/artifactory/$repository$path";
    my $basename = basename( $path );
    my $url;

    if( $snapshot && $version ) {
        $url = "$base_url/$version-$snapshot/$basename-$version-$snapshot.jar";
    }

    if( $release ) {
        $url = "$base_url/$release/$basename-$release.jar";
    }

    if( $integration && $version ) {
        $url = "$base_url/$version-$integration/$basename-$version-$integration.jar";
    }
    return $self->get( $url );
}

=head2 retrieve_build_artifacts_archive( $payload )

Takes payload (hashref) then retrieve build artifacts archive.

=cut

sub retrieve_build_artifacts_archive {
    my ( $self, $payload ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = "$artifactory:$port/artifactory/api/archive/buildArtifacts";
    return $self->post( $url, "Content-Type" => 'application/json', Content => to_json( $payload ) );
}

=head2 trace_artifact_retrieval( $path )

Takes path and traces artifact retrieval

=cut

sub trace_artifact_retrieval {
    my ( $self, $path ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/$repository$path?trace";
    return $self->get( $url );
}

=head2 archive_entry_download( $path, $archive_path )

Takes path and archive_path, retrieves an archived resource from the specified archive destination.

=cut

sub archive_entry_download {
    my ( $self, $path, $archive_path ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/$repository$path!$archive_path";
    return $self->get( $url );
}

=head2 create_directory( path => $path, properties => { key => [ values ] } )

Takes path, properties then create a directory.  Directory needs to end with a /, such as "/some_dir/".

=cut

sub create_directory {
    my ( $self, %args ) = @_;
    return $self->deploy_artifact( %args );
}

=head2 deploy_artifact( path => $path, properties => { key => [ values ] }, content => $content )

Takes path, properties and content then deploys artifact.  Note that properties are a hashref with key-arrayref pairs,
such as:

    $prop = { key1 => ['a'], key2 => ['a', 'b'] }

=cut

sub deploy_artifact {
    my ( $self, %args ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );

    my $path = $args{ path };
    my $properties = $args{ properties };
    my $content = $args{ content };
    my $header = $args{ header };
    my $url = "$artifactory:$port/artifactory/$repository$path;";

    my $request = $self->_attach_properties( url => $url, properties => $properties, matrix => 1 );
    return $self->put( $request, %{ $header }, content => $content );
}

=head2 deploy_artifact_by_checksum( path => $path, properties => { key => [ values ] }, content => $content, sha1 => $sha1 )

Takes path, properties, content and sha1 then deploys artifact.  Note that properties are a hashref with key-arrayref
pairs, such as:

    $prop = { key1 => ['a'], key2 => ['a', 'b'] }

=cut

sub deploy_artifact_by_checksum {
    my ( $self, %args ) = @_;

    my $sha1 = $args{ sha1 };
    my $header = {
        'X-Checksum-Deploy' => 'true',
        'X-Checksum-Sha1' => $sha1,
    };
    $args{ header } = $header;
    return $self->deploy_artifact( %args );
}

=head2 deploy_artifacts_from_archive( path => $path, file => $file )

Path is the path on Artifactory, file is path to local archive.  Will deploy $file to $path.

=cut

sub deploy_artifacts_from_archive {
    my ( $self, %args ) = @_;

    my $path = $args{ path };
    my $file = $args{ file };
    my %header = (
        'X-Explode-Archive' => 'true',
    );

    # need to use fully-qualified name here so that I can mock from unit tests
    my $bin = File::Slurp::read_file( $file, { binmode => ':raw' } );
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/$repository$path";
    return $self->put( $url, %header, content => $bin );
}

=head2 file_compliance_info( $path )

Retrieves file compliance info of a given path.

=cut

sub file_compliance_info {
    my ( $self, $path ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/api/compliance/$repository$path";
    return $self->get( $url );
}

=head2 delete_item( $path )

Delete $path on artifactory.

=cut

sub delete_item {
    my ( $self, $path ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/$repository$path";
    return $self->delete( $url );
}

=head2 copy_item( from => $from, to => $to, dry => 1, suppressLayouts => 0/1, failFast => 0/1 )

Copies an artifact from $from to $to.  Note that for this particular API call, the $from and $to must include repository
names as copy source and destination may be different repositories.  You can also supply dry, suppressLayouts and
failFast values as specified in the documentation.

=cut

sub copy_item {
    my ( $self, %args ) = @_;
    $args{ method } = 'copy';
    return $self->_handle_item( %args );
}

=head2 move_item( from => $from, to => $to, dry => 1, suppressLayouts => 0/1, failFast => 0/1 )

Moves an artifact from $from to $to.  Note that for this particular API call, the $from and $to must include repository
names as copy source and destination may be different repositories.  You can also supply dry, suppressLayouts and
failFast values as specified in the documentation.

=cut

sub move_item {
    my ( $self, %args ) = @_;
    $args{ method } = 'move';
    return $self->_handle_item( %args );
}

=head2 get_repository_replication_configuration

Get repository replication configuration

=cut

sub get_repository_replication_configuration {
    my $self = shift;
    return $self->_handle_repository_replication_configuration( 'get' );
}

=head2 set_repository_replication_configuration( $payload )

Set repository replication configuration

=cut

sub set_repository_replication_configuration {
    my ( $self, $payload ) = @_;
    return $self->_handle_repository_replication_configuration( 'put', $payload );
}

=head2 update_repository_replication_configuration( $payload )

Update repository replication configuration

=cut

sub update_repository_replication_configuration {
    my ( $self, $payload ) = @_;
    return $self->_handle_repository_replication_configuration( 'post', $payload );
}

=head2 delete_repository_replication_configuration

Delete repository replication configuration

=cut

sub delete_repository_replication_configuration {
    my $self = shift;
    return $self->_handle_repository_replication_configuration( 'delete' );
}

=head2 scheduled_replication_status

Gets scheduled replication status of a repository

=cut

sub scheduled_replication_status {
    my $self = shift;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/api/replication/$repository";
    return $self->get( $url );
}

=head2 pull_push_replication( payload => $payload, path => $path )

Schedules immediate content replication between two Artifactory instances

=cut

sub pull_push_replication {
    my ( $self, %args ) = @_;
    my $payload = $args{ payload };
    my $path = $args{ path };
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/api/replication/$repository$path";
    return $self->post( $url, "Content-Type" => 'application/json', Content => to_json( $payload ) );
}

=head2 file_list( $dir, %opts )

Get a flat (the default) or deep listing of the files and folders (not included by default) within a folder

=cut

sub file_list {
    my ( $self, $dir, %opts ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/api/storage/$repository$dir?list";
    
    for my $opt ( keys %opts ) {
        my $val = $opts{ $opt };
        $url .= "&${opt}=$val";
    }
    return $self->get( $url );
}

=head1 SEARCHES

=cut

=head2 artifact_search( name => $name, repos => [ @repos ] )

Artifact search by part of file name

=cut

sub artifact_search {
    my ( $self, %args ) = @_;
    return $self->_handle_search( 'artifact', %args );
}

=head2 archive_entry_search( name => $name, repos => [ @repos ] )

Search archive entries for classes or any other jar resources

=cut

sub archive_entry_search {
    my ( $self, %args ) = @_;
    return $self->_handle_search( 'archive', %args );
}

=head2 gavc_search( groupId => 'foo', classifier => 'bar' )

Search by Maven coordinates: groupId, artifactId, version & classifier

=cut

sub gavc_search {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'gavc', %args );
}

=head2 property_search( p => [ 'v1', 'v2' ], repos => [ 'repo1', repo2' ]  )

Search by properties

=cut

sub property_search {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'prop', %args );
}

=head2 checksum_search( md5sum => '12345', repos => [ 'repo1', repo2' ]  )

Artifact search by checksum (md5 or sha1)

=cut

sub checksum_search {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'checksum', %args );
}

=head2 bad_checksum_search( type => 'md5', repos => [ 'repo1', repo2' ]  )

Find all artifacts that have a bad or missing client checksum values (md5 or sha1)

=cut

sub bad_checksum_search {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'badChecksum', %args );
}

=head2 artifacts_not_downloaded_since( notUsedSince => 12345, createdBefore => 12345, repos => [ 'repo1', repo2' ] )

Retrieve all artifacts not downloaded since the specified Java epoch in msec.

=cut

sub artifacts_not_downloaded_since {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'usage', %args );
}

=head2 artifacts_created_in_date_range( from => 12345, to => 12345, repos => [ 'repo1', repo2' ] )

Get all artifacts created in date range

=cut

sub artifacts_created_in_date_range {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'creation', %args );
}

=head2 pattern_search( $pattern )

Get all artifacts matching the given Ant path pattern

=cut

sub pattern_search {
    my ( $self, $pattern ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/api/search/pattern?pattern=$repository:$pattern";
    return $self->get( $url );
}

=head2 builds_for_dependency( sha1 => 'abcde' )

Find all the builds an artifact is a dependency of (where the artifact is included in the build-info dependencies)

=cut

sub builds_for_dependency {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'dependency', %args );
}

=head2 license_search( unapproved => 1, unknown => 1, notfound => 0, neutral => 0, repos => [ 'foo', 'bar' ] )

Search for artifacts with specified statuses

=cut

sub license_search {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'license', %args );
}

=head2 artifact_version_search( g => 'foo', a => 'bar', v => '1.0', repos => [ 'foo', 'bar' ] )

Search for all available artifact versions by GroupId and ArtifactId in local, remote or virtual repositories

=cut

sub artifact_version_search {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'versions', %args );
}

=head2 artifact_latest_version_search_based_on_layout( g => 'foo', a => 'bar', v => '1.0', repos => [ 'foo', 'bar' ] )

Search for the latest artifact version by groupId and artifactId, based on the layout defined in the repository 

=cut

sub artifact_latest_version_search_based_on_layout {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'latestVersion', %args );
}

=head2 artifact_latest_version_search_based_on_properties( repo => '_any', path => '/a/b', listFiles => 1 )

Search for artifacts with the latest value in the "version" property

=cut

sub artifact_latest_version_search_based_on_properties {
    my ( $self, %args ) = @_;
    my $repo = delete $args{ repo };
    my $path = delete $args{ path };
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = "$artifactory:$port/artifactory/api/versions/$repo$path?";
    $url .= $self->_stringify_hash( '&', %args );
    return $self->get( $url );
}

=head2 build_artifacts_search( buildNumber => 15, buildName => 'foobar' )

Find all the artifacts related to a specific build

=cut

sub build_artifacts_search {
    my ( $self, %args ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = "$artifactory:$port/artifactory/api/search/buildArtifacts";
    return $self->post( $url, 'Content-Type' => 'application/json', content => to_json( \%args ) );
}

=head1 SECURITY

=cut

=head2 get_users

Get the users list

=cut

sub get_users {
    my $self = shift;
    return $self->_handle_security( undef, 'get', 'users' );
}

=head2 get_user_details( $user )

Get the details of an Artifactory user

=cut

sub get_user_details {
    my ( $self, $user ) = @_;
    return $self->_handle_security( $user, 'get', 'users' );
}

=head2 create_or_replace_user( $user, %args )

Creates a new user in Artifactory or replaces an existing user

=cut

sub create_or_replace_user {
    my ( $self, $user, %args ) = @_;
    return $self->_handle_security( $user, 'put', 'users', %args );
}

=head2 update_user( $user, %args )

Updates an exiting user in Artifactory with the provided user details

=cut

sub update_user {
    my ( $self, $user, %args ) = @_;
    return $self->_handle_security( $user, 'post', 'users', %args );
}

=head2 delete_user( $user )

Removes an Artifactory user

=cut

sub delete_user {
    my ( $self, $user ) = @_;
    return $self->_handle_security( $user, 'delete', 'users' );
}

=head2 get_groups

Get the groups list

=cut

sub get_groups {
    my $self = shift;
    return $self->_handle_security( undef, 'get', 'groups' );
}

=head2 get_group_details( $group )

Get the details of an Artifactory Group

=cut

sub get_group_details {
    my ( $self, $group ) = @_;
    return $self->_handle_security( $group, 'get', 'groups' );
}

=head2 create_or_replace_group( $group, %args )

Creates a new group in Artifactory or replaces an existing group

=cut

sub create_or_replace_group {
    my ( $self, $group, %args ) = @_;
    return $self->_handle_security( $group, 'put', 'groups', %args );
}

=head2 update_group( $group, %args )

Updates an exiting group in Artifactory with the provided group details

=cut

sub update_group {
    my ( $self, $group, %args ) = @_;
    return $self->_handle_security( $group, 'post', 'groups', %args );
}

=head2 delete_group( $group )

Removes an Artifactory group

=cut

sub delete_group {
    my ( $self, $group ) = @_;
    return $self->_handle_security( $group, 'delete', 'groups' );
}

=head2 get_permission_targets

Get the permission targets list

=cut

sub get_permission_targets {
    my $self = shift;
    return $self->_handle_security( undef, 'get', 'permissions' );
}

=head2 get_permission_target_details( $name )

Get the details of an Artifactory Permission Target

=cut

sub get_permission_target_details {
    my ( $self, $name ) = @_;
    return $self->_handle_security( $name, 'get', 'permissions' );
}

=head2 create_or_replace_permission_target( $name, %args )

Creates a new permission target in Artifactory or replaces an existing permission target

=cut

sub create_or_replace_permission_target {
    my ( $self, $name, %args ) = @_;
    return $self->_handle_security( $name, 'put', 'permissions', %args );
}

=head2 delete_permission_target( $name )

Deletes an Artifactory permission target

=cut

sub delete_permission_target {
    my ( $self, $name ) = @_;
    return $self->_handle_security( $name, 'delete', 'permissions' );
}

=head2 effective_item_permissions( $path )

Returns a list of effective permissions for the specified item (file or folder)

=cut

sub effective_item_permissions {
    my ( $self, $path ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/api/storage/$repository$path";
    return $self->get( $url );
}

=head2 security_configuration

Retrieve the security configuration (security.xml)

=cut

sub security_configuration {
    my ( $self, $path ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = "$artifactory:$port/artifactory/api/system/security";
    return $self->get( $url );
}

=head1 REPOSITORIES

=cut

=head2 get_repositories

Returns a list of minimal repository details for all repositories of the specified type

=cut

sub get_repositories {
    my ( $self, $path ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = "$artifactory:$port/artifactory/api/repositories";
    return $self->get( $url );
}

=head2 repository_configuration( $name, %args )

Retrieves the current configuration of a repository

=cut

sub repository_configuration {
    my ( $self, $repo, %args ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = ( %args ) ? "$artifactory:$port/artifactory/api/repositories/$repo?" : "$artifactory:$port/artifactory/api/repositories/$repo";
    $url .= $self->_stringify_hash( '&', %args ) if ( %args );
    return $self->get( $url );
}

=head2 create_or_replace_repository_configuration( $name, $payload, %args )

Creates a new repository in Artifactory with the provided configuration or replaces the configuration of an existing
repository

=cut

sub create_or_replace_repository_configuration {
    my ( $self, $repo, $payload, %args ) = @_;
    return $self->_handle_repositories( $repo, $payload, 'put', %args );
}

=head2 update_repository_configuration( $name, %payload )

Updates an exiting repository configuration in Artifactory with the provided configuration elements

=cut

sub update_repository_configuration {
    my ( $self, $repo, $payload ) = @_;
    return $self->_handle_repositories( $repo, $payload, 'post' );
}

=head2 delete_repository( $name )

Removes a repository configuration together with the whole repository content

=cut

sub delete_repository {
    my ( $self, $repo ) = @_;
    return $self->_handle_repositories( $repo, undef, 'delete' );
}

=head2 calculate_yum_repository_metadata( async => 0/1 )

Calculates/recalculates the YUM metdata for this repository, based on the RPM package currently hosted in the repository

=cut

sub calculate_yum_repository_metadata {
    my ( $self, %args ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = ( %args ) ? "$artifactory:$port/artifactory/api/yum/$repository?" : "$artifactory:$port/artifactory/api/yum/$repository";
    $url .= $self->_stringify_hash( '&', %args ) if ( %args );
    return $self->post( $url );
}

=head2 calculate_nuget_repository_metadata

Recalculates all the NuGet packages for this repository (local/cache/virtual), and re-annotate the NuGet properties for
each NuGet package according to it's internal nuspec file

=cut

sub calculate_nuget_repository_metadata {
    my ( $self ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/api/nuget/$repository/reindex";
    return $self->post( $url );
}

=head2 calculate_maven_index( repos => [ 'repo1', 'repo2' ], force => 0/1 )

Calculates/caches a Maven index for the specified repositories

=cut

sub calculate_maven_index {
    my ( $self, %args ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = "$artifactory:$port/artifactory/api/maven?";
    $url .= $self->_stringify_hash( '&', %args );
    return $self->post( $url );
}

=head2 calculate_maven_metadata( $path )

Calculates Maven metadata on the specified path (local repositories only)

=cut

sub calculate_maven_metadata {
    my ( $self, $path ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/api/maven/calculateMetadata/$repository$path";
    return $self->post( $url );
}

=head1 SYSTEM & CONFIGURATION

=cut

=head2 system_info

Get general system information

=cut

sub system_info {
    my $self = shift;
    return $self->_handle_system();
}

=head2 system_health_ping

Get a simple status response about the state of Artifactory

=cut

sub system_health_ping {
    my $self = shift;
    return $self->_handle_system( 'ping' );
}

=head2 general_configuration

Get the general configuration (artifactory.config.xml)

=cut

sub general_configuration {
    my $self = shift;
    return $self->_handle_system( 'configuration' );
}

=head2 save_general_configuration( $file )

Save the general configuration (artifactory.config.xml)

=cut

sub save_general_configuration {
    my ( $self, $xml ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $file = File::Slurp::read_file( $xml );
    my $url = "$artifactory:$port/artifactory/api/system/configuration";
    return $self->post( $url, 'Content-Type' => 'application/xml', content => $file );
}

=head2 version_and_addons_information( $file )

Retrieve information about the current Artifactory version, revision, and currently installed Add-ons

=cut

sub version_and_addons_information {
    my $self = shift;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = "$artifactory:$port/artifactory/api/system/version";
    return $self->get( $url );
}

=head1 PLUGINS

=cut

=head2 execute_plugin_code( $execution_name, $params, $async )

Executes a named execution closure found in the executions section of a user plugin

=cut

sub execute_plugin_code {
    my ( $self, $execution_name, $params, $async ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = ( $params ) ? "$artifactory:$port/artifactory/api/plugins/execute/$execution_name?params=" :
        "$artifactory:$port/artifactory/api/plugins/execute/$execution_name";
        
    $url = $self->_attach_properties( url => $url, properties => $params );
    $url .= "&" . $self->_stringify_hash( '&', %{ $async } ) if ( $async );
    return $self->post( $url );
}

=head2 retrieve_all_available_plugin_info

Retrieves all available user plugin information (subject to the permissions of the provided credentials)

=cut

sub retrieve_all_available_plugin_info {
    my $self = shift;
    return $self->_handle_plugins();
}

=head2 retrieve_plugin_info_of_a_certain_type( $type )

Retrieves all available user plugin information (subject to the permissions of the provided credentials) of the
specified type

=cut

sub retrieve_plugin_info_of_a_certain_type {
    my ( $self, $type ) = @_;
    return $self->_handle_plugins( $type );
}

sub _build_ua {
    my $self = shift;
    $self->{ ua } = LWP::UserAgent->new() unless( $self->{ ua } );
}

sub _request {
    my ( $self, $method, @args ) = @_;
    return $self->{ ua }->$method( @args );
}

sub _unpack_attributes {
    my ( $self, @args ) = @_;
    my @result;

    for my $attr ( @args ) {
        push @result, $self->{ $attr };
    }
    return @result;
}

sub _get_build {
    my ( $self, $path ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = "$artifactory:$port/artifactory/api/build/$path";
    return $self->get( $url );
}

sub _attach_properties {
    my ( $self, %args ) = @_;
    my $url = $args{ url };
    my $properties = $args{ properties };
    my $matrix = $args{ matrix };

    for my $key ( keys %{ $properties } ) {
        $url .= $self->_handle_prop_multivalue( $key, $properties->{ $key }, $matrix );
    }
    return $url;
}

sub _handle_prop_multivalue {
    my ( $self, $key, $values, $matrix ) = @_;

    # need to handle matrix vs non-matrix situations.
    # if matrix, string looks like key=val;key=val2;key=val3;
    # if non-matrix, string looks like key=val1,val2,val3|
    my $str = ( $matrix ) ? '' : "$key=";

    for my $val ( @{ $values } ) {
        $val = '' if ( !defined $val );
        $val = uri_escape( $val );
        $str .= ( $matrix ) ? "$key=$val;" : "$val,";
    }
    $str .= ( $matrix ) ? '' : "|";
    return $str;
}

sub _handle_item {
    my ( $self, %args ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my ( $from, $to, $dry, $suppress_layouts, $fail_fast, $method ) = ( $args{ from }, $args{ to }, $args{ dry },
        $args{ suppress_layouts }, $args{ fail_fast }, $args{ method } );

    my $url = "$artifactory:$port/artifactory/api/$method$from?to=$to";
    $url .= "&dry=$dry" if ( defined $dry );
    $url .= "&suppressLayouts=$suppress_layouts" if ( defined $suppress_layouts );
    $url .= "&failFast=$fail_fast" if ( defined $fail_fast );
    return $self->post( $url );
}

sub _handle_repository_replication_configuration {
    my ( $self, $method, $payload ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/api/replications/$repository";
    ( $payload ) ? $self->$method( $url, 'Content-Type' => 'application/json', content => $payload ) : $self->$method( $url ); 
}

sub _handle_search {
    my ( $self, $api, %args ) = @_;
    my $name = $args{ name };
    my $repos = $args{ repos };
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = "$artifactory:$port/artifactory/api/search/$api?name=$name";
    
    if ( ref( $repos ) eq 'ARRAY' ) {
        $url .= "&repos=";
        for my $item( @{ $repos } ) {
            $url .= "$item,";
        }
    }
    return $self->get( $url );
}

sub _handle_search_props {
    my ( $self, $method, %args ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = "$artifactory:$port/artifactory/api/search/$method?";

    $url .= $self->_stringify_hash( '&', %args );
    return $self->get( $url );
}

sub _stringify_hash {
    my ( $self, $delimiter, %args ) = @_;

    my @strs;
    for my $key ( keys %args ) {
        my $val = $args{ $key };
        
        if ( ref( $val ) eq 'ARRAY' ) {
            $val = join( ",", @{ $val } );
        }
        push @strs, "$key=$val";
    }
    return join( $delimiter, @strs );
}

sub _handle_security {
    my ( $self, $label, $method, $element, %args ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = ( $label ) ? "$artifactory:$port/artifactory/api/security/$element/$label" : "$artifactory:$port/artifactory/api/security/$element";

    if ( %args ) {
        return $self->$method( $url, 'Content-Type' => 'application/json', content => to_json( \%args ) );
    }
    return $self->$method( $url );
}

sub _handle_repositories {
    my ( $self, $repo, $payload, $method, %args ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = ( %args ) ? "$artifactory:$port/artifactory/api/repositories/$repo?" : "$artifactory:$port/artifactory/api/repositories/$repo";
    $url .= $self->_stringify_hash( '&', %args ) if ( %args );
    
    if ( $payload ) {
        return $self->$method( $url, 'Content-Type' => 'application/json', content => to_json( $payload ) );
    }
    return $self->$method( $url );
}

sub _handle_system {
    my ( $self, $arg ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = ( $arg ) ? "$artifactory:$port/artifactory/api/system/$arg" : "$artifactory:$port/artifactory/api/system";
    return $self->get( $url );
}

sub _handle_plugins {
    my ( $self, $type ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = ( $type ) ? "$artifactory:$port/artifactory/api/plugins/$type" : "$artifactory:$port/artifactory/api/plugins";
    return $self->get( $url );
}

__PACKAGE__->meta->make_immutable;

=head1 AUTHOR

Satoshi Yagi, C<< <satoshi at yahoo-inc.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-artifactory-client at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Artifactory-Client>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Artifactory::Client

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Artifactory-Client>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Artifactory-Client>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Artifactory-Client>

=item * Search CPAN

L<http://search.cpan.org/dist/Artifactory-Client/>

=back

=head1 ACKNOWLEDGEMENTS

=head1 LICENSE AND COPYRIGHT

Copyright 2014, Yahoo! Inc.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

1; # End of Artifactory::Client

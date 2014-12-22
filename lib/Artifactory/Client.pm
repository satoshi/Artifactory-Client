package Artifactory::Client;

use strict;
use warnings FATAL => 'all';

use Moose;

use URI;
use JSON::MaybeXS;
use LWP::UserAgent;
use Path::Tiny qw();
use MooseX::StrictConstructor;
use URI::Escape qw(uri_escape);
use File::Basename qw(basename);
use HTTP::Request::StreamingUpload;

use namespace::autoclean;

=head1 NAME

Artifactory::Client - Perl client for Artifactory REST API

=head1 VERSION

Version 0.8.0

=cut

our $VERSION = '0.8.0';

=head1 SYNOPSIS

This is a Perl client for Artifactory REST API:
https://www.jfrog.com/confluence/display/RTF/Artifactory+REST+API Every public
method provided in this module returns a HTTP::Response object.

    use Artifactory::Client;

    my $args = {
        artifactory => 'http://artifactory.server.com',
        port => 8080,
        repository => 'myrepository',
        context_root => '/', # Context root for artifactory. Defaults to 'artifactory'.
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
    my $file = '/local/file.xml';

    # Name of methods are taken straight from Artifactory REST API documentation.  'Deploy Artifact' would map to
    # deploy_artifact method, like below.  The caller gets HTTP::Response object back.
    my $resp = $client->deploy_artifact( path => $path, properties => $properties, file => $file );

    # Custom requests can also be made via usual get / post / put / delete requests.
    my $resp = $client->get( 'http://artifactory.server.com/path/to/resource' );

    # drop in a different UserAgent:
    my $ua = WWW::Mechanize->new();
    $client->ua( $ua ); # now uses WWW::Mechanize to make requests

Note on testing: This module is developed using Test-Driven Development.  I
have functional tests making real API calls, however they contain proprietary
information and I am not allowed to open source them.  The unit tests included
are dumbed-down version of my functional tests.  They should serve as a
detailed guide on how to make API calls.

=cut

has 'artifactory' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    writer   => '_set_artifactory',
);

has 'port' => (
    is      => 'ro',
    isa     => 'Int',
    default => 80,
);

has 'context_root' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'artifactory',
);

has 'ua' => (
    is      => 'rw',
    isa     => 'LWP::UserAgent',
    builder => '_build_ua',
    lazy    => 1,
);

has 'repository' => (
    is      => 'ro',
    isa     => 'Str',
    default => '',
    writer  => '_set_repository',
);

has '_json' => (
    is      => 'ro',
    builder => '_build_json',
    lazy    => 1,
);

has '_api_url' => (
    is       => 'ro',
    isa      => 'Str',
    init_arg => undef,
    writer   => '_set_api_url',
);

has '_art_url' => (
    is       => 'ro',
    isa      => 'Str',
    init_arg => undef,
    writer   => '_set_art_url',
);

sub BUILD {
    my ($self) = @_;

    # Save URIs
    my $uri = URI->new( $self->artifactory() );
    $uri->port( $self->port );
    my $context_root = $self->context_root();
    $context_root = '' if ( $context_root eq '/' );

    $uri->path_segments( $context_root, );
    my $_art_url = $uri->canonical()->as_string();
    $_art_url =~ s{\/$}{}xi;
    $self->_set_art_url($_art_url);

    $uri->path_segments( $context_root, 'api' );
    $self->_set_api_url( $uri->canonical()->as_string() );

    # Save Repository
    my $repo = $self->repository;
    $repo =~ s{^\/}{}xi;
    $repo =~ s{\/$}{}xi;
    $self->_set_repository($repo);

    return 1;
} ## end sub BUILD

=head1 GENERIC METHODS

=cut

=head2 get( @args )

Invokes GET request on LWP::UserAgent-like object; params are passed through.

=cut

sub get {
    my ( $self, @args ) = @_;
    return $self->_request( 'get', @args );
} ## end sub get

=head2 post( @args )

nvokes POST request on LWP::UserAgent-like object; params are passed through.

=cut

sub post {
    my ( $self, @args ) = @_;
    return $self->_request( 'post', @args );
} ## end sub post

=head2 put( @args )

Invokes PUT request on LWP::UserAgent-like object; params are passed through.

=cut

sub put {
    my ( $self, @args ) = @_;
    return $self->_request( 'put', @args );
} ## end sub put

=head2 delete( @args )

Invokes DELETE request on LWP::UserAgent-like object; params are passed
through.

=cut

sub delete {
    my ( $self, @args ) = @_;
    return $self->_request( 'delete', @args );
} ## end sub delete

=head2 request( @args )

Invokes request() on LWP::UserAgent-like object; params are passed through.

=cut

sub request {
    my ( $self, @args ) = @_;
    return $self->_request( 'request', @args );
} ## end sub request

=head1 BUILDS

=cut

=head2 all_builds

Retrieves information on all builds from artifactory.

=cut

sub all_builds {
    my $self = shift;
    return $self->_get_build('');
} ## end sub all_builds

=head2 build_runs( $build_name )

Retrieves information of a particular build from artifactory.

=cut

sub build_runs {
    my ( $self, $build ) = @_;
    return $self->_get_build($build);
} ## end sub build_runs

=head2 build_info( $build_name, $build_number )

Retrieves information of a particular build number.

=cut

sub build_info {
    my ( $self, $build, $number ) = @_;
    return $self->_get_build("$build/$number");
} ## end sub build_info

=head2 builds_diff( $build_name, $new_build_number, $old_build_number )

Retrieves diff of 2 builds

=cut

sub builds_diff {
    my ( $self, $build, $new, $old ) = @_;
    return $self->_get_build("$build/$new?diff=$old");
} ## end sub builds_diff

=head2 build_promotion( $build_name, $build_number, $payload )

Promotes a build by POSTing payload

=cut

sub build_promotion {
    my ( $self, $build, $number, $payload ) = @_;

    my $url = $self->_api_url() . "/build/promote/$build/$number";
    return $self->post(
        $url,
        "Content-Type" => 'application/json',
        Content        => $self->_json->encode($payload)
    );
} ## end sub build_promotion

=head2 delete_build( name => $build_name, buildnumbers => [ buildnumbers ], artifacts => 0,1, deleteall => 0,1 )

Promotes a build by POSTing payload

=cut

sub delete_build {
    my ( $self, %args ) = @_;
    my $build        = $args{name};
    my $buildnumbers = $args{buildnumbers};
    my $artifacts    = $args{artifacts};
    my $deleteall    = $args{deleteall};

    my $url = $self->_api_url() . "/build/$build";
    my @params;

    if ( ref($buildnumbers) eq 'ARRAY' ) {
        my $str = "buildNumbers=";
        $str .= join( ",", @{$buildnumbers} );
        push @params, $str;
    } ## end if ( ref($buildnumbers...))

    if ( defined $artifacts ) {
        push @params, "artifacts=$artifacts";
    }

    if ( defined $deleteall ) {
        push @params, "deleteAll=$deleteall";
    }

    if (@params) {
        $url .= "?";
        $url .= join( "&", @params );
    } ## end if (@params)
    return $self->delete($url);
} ## end sub delete_build

=head2 build_rename( $build_name, $new_build_name )

Renames a build

=cut

sub build_rename {
    my ( $self, $build, $new_build ) = @_;

    my $url = $self->_api_url() . "/build/rename/$build?to=$new_build";
    return $self->post($url);
} ## end sub build_rename

=head1 ARTIFACTS & STORAGE

=cut

=head2 folder_info( $path )

Returns folder info

=cut

sub folder_info {
    my ( $self, $path ) = @_;

    $path = $self->_merge_repo_and_path($path);
    my $url = $self->_api_url() . "/storage/$path";

    return $self->get($url);
} ## end sub folder_info

=head2 file_info( $path )

Returns file info

=cut

sub file_info {
    my ( $self, $path ) = @_;
    return $self->folder_info($path);    # should be OK to do this
} ## end sub file_info

=head2 item_last_modified( $path )

Returns item_last_modified for a given path

=cut

sub item_last_modified {
    my ( $self, $path ) = @_;
    $path = $self->_merge_repo_and_path($path);
    my $url = $self->_api_url() . "/storage/$path?lastModified";
    return $self->get($url);
} ## end sub item_last_modified

=head2 file_statistics( $path )

Returns file_statistics for a given path

=cut

sub file_statistics {
    my ( $self, $path ) = @_;
    my $url = $self->_api_url() . "/storage/$path?stats";
    return $self->get($url);
} ## end sub file_statistics

=head2 item_properties( path => $path, properties => [ key_names ] )

Takes path and properties then get item properties.

=cut

sub item_properties {
    my ( $self, %args ) = @_;

    my $path       = $args{path};
    my $properties = $args{properties};

    $path = $self->_merge_repo_and_path($path);
    my $url = $self->_api_url() . "/storage/$path?properties";

    if ( ref($properties) eq 'ARRAY' ) {
        my $str = join( ',', @{$properties} );
        $url .= "=" . $str;
    } ## end if ( ref($properties) ...)
    return $self->get($url);
} ## end sub item_properties

=head2 set_item_properties( path => $path, properties => { key => [ values ] }, recursive => 0,1 )

Takes path and properties then set item properties.  Supply recursive => 0 if
you want to suppress propagation of properties downstream.  Note that
properties are a hashref with key-arrayref pairs, such as:

    $prop = { key1 => ['a'], key2 => ['a', 'b'] }

=cut

sub set_item_properties {
    my ( $self, %args ) = @_;

    my $path       = $args{path};
    my $properties = $args{properties};
    my $recursive  = $args{recursive};

    $path = $self->_merge_repo_and_path($path);
    my $url = $self->_api_url() . "/storage/$path?properties=";

    my $request = $url . $self->_attach_properties( properties => $properties );
    $request .= "&recursive=$recursive" if ( defined $recursive );
    return $self->put($request);
} ## end sub set_item_properties

=head2 delete_item_properties( path => $path, properties => [ key_names ], recursive => 0,1 )

Takes path and properties then delete item properties.  Supply recursive => 0
if you want to suppress propagation of properties downstream.

=cut

sub delete_item_properties {
    my ( $self, %args ) = @_;

    my $path       = $args{path};
    my $properties = $args{properties};
    my $recursive  = $args{recursive};

    $path = $self->_merge_repo_and_path($path);
    my $url = $self->_api_url() . "/storage/$path?properties=" . join( ",", @{$properties} );
    $url .= "&recursive=$recursive" if ( defined $recursive );
    return $self->delete($url);
} ## end sub delete_item_properties

=head2 retrieve_artifact( $path, [ $filename ] )

Takes path and retrieves artifact on the path.  If $filename is given, artifact
content goes into the $filename rather than the HTTP::Response object.

=cut

sub retrieve_artifact {
    my ( $self, $path, $filename ) = @_;
    $path = $self->_merge_repo_and_path($path);
    my $url = $self->_art_url() . "/$path";
    return ($filename)
      ? $self->get( $url, ":content_file" => $filename )
      : $self->get($url);
} ## end sub retrieve_artifact

=head2 retrieve_latest_artifact( path => $path, snapshot => $snapshot, release => $release, integration => $integration,
    version => $version )

Takes path, version, snapshot / release / integration and makes a GET request

=cut

sub retrieve_latest_artifact {
    my ( $self, %args ) = @_;

    my $path        = $args{path};
    my $snapshot    = $args{snapshot};
    my $release     = $args{release};
    my $integration = $args{integration};
    my $version     = $args{version};
    $path = $self->_merge_repo_and_path($path);

    my $base_url = $self->_art_url() . "/$path";
    my $basename = basename($path);
    my $url;

    if ( $snapshot && $version ) {
        $url = "$base_url/$version-$snapshot/$basename-$version-$snapshot.jar";
    } ## end if ( $snapshot && $version)

    if ($release) {
        $url = "$base_url/$release/$basename-$release.jar";
    }

    if ( $integration && $version ) {
        $url = "$base_url/$version-$integration/$basename-$version-$integration.jar";
    } ## end if ( $integration && $version)
    return $self->get($url);
} ## end sub retrieve_latest_artifact

=head2 retrieve_build_artifacts_archive( $payload )

Takes payload (hashref) then retrieve build artifacts archive.

=cut

sub retrieve_build_artifacts_archive {
    my ( $self, $payload ) = @_;

    my $url = $self->_api_url() . "/archive/buildArtifacts";
    return $self->post(
        $url,
        "Content-Type" => 'application/json',
        Content        => $self->_json->encode($payload)
    );
} ## end sub retrieve_build_artifacts_archive

=head2 trace_artifact_retrieval( $path )

Takes path and traces artifact retrieval

=cut

sub trace_artifact_retrieval {
    my ( $self, $path ) = @_;
    $path = $self->_merge_repo_and_path($path);
    my $url = $self->_art_url() . "/$path?trace";
    return $self->get($url);
} ## end sub trace_artifact_retrieval

=head2 archive_entry_download( $path, $archive_path )

Takes path and archive_path, retrieves an archived resource from the specified
archive destination.

=cut

sub archive_entry_download {
    my ( $self, $path, $archive_path ) = @_;
    $path = $self->_merge_repo_and_path($path);
    my $url = $self->_art_url() . "/$path!$archive_path";
    return $self->get($url);
} ## end sub archive_entry_download

=head2 create_directory( path => $path, properties => { key => [ values ] } )

Takes path, properties then create a directory.  Directory needs to end with a
/, such as "/some_dir/".

=cut

sub create_directory {
    my ( $self, %args ) = @_;
    return $self->deploy_artifact(%args);
} ## end sub create_directory

=head2 deploy_artifact( path => $path, properties => { key => [ values ] }, file => $file )

Takes path on Artifactory, properties and filename then deploys the file.  Note
that properties are a hashref with key-arrayref pairs, such as:

    $prop = { key1 => ['a'], key2 => ['a', 'b'] }

=cut

sub deploy_artifact {
    my ( $self, %args ) = @_;

    my $path       = $args{path};
    my $properties = $args{properties};
    my $file       = $args{file};
    my $header     = $args{header};

    $path = $self->_merge_repo_and_path($path);
    my @joiners = ( $self->_art_url() . "/$path" );
    my $props   = $self->_attach_properties(
        properties => $properties,
        matrix     => 1
    );
    push @joiners, $props if ($props);    # if properties aren't passed in, the function returns empty string
    my $url = join( ";", @joiners );

    my $req = HTTP::Request::StreamingUpload->new(
        PUT     => $url,
        path    => $file,
        headers => HTTP::Headers->new( %{$header} ),
    );
    return $self->request($req);
} ## end sub deploy_artifact

=head2 deploy_artifact_by_checksum( path => $path, properties => { key => [ values ] }, file => $file, sha1 => $sha1 )

Takes path, properties, filename and sha1 then deploys the file.  Note that
properties are a hashref with key-arrayref pairs, such as:

    $prop = { key1 => ['a'], key2 => ['a', 'b'] }

=cut

sub deploy_artifact_by_checksum {
    my ( $self, %args ) = @_;

    my $sha1   = $args{sha1};
    my $header = {
        'X-Checksum-Deploy' => 'true',
        'X-Checksum-Sha1'   => $sha1,
    };
    $args{header} = $header;
    return $self->deploy_artifact(%args);
} ## end sub deploy_artifact_by_checksum

=head2 deploy_artifacts_from_archive( path => $path, file => $file )

Path is the path on Artifactory, file is path to local archive.  Will deploy
$file to $path.

=cut

sub deploy_artifacts_from_archive {
    my ( $self, %args ) = @_;

    my $header = { 'X-Explode-Archive' => 'true', };
    $args{header} = $header;
    return $self->deploy_artifact(%args);
} ## end sub deploy_artifacts_from_archive

=head2 file_compliance_info( $path )

Retrieves file compliance info of a given path.

=cut

sub file_compliance_info {
    my ( $self, $path ) = @_;
    $path = $self->_merge_repo_and_path($path);
    my $url = $self->_api_url() . "/compliance/$path";
    return $self->get($url);
} ## end sub file_compliance_info

=head2 delete_item( $path )

Delete $path on artifactory.

=cut

sub delete_item {
    my ( $self, $path ) = @_;
    $path = $self->_merge_repo_and_path($path);
    my $url = $self->_art_url() . "/$path";
    return $self->delete($url);
} ## end sub delete_item

=head2 copy_item( from => $from, to => $to, dry => 1, suppressLayouts => 0/1, failFast => 0/1 )

Copies an artifact from $from to $to.  Note that for this particular API call,
the $from and $to must include repository names as copy source and destination
may be different repositories.  You can also supply dry, suppressLayouts and
failFast values as specified in the documentation.

=cut

sub copy_item {
    my ( $self, %args ) = @_;
    $args{method} = 'copy';
    return $self->_handle_item(%args);
} ## end sub copy_item

=head2 move_item( from => $from, to => $to, dry => 1, suppressLayouts => 0/1, failFast => 0/1 )

Moves an artifact from $from to $to.  Note that for this particular API call,
the $from and $to must include repository names as copy source and destination
may be different repositories.  You can also supply dry, suppressLayouts and
failFast values as specified in the documentation.

=cut

sub move_item {
    my ( $self, %args ) = @_;
    $args{method} = 'move';
    return $self->_handle_item(%args);
} ## end sub move_item

=head2 get_repository_replication_configuration

Get repository replication configuration

=cut

sub get_repository_replication_configuration {
    my $self = shift;
    return $self->_handle_repository_replication_configuration('get');
} ## end sub get_repository_replication_configuration

=head2 set_repository_replication_configuration( $payload )

Set repository replication configuration

=cut

sub set_repository_replication_configuration {
    my ( $self, $payload ) = @_;
    return $self->_handle_repository_replication_configuration( 'put', $payload );
} ## end sub set_repository_replication_configuration

=head2 update_repository_replication_configuration( $payload )

Update repository replication configuration

=cut

sub update_repository_replication_configuration {
    my ( $self, $payload ) = @_;
    return $self->_handle_repository_replication_configuration( 'post', $payload );
} ## end sub update_repository_replication_configuration

=head2 delete_repository_replication_configuration

Delete repository replication configuration

=cut

sub delete_repository_replication_configuration {
    my $self = shift;
    return $self->_handle_repository_replication_configuration('delete');
} ## end sub delete_repository_replication_configuration

=head2 scheduled_replication_status

Gets scheduled replication status of a repository

=cut

sub scheduled_replication_status {
    my $self       = shift;
    my $repository = $self->repository();
    my $url        = $self->_api_url() . "/replication/$repository";
    return $self->get($url);
} ## end sub scheduled_replication_status

=head2 pull_push_replication( payload => $payload, path => $path )

Schedules immediate content replication between two Artifactory instances

=cut

sub pull_push_replication {
    my ( $self, %args ) = @_;
    my $payload = $args{payload};
    my $path    = $args{path};
    $path = $self->_merge_repo_and_path($path);
    my $url = $self->_api_url() . "/replication/$path";
    return $self->post(
        $url,
        "Content-Type" => 'application/json',
        Content        => $self->_json->encode($payload)
    );
} ## end sub pull_push_replication

=head2 file_list( $dir, %opts )

Get a flat (the default) or deep listing of the files and folders (not included
by default) within a folder

=cut

sub file_list {
    my ( $self, $dir, %opts ) = @_;
    $dir = $self->_merge_repo_and_path($dir);
    my $url = $self->_api_url() . "/storage/$dir?list";

    for my $opt ( keys %opts ) {
        my $val = $opts{$opt};
        $url .= "&${opt}=$val";
    } ## end for my $opt ( keys %opts)
    return $self->get($url);
} ## end sub file_list

=head1 SEARCHES

=cut

=head2 artifact_search( name => $name, repos => [ @repos ] )

Artifact search by part of file name

=cut

sub artifact_search {
    my ( $self, %args ) = @_;
    return $self->_handle_search( 'artifact', %args );
} ## end sub artifact_search

=head2 archive_entry_search( name => $name, repos => [ @repos ] )

Search archive entries for classes or any other jar resources

=cut

sub archive_entry_search {
    my ( $self, %args ) = @_;
    return $self->_handle_search( 'archive', %args );
} ## end sub archive_entry_search

=head2 gavc_search( groupId => 'foo', classifier => 'bar' )

Search by Maven coordinates: groupId, artifactId, version & classifier

=cut

sub gavc_search {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'gavc', %args );
} ## end sub gavc_search

=head2 property_search( p => [ 'v1', 'v2' ], repos => [ 'repo1', repo2' ]  )

Search by properties

=cut

sub property_search {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'prop', %args );
} ## end sub property_search

=head2 checksum_search( md5sum => '12345', repos => [ 'repo1', repo2' ]  )

Artifact search by checksum (md5 or sha1)

=cut

sub checksum_search {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'checksum', %args );
} ## end sub checksum_search

=head2 bad_checksum_search( type => 'md5', repos => [ 'repo1', repo2' ]  )

Find all artifacts that have a bad or missing client checksum values (md5 or
sha1)

=cut

sub bad_checksum_search {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'badChecksum', %args );
} ## end sub bad_checksum_search

=head2 artifacts_not_downloaded_since( notUsedSince => 12345, createdBefore => 12345, repos => [ 'repo1', repo2' ] )

Retrieve all artifacts not downloaded since the specified Java epoch in msec.

=cut

sub artifacts_not_downloaded_since {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'usage', %args );
} ## end sub artifacts_not_downloaded_since

=head2 artifacts_created_in_date_range( from => 12345, to => 12345, repos => [ 'repo1', repo2' ] )

Get all artifacts created in date range

=cut

sub artifacts_created_in_date_range {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'creation', %args );
} ## end sub artifacts_created_in_date_range

=head2 pattern_search( $pattern )

Get all artifacts matching the given Ant path pattern

=cut

sub pattern_search {
    my ( $self, $pattern ) = @_;
    my $repository = $self->repository();
    my $url        = $self->_api_url() . "/search/pattern?pattern=$repository:$pattern";
    return $self->get($url);
} ## end sub pattern_search

=head2 builds_for_dependency( sha1 => 'abcde' )

Find all the builds an artifact is a dependency of (where the artifact is
included in the build-info dependencies)

=cut

sub builds_for_dependency {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'dependency', %args );
} ## end sub builds_for_dependency

=head2 license_search( unapproved => 1, unknown => 1, notfound => 0, neutral => 0, repos => [ 'foo', 'bar' ] )

Search for artifacts with specified statuses

=cut

sub license_search {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'license', %args );
} ## end sub license_search

=head2 artifact_version_search( g => 'foo', a => 'bar', v => '1.0', repos => [ 'foo', 'bar' ] )

Search for all available artifact versions by GroupId and ArtifactId in local,
remote or virtual repositories

=cut

sub artifact_version_search {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'versions', %args );
} ## end sub artifact_version_search

=head2 artifact_latest_version_search_based_on_layout( g => 'foo', a => 'bar', v => '1.0', repos => [ 'foo', 'bar' ] )

Search for the latest artifact version by groupId and artifactId, based on the
layout defined in the repository

=cut

sub artifact_latest_version_search_based_on_layout {
    my ( $self, %args ) = @_;
    return $self->_handle_search_props( 'latestVersion', %args );
} ## end sub artifact_latest_version_search_based_on_layout

=head2 artifact_latest_version_search_based_on_properties( repo => '_any', path => '/a/b', listFiles => 1 )

Search for artifacts with the latest value in the "version" property

=cut

sub artifact_latest_version_search_based_on_properties {
    my ( $self, %args ) = @_;
    my $repo = delete $args{repo};
    my $path = delete $args{path};

    $repo =~ s{^\/}{}xi;
    $repo =~ s{\/$}{}xi;

    $path =~ s{^\/}{}xi;
    $path =~ s{\/$}{}xi;

    my $url = $self->_api_url() . "/versions/$repo/$path?";
    $url .= $self->_stringify_hash( '&', %args );
    return $self->get($url);
} ## end sub artifact_latest_version_search_based_on_properties

=head2 build_artifacts_search( buildNumber => 15, buildName => 'foobar' )

Find all the artifacts related to a specific build

=cut

sub build_artifacts_search {
    my ( $self, %args ) = @_;

    my $url = $self->_api_url() . "/search/buildArtifacts";
    return $self->post(
        $url,
        'Content-Type' => 'application/json',
        content        => $self->_json->encode( \%args )
    );
} ## end sub build_artifacts_search

=head1 SECURITY

=cut

=head2 get_users

Get the users list

=cut

sub get_users {
    my $self = shift;
    return $self->_handle_security( undef, 'get', 'users' );
} ## end sub get_users

=head2 get_user_details( $user )

Get the details of an Artifactory user

=cut

sub get_user_details {
    my ( $self, $user ) = @_;
    return $self->_handle_security( $user, 'get', 'users' );
} ## end sub get_user_details

=head2 create_or_replace_user( $user, %args )

Creates a new user in Artifactory or replaces an existing user

=cut

sub create_or_replace_user {
    my ( $self, $user, %args ) = @_;
    return $self->_handle_security( $user, 'put', 'users', %args );
} ## end sub create_or_replace_user

=head2 update_user( $user, %args )

Updates an exiting user in Artifactory with the provided user details

=cut

sub update_user {
    my ( $self, $user, %args ) = @_;
    return $self->_handle_security( $user, 'post', 'users', %args );
} ## end sub update_user

=head2 delete_user( $user )

Removes an Artifactory user

=cut

sub delete_user {
    my ( $self, $user ) = @_;
    return $self->_handle_security( $user, 'delete', 'users' );
} ## end sub delete_user

=head2 get_groups

Get the groups list

=cut

sub get_groups {
    my $self = shift;
    return $self->_handle_security( undef, 'get', 'groups' );
} ## end sub get_groups

=head2 get_group_details( $group )

Get the details of an Artifactory Group

=cut

sub get_group_details {
    my ( $self, $group ) = @_;
    return $self->_handle_security( $group, 'get', 'groups' );
} ## end sub get_group_details

=head2 create_or_replace_group( $group, %args )

Creates a new group in Artifactory or replaces an existing group

=cut

sub create_or_replace_group {
    my ( $self, $group, %args ) = @_;
    return $self->_handle_security( $group, 'put', 'groups', %args );
} ## end sub create_or_replace_group

=head2 update_group( $group, %args )

Updates an exiting group in Artifactory with the provided group details

=cut

sub update_group {
    my ( $self, $group, %args ) = @_;
    return $self->_handle_security( $group, 'post', 'groups', %args );
} ## end sub update_group

=head2 delete_group( $group )

Removes an Artifactory group

=cut

sub delete_group {
    my ( $self, $group ) = @_;
    return $self->_handle_security( $group, 'delete', 'groups' );
} ## end sub delete_group

=head2 get_permission_targets

Get the permission targets list

=cut

sub get_permission_targets {
    my $self = shift;
    return $self->_handle_security( undef, 'get', 'permissions' );
} ## end sub get_permission_targets

=head2 get_permission_target_details( $name )

Get the details of an Artifactory Permission Target

=cut

sub get_permission_target_details {
    my ( $self, $name ) = @_;
    return $self->_handle_security( $name, 'get', 'permissions' );
} ## end sub get_permission_target_details

=head2 create_or_replace_permission_target( $name, %args )

Creates a new permission target in Artifactory or replaces an existing
permission target

=cut

sub create_or_replace_permission_target {
    my ( $self, $name, %args ) = @_;
    return $self->_handle_security( $name, 'put', 'permissions', %args );
} ## end sub create_or_replace_permission_target

=head2 delete_permission_target( $name )

Deletes an Artifactory permission target

=cut

sub delete_permission_target {
    my ( $self, $name ) = @_;
    return $self->_handle_security( $name, 'delete', 'permissions' );
} ## end sub delete_permission_target

=head2 effective_item_permissions( $path )

Returns a list of effective permissions for the specified item (file or folder)

=cut

sub effective_item_permissions {
    my ( $self, $path ) = @_;
    $path = $self->_merge_repo_and_path($path);
    my $url = $self->_api_url() . "/storage/$path";
    return $self->get($url);
} ## end sub effective_item_permissions

=head2 security_configuration

Retrieve the security configuration (security.xml)

=cut

sub security_configuration {
    my ( $self, $path ) = @_;

    my $url = $self->_api_url() . "/system/security";
    return $self->get($url);
} ## end sub security_configuration

=head1 REPOSITORIES

=cut

=head2 get_repositories( $type )

Returns a list of minimal repository details for all repositories of the
specified type

=cut

sub get_repositories {
    my ( $self, $type ) = @_;

    my $url = $self->_api_url() . "/repositories";
    $url .= "?type=$type" if ($type);

    return $self->get($url);
} ## end sub get_repositories

=head2 repository_configuration( $name, %args )

Retrieves the current configuration of a repository

=cut

sub repository_configuration {
    my ( $self, $repo, %args ) = @_;

    $repo =~ s{^\/}{}xi;
    $repo =~ s{\/$}{}xi;

    my $url =
      (%args)
      ? $self->_api_url() . "/repositories/$repo?"
      : $self->_api_url() . "/repositories/$repo";
    $url .= $self->_stringify_hash( '&', %args ) if (%args);
    return $self->get($url);
} ## end sub repository_configuration

=head2 create_or_replace_repository_configuration( $name, \%payload, %args )

Creates a new repository in Artifactory with the provided configuration or
replaces the configuration of an existing repository

=cut

sub create_or_replace_repository_configuration {
    my ( $self, $repo, $payload, %args ) = @_;
    return $self->_handle_repositories( $repo, $payload, 'put', %args );
} ## end sub create_or_replace_repository_configuration

=head2 update_repository_configuration( $name, \%payload )

Updates an exiting repository configuration in Artifactory with the provided
configuration elements

=cut

sub update_repository_configuration {
    my ( $self, $repo, $payload ) = @_;
    return $self->_handle_repositories( $repo, $payload, 'post' );
} ## end sub update_repository_configuration

=head2 delete_repository( $name )

Removes a repository configuration together with the whole repository content

=cut

sub delete_repository {
    my ( $self, $repo ) = @_;
    return $self->_handle_repositories( $repo, undef, 'delete' );
} ## end sub delete_repository

=head2 calculate_yum_repository_metadata( async => 0/1 )

Calculates/recalculates the YUM metdata for this repository, based on the RPM
package currently hosted in the repository

=cut

sub calculate_yum_repository_metadata {
    my ( $self, %args ) = @_;
    my $repository = $self->repository();
    my $url =
      (%args)
      ? $self->_api_url() . "/yum/$repository?"
      : $self->_api_url() . "/yum/$repository";
    $url .= $self->_stringify_hash( '&', %args ) if (%args);
    return $self->post($url);
} ## end sub calculate_yum_repository_metadata

=head2 calculate_nuget_repository_metadata

Recalculates all the NuGet packages for this repository (local/cache/virtual),
and re-annotate the NuGet properties for each NuGet package according to it's
internal nuspec file

=cut

sub calculate_nuget_repository_metadata {
    my $self       = shift;
    my $repository = $self->repository();
    my $url        = $self->_api_url() . "/nuget/$repository/reindex";
    return $self->post($url);
} ## end sub calculate_nuget_repository_metadata

=head2 calculate_maven_index( repos => [ 'repo1', 'repo2' ], force => 0/1 )

Calculates/caches a Maven index for the specified repositories

=cut

sub calculate_maven_index {
    my ( $self, %args ) = @_;

    my $url = $self->_api_url() . "/maven?";
    $url .= $self->_stringify_hash( '&', %args );
    return $self->post($url);
} ## end sub calculate_maven_index

=head2 calculate_maven_metadata( $path )

Calculates Maven metadata on the specified path (local repositories only)

=cut

sub calculate_maven_metadata {
    my ( $self, $path ) = @_;
    $path = $self->_merge_repo_and_path($path);
    my $url = $self->_api_url() . "/maven/calculateMetadata/$path";
    return $self->post($url);
} ## end sub calculate_maven_metadata

=head1 SYSTEM & CONFIGURATION

=cut

=head2 system_info

Get general system information

=cut

sub system_info {
    my $self = shift;
    return $self->_handle_system();
} ## end sub system_info

=head2 system_health_ping

Get a simple status response about the state of Artifactory

=cut

sub system_health_ping {
    my $self = shift;
    return $self->_handle_system('ping');
} ## end sub system_health_ping

=head2 general_configuration

Get the general configuration (artifactory.config.xml)

=cut

sub general_configuration {
    my $self = shift;
    return $self->_handle_system('configuration');
} ## end sub general_configuration

=head2 save_general_configuration( $file )

Save the general configuration (artifactory.config.xml)

=cut

sub save_general_configuration {
    my ( $self, $xml ) = @_;

    my $file = Path::Tiny::path($xml)->slurp( { binmode => ":raw" } );
    my $url = $self->_api_url() . "/system/configuration";
    return $self->post(
        $url,
        'Content-Type' => 'application/xml',
        content        => $file
    );
} ## end sub save_general_configuration

=head2 version_and_addons_information

Retrieve information about the current Artifactory version, revision, and
currently installed Add-ons

=cut

sub version_and_addons_information {
    my $self = shift;

    my $url = $self->_api_url() . "/system/version";
    return $self->get($url);
} ## end sub version_and_addons_information

=head1 PLUGINS

=cut

=head2 execute_plugin_code( $execution_name, $params, $async )

Executes a named execution closure found in the executions section of a user
plugin

=cut

sub execute_plugin_code {
    my ( $self, $execution_name, $params, $async ) = @_;

    my $url =
      ($params)
      ? $self->_api_url() . "/plugins/execute/$execution_name?params="
      : $self->_api_url() . "/plugins/execute/$execution_name";

    $url = $url . $self->_attach_properties( properties => $params );
    $url .= "&" . $self->_stringify_hash( '&', %{$async} ) if ($async);
    return $self->post($url);
} ## end sub execute_plugin_code

=head2 retrieve_all_available_plugin_info

Retrieves all available user plugin information (subject to the permissions of
the provided credentials)

=cut

sub retrieve_all_available_plugin_info {
    my $self = shift;
    return $self->_handle_plugins();
} ## end sub retrieve_all_available_plugin_info

=head2 retrieve_plugin_info_of_a_certain_type( $type )

Retrieves all available user plugin information (subject to the permissions of
the provided credentials) of the specified type

=cut

sub retrieve_plugin_info_of_a_certain_type {
    my ( $self, $type ) = @_;
    return $self->_handle_plugins($type);
} ## end sub retrieve_plugin_info_of_a_certain_type

=head2 retrieve_build_staging_strategy( strategyName => 'strategy1', buildName => 'build1', %args )

Retrieves a build staging strategy defined by a user plugin

=cut

sub retrieve_build_staging_strategy {
    my ( $self, %args ) = @_;
    my $strategy_name = delete $args{strategyName};
    my $build_name    = delete $args{buildName};

    my $url = $self->_api_url() . "/plugins/build/staging/$strategy_name?buildName=$build_name?params=";
    $url = $url . $self->_attach_properties( properties => \%args );
    return $self->get($url);
} ## end sub retrieve_build_staging_strategy

=head2 execute_build_promotion( promotionName => 'promotion1', buildName => 'build1', buildNumber => 3, %args )

Executes a named promotion closure found in the promotions section of a user
plugin

=cut

sub execute_build_promotion {
    my ( $self, %args ) = @_;
    my $promotion_name = delete $args{promotionName};
    my $build_name     = delete $args{buildName};
    my $build_number   = delete $args{buildNumber};

    my $url = $self->_api_url() . "/plugins/build/promote/$promotion_name/$build_name/$build_number?params=";
    $url = $url . $self->_attach_properties( properties => \%args );
    return $self->post($url);
} ## end sub execute_build_promotion

=head1 IMPORT & EXPORT

=cut

=head2 import_repository_content( path => 'foobar', repo => 'repo', metadata => 1, verbose => 0 )

Import one or more repositories

=cut

sub import_repository_content {
    my ( $self, %args ) = @_;

    my $url = $self->_api_url() . "/import/repositories?";
    $url .= $self->_stringify_hash( '&', %args );
    return $self->post($url);
} ## end sub import_repository_content

=head2 import_system_settings_example

Returned default Import Settings JSON

=cut

sub import_system_settings_example {
    my $self = shift;
    return $self->_handle_system_settings('import');
} ## end sub import_system_settings_example

=head2 full_system_import( importPath => '/import/path', includeMetadata => 'false' etc )

Import full system from a server local Artifactory export directory

=cut

sub full_system_import {
    my ( $self, %args ) = @_;
    return $self->_handle_system_settings( 'import', %args );
} ## end sub full_system_import

=head2 export_system_settings_example

Returned default Export Settings JSON

=cut

sub export_system_settings_example {
    my $self = shift;
    return $self->_handle_system_settings('export');
} ## end sub export_system_settings_example

=head2 export_system( exportPath => '/export/path', includeMetadata => 'true' etc )

Export full system to a server local directory

=cut

sub export_system {
    my ( $self, %args ) = @_;
    return $self->_handle_system_settings( 'export', %args );
} ## end sub export_system

sub _build_ua {
    my $self = shift;
    return LWP::UserAgent->new( agent => 'perl-artifactory-client/' . $VERSION, );
} ## end sub _build_ua

sub _build_json {
    my ($self) = @_;
    return JSON::MaybeXS->new( utf8 => 1 );
} ## end sub _build_json

sub _request {
    my ( $self, $method, @args ) = @_;
    return $self->ua->$method(@args);
} ## end sub _request

sub _get_build {
    my ( $self, $path ) = @_;

    my $url = $self->_api_url() . "/build/$path";
    return $self->get($url);
} ## end sub _get_build

sub _attach_properties {
    my ( $self, %args ) = @_;
    my $properties = $args{properties};
    my $matrix     = $args{matrix};
    my @strings;

    for my $key ( keys %{$properties} ) {
        push @strings, $self->_handle_prop_multivalue( $key, $properties->{$key}, $matrix );
    } ## end for my $key ( keys %{$properties...})

    return join( ";", @strings ) if $matrix;
    return join( "|", @strings );
} ## end sub _attach_properties

sub _handle_prop_multivalue {
    my ( $self, $key, $values, $matrix ) = @_;

    # need to handle matrix vs non-matrix situations.
    if ($matrix) {
        return $self->_handle_matrix_props( $key, $values );
    }
    return $self->_handle_non_matrix_props( $key, $values );
} ## end sub _handle_prop_multivalue

sub _handle_matrix_props {
    my ( $self, $key, $values ) = @_;

    # string looks like key=val;key=val2;key=val3;
    my @strings;
    for my $value ( @{$values} ) {
        $value = '' if ( !defined $value );

        #$value = uri_escape( $value );
        push @strings, "$key=$value";
    } ## end for my $value ( @{$values...})
    return join( ";", @strings );
} ## end sub _handle_matrix_props

sub _handle_non_matrix_props {
    my ( $self, $key, $values ) = @_;

    # string looks like key=val1,val2,val3|
    my $str = "$key=";
    my @value_holder;
    for my $value ( @{$values} ) {
        $value = '' if ( !defined $value );
        $value = uri_escape($value);
        push @value_holder, $value;
    } ## end for my $value ( @{$values...})
    $str .= join( ",", @value_holder );
    return $str;
} ## end sub _handle_non_matrix_props

sub _handle_item {
    my ( $self, %args ) = @_;

    my ( $from, $to, $dry, $suppress_layouts, $fail_fast, $method ) =
      ( $args{from}, $args{to}, $args{dry}, $args{suppress_layouts}, $args{fail_fast}, $args{method} );

    my $url = $self->_api_url() . "/$method$from?to=$to";
    $url .= "&dry=$dry" if ( defined $dry );
    $url .= "&suppressLayouts=$suppress_layouts"
      if ( defined $suppress_layouts );
    $url .= "&failFast=$fail_fast" if ( defined $fail_fast );
    return $self->post($url);
} ## end sub _handle_item

sub _handle_repository_replication_configuration {
    my ( $self, $method, $payload ) = @_;
    my $repository = $self->repository();
    my $url        = $self->_api_url() . "/replications/$repository";

    return $self->$method(
        $url,
        'Content-Type' => 'application/json',
        content        => $payload
    ) if ($payload);

    return $self->$method($url);
} ## end sub _handle_repository_replication_configuration

sub _handle_search {
    my ( $self, $api, %args ) = @_;
    my $name  = $args{name};
    my $repos = $args{repos};

    my $url = $self->_api_url() . "/search/$api?name=$name";

    if ( ref($repos) eq 'ARRAY' ) {
        $url .= "&repos=";
        for my $item ( @{$repos} ) {
            $url .= "$item,";
        }
    } ## end if ( ref($repos) eq 'ARRAY')
    return $self->get($url);
} ## end sub _handle_search

sub _handle_search_props {
    my ( $self, $method, %args ) = @_;

    my $url = $self->_api_url() . "/search/$method?";

    $url .= $self->_stringify_hash( '&', %args );
    return $self->get($url);
} ## end sub _handle_search_props

sub _stringify_hash {
    my ( $self, $delimiter, %args ) = @_;

    my @strs;
    for my $key ( keys %args ) {
        my $val = $args{$key};

        if ( ref($val) eq 'ARRAY' ) {
            $val = join( ",", @{$val} );
        }
        push @strs, "$key=$val";
    } ## end for my $key ( keys %args)
    return join( $delimiter, @strs );
} ## end sub _stringify_hash

sub _handle_security {
    my ( $self, $label, $method, $element, %args ) = @_;

    my $url =
      ($label)
      ? $self->_api_url() . "/security/$element/$label"
      : $self->_api_url() . "/security/$element";

    if (%args) {
        return $self->$method(
            $url,
            'Content-Type' => 'application/json',
            content        => $self->_json->encode( \%args )
        );
    } ## end if (%args)
    return $self->$method($url);
} ## end sub _handle_security

sub _handle_repositories {
    my ( $self, $repo, $payload, $method, %args ) = @_;

    $repo =~ s{^\/}{}xi;
    $repo =~ s{\/$}{}xi;

    my $url =
      (%args)
      ? $self->_api_url() . "/repositories/$repo?"
      : $self->_api_url() . "/repositories/$repo";
    $url .= $self->_stringify_hash( '&', %args ) if (%args);

    if ($payload) {
        return $self->$method(
            $url,
            'Content-Type' => 'application/json',
            content        => $self->_json->encode($payload)
        );
    } ## end if ($payload)
    return $self->$method($url);
} ## end sub _handle_repositories

sub _handle_system {
    my ( $self, $arg ) = @_;

    my $url =
      ($arg)
      ? $self->_api_url() . "/system/$arg"
      : $self->_api_url() . "/system";
    return $self->get($url);
} ## end sub _handle_system

sub _handle_plugins {
    my ( $self, $type ) = @_;

    my $url =
      ($type)
      ? $self->_api_url() . "/plugins/$type"
      : $self->_api_url() . "/plugins";
    return $self->get($url);
} ## end sub _handle_plugins

sub _handle_system_settings {
    my ( $self, $action, %args ) = @_;

    my $url = $self->_api_url() . "/$action/system";

    if (%args) {
        return $self->post(
            $url,
            'Content-Type' => 'application/json',
            content        => $self->_json->encode( \%args )
        );
    } ## end if (%args)
    return $self->get($url);
} ## end sub _handle_system_settings

sub _merge_repo_and_path {
    my ( $self, $_path ) = @_;

    $_path = '' if not defined $_path;
    $_path =~ s{^\/}{}xi;

    return join( '/', grep { $_ } $self->repository(), $_path );
} ## end sub _merge_repo_and_path

__PACKAGE__->meta->make_immutable;

=head1 AUTHOR

Satoshi Yagi, C<< <satoshi.yagi at yahoo.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-artifactory-client at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Artifactory-Client>.  I will
be notified, and then you'll automatically be notified of progress on your bug
as I make changes.

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

This program is free software; you can redistribute it and/or modify it under
the terms of the the Artistic License (2.0). You may obtain a copy of the full
license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified Versions is
governed by this Artistic License. By using, modifying or distributing the
Package, you accept this license. Do not use, modify, or distribute the
Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made by
someone other than you, you are nevertheless required to ensure that your
Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service mark,
tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge patent
license to make, have made, use, offer to sell, sell, import and otherwise
transfer the Package with respect to any patent claims licensable by the
Copyright Holder that are necessarily infringed by the Package. If you
institute patent litigation (including a cross-claim or counterclaim) against
any party alleging that the Package constitutes direct or contributory patent
infringement, then this Artistic License to you shall terminate on the date
that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER AND
CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES. THE IMPLIED
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY YOUR LOCAL LAW.
UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR CONTRIBUTOR WILL BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING IN ANY WAY
OUT OF THE USE OF THE PACKAGE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
DAMAGE.

=cut

1;    # End of Artifactory::Client

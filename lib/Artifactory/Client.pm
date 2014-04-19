package Artifactory::Client;

use strict;
use warnings;
use Moose;
use LWP::UserAgent;
use Data::Dumper;
use URI::Escape;
use namespace::autoclean;
use JSON;

=head1 NAME

Artifactory::Client - Perl client for Artifactory REST API

=head1 VERSION

Version 0.0.30

=cut

our $VERSION = '0.0.30';

=head1 SYNOPSIS

This is a Perl client for Artifactory REST API: https://www.jfrog.com/confluence/display/RTF/Artifactory+REST+API

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

=cut

has 'artifactory' => (
    is => 'ro',
    isa => 'Str',
    required => 1
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
    required => 1
);

=head1 SUBROUTINES/METHODS

=cut

sub _build_ua {
    my $self = shift;
    $self->{ ua } = LWP::UserAgent->new() unless( $self->{ ua } );
}

=head2 get

Invokes GET request on LWP::UserAgent-like object; params are passed through.
Returns HTTP::Response object.

=cut

sub get {
    my ( $self, @args ) = @_;
    return $self->_request( 'get', @args );
}

=head2 post

nvokes POST request on LWP::UserAgent-like object; params are passed through.
Returns HTTP::Response object.

=cut

sub post {
    my ( $self, @args ) = @_;
    return $self->_request( 'post', @args );
}

=head2 put

Invokes PUT request on LWP::UserAgent-like object; params are passed through.
Returns HTTP::Response object.

=cut

sub put {
    my ( $self, @args ) = @_;
    return $self->_request( 'put', @args );
}

=head2 delete

Invokes DELETE request on LWP::UserAgent-like object; params are passed through.
Returns HTTP::Response object.

=cut

sub delete {
    my ( $self, @args ) = @_;
    return $self->_request( 'delete', @args );
}

sub _request {
    my ( $self, $method, @args ) = @_;
    return $self->{ ua }->$method( @args );
}

=head2 deploy_artifact( path => $path, properties => { key => [ values ] }, content => $content )

Takes path, properties and content then deploys artifact.  Note that properties are a hashref with key-arrayref pairs,
such as:

    $prop = { key1 => ['a'], key2 => ['a', 'b'] }

Returns HTTP::Response object.

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

Returns HTTP::Response object.

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

=head2 set_item_properties( path => $path, properties => { key => [ values ] }, recursive => 0,1 )

Takes path and properties then set item properties.  Supply recursive => 0 if you want to suppress propagation of
properties downstream.  Note that properties are a hashref with key-arrayref pairs, such as:

    $prop = { key1 => ['a'], key2 => ['a', 'b'] }

Returns HTTP::Response object.

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

=head2 item_properties( path => $path, properties => [ key_names ] )

Takes path and properties then get item properties.
Returns HTTP::Response object.

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

=head2 retrieve_artifact( $path )

Takes path and retrieves artifact on the path.
Returns HTTP::Response object.

=cut

sub retrieve_artifact {
    my ( $self, $path ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/$repository$path";
    return $self->get( $url );
}

=head2 all_builds

Retrieves information on all builds from artifactory.
Returns HTTP::Response object.

=cut

sub all_builds {
    my $self = shift;
    return $self->_get_build('');
}

=head2 build_runs( $build_name )

Retrieves information of a particular build from artifactory.
Returns HTTP::Response object.

=cut

sub build_runs {
    my ( $self, $build ) = @_;
    return $self->_get_build( $build );
}

=head2 build_info( $build_name, $build_number )

Retrieves information of a particular build number.
Returns HTTP::Response object.

=cut

sub build_info {
    my ( $self, $build, $number ) = @_;
    return $self->_get_build( "$build/$number" );
}

=head2 builds_diff( $build_name, $new_build_number, $old_build_number )

Retrieves diff of 2 builds
Returns HTTP::Response object.

=cut

sub builds_diff {
    my ( $self, $build, $new, $old ) = @_;
    return $self->_get_build( "$build/$new?diff=$old" );
}

=head2 build_promotion( $build_name, $build_number, $payload )

Promotes a build by POSTing payload
Returns HTTP::Response object.

=cut

sub build_promotion {
    my ( $self, $build, $number, $payload ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = "$artifactory:$port/artifactory/api/build/promote/$build/$number";
    return $self->post( $url, "Content-Type" => 'application/json', Content => to_json( $payload ) );
}

=head2 delete_build( name => $build_name, buildnumbers => [ buildnumbers ], artifacts => 0,1, deleteall => 0,1 )

Promotes a build by POSTing payload
Returns HTTP::Response object.

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

sub _get_build {
    my ( $self, $path ) = @_;
    my ( $artifactory, $port ) = $self->_unpack_attributes( 'artifactory', 'port' );
    my $url = "$artifactory:$port/artifactory/api/build/$path";
    return $self->get( $url ); 
}

=head2 delete_item( $path )

Delete $path on artifactory.
Returns HTTP::Response object.

=cut

sub delete_item {
    my ( $self, $path ) = @_;
    my ( $artifactory, $port, $repository ) = $self->_unpack_attributes( 'artifactory', 'port', 'repository' );
    my $url = "$artifactory:$port/artifactory/$repository$path";
    return $self->delete( $url );
}

sub _unpack_attributes {
    my ( $self, @args ) = @_;
    my @result;

    for my $attr ( @args ) {
        push @result, $self->{ $attr };
    }
    return @result;
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

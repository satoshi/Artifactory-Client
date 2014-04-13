[![Build Status](https://travis-ci.org/satoshi/Artifactory-Client.svg?branch=master)](https://travis-ci.org/satoshi/Artifactory-Client)

This is a Perl client for Artifactory REST API: https://www.jfrog.com/confluence/display/RTF/Artifactory+REST+API
```perl
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
```

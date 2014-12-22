use strict;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
    module_name        => 'Artifactory::Client',
    license            => 'Artistic_2_0',
    dist_author        => q{Satoshi Yagi <satoshi@yahoo-inc.com>},
    dist_version_from  => 'lib/Artifactory/Client.pm',
    release_status     => 'stable',
    configure_requires => { 'Module::Build' => 0, },
    test_requires      => {
        'Test::More'     => 0,
        'JSON'           => 0,
        'WWW::Mechanize' => 0,
    },
    requires => {
        'HTTP::Request::StreamingUpload' => 0,
        'JSON::MaybeXS'                  => 0,
        'LWP::UserAgent'                 => 0,
        'Moose'                          => 2.0604,
        'MooseX::StrictConstructor'      => 0,
        'namespace::autoclean'           => 0,
        'Path::Tiny'                     => 0,
        'URI::Escape'                    => 0,
    },
    add_to_cleanup     => ['Artifactory-Client-*'],
    create_makefile_pl => 'traditional',

    meta_merge => {
        no_index  => { directory => [ 't_func', ], },
        keywords  => [qw(artifactory)],
        resources => {
            bugtracker => 'https://github.com/satoshi/Artifactory-Client/issues',
            repository => 'git://github.com/satoshi/Artifactory-Client.git',
            homepage   => 'https://github.com/satoshi/Artifactory-Client',
        },
    },
);

$builder->create_build_script();

use strict;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Artifactory::Client',
    license             => 'Artistic_2_0',
    dist_author         => q{Satoshi Yagi <satoshi@yahoo-inc.com>},
    dist_version_from   => 'lib/Artifactory/Client.pm',
    release_status      => 'stable',
    configure_requires => {
        'Module::Build' => 0,
    },
    build_requires => {
        'Test::More'        => 0,
        'JSON'              => 0,
        'LWP::UserAgent'    => 0,
        'WWW::Mechanize'    => 0,
    },
    requires => {
        'Moose'                 => 2.0604,
        'LWP::UserAgent'        => 0,
        'URI::Escape'           => 0,
        'namespace::autoclean'  => 0,
    },
    add_to_cleanup     => [ 'Artifactory-Client-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
